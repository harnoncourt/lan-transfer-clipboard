import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/lan_peer.dart';
import '../models/received_item.dart';
import 'device_identity.dart';

class LanTransferService extends ChangeNotifier {
  static const int discoveryPort = 45671;
  static const MethodChannel _platformChannel =
      MethodChannel('app.local.lan_transfer_clipboard/files');

  final Map<String, LanPeer> _peers = {};
  final List<ReceivedItem> _receivedItems = [];
  List<String> _localAddresses = const [];

  RawDatagramSocket? _discoverySocket;
  StreamSubscription<RawSocketEvent>? _discoverySubscription;
  HttpServer? _httpServer;
  Timer? _heartbeatTimer;
  Timer? _pruneTimer;
  late final DeviceIdentity _identity;
  bool _started = false;

  List<LanPeer> get peers {
    final values = _peers.values.toList()
      ..sort((a, b) => a.deviceName.compareTo(b.deviceName));
    return values;
  }

  List<ReceivedItem> get receivedItems => List.unmodifiable(_receivedItems);

  int? get localPort => _httpServer?.port;

  String get localDeviceName => _identity.deviceName;

  String get localPlatform => _identity.platform;

  List<String> get localAddresses => List.unmodifiable(_localAddresses);

  Future<Directory> getReceivedDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download/LAN Transfer');
    }

    return getApplicationDocumentsDirectory();
  }

  Future<void> start() async {
    if (_started) {
      return;
    }

    _identity = await DeviceIdentity.load();
    _localAddresses = await _loadLocalAddresses();
    _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _serveHttp(_httpServer!);
    await _bindDiscoverySocket();

    _started = true;
    _startTimers();
    _sendHelloBurst();
  }

  Future<void> stop() async {
    _started = false;
    _heartbeatTimer?.cancel();
    _pruneTimer?.cancel();
    _heartbeatTimer = null;
    _pruneTimer = null;
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    final discoverySocket = _discoverySocket;
    _discoverySocket = null;
    discoverySocket?.close();
    final httpServer = _httpServer;
    _httpServer = null;
    await httpServer?.close(force: true);
  }

  void pauseDiscoveryPruning() {
    _pruneTimer?.cancel();
    _pruneTimer = null;
  }

  Future<void> resumeDiscovery() async {
    if (!_started) {
      return;
    }

    _localAddresses = await _loadLocalAddresses();
    await _bindDiscoverySocket(restart: true);
    _startTimers();
    _sendHelloBurst();
    notifyListeners();
  }

  Future<void> sendClipboard(LanPeer peer, String text) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(peer.baseUri.resolve('/clipboard'));
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode({'text': text})));
      final response = await request.close();
      if (response.statusCode >= 300) {
        throw HttpException('Clipboard send failed: ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> sendFile(
    LanPeer peer, {
    required String fileName,
    required int fileLength,
    required Stream<List<int>> bytes,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(peer.baseUri.resolve('/file'));
      request.headers.contentType = ContentType.binary;
      request.headers.set('X-File-Name', Uri.encodeComponent(fileName));
      request.contentLength = fileLength;
      await request.addStream(bytes);
      final response = await request.close();
      if (response.statusCode >= 300) {
        throw HttpException('File send failed: ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }

  void _serveHttp(HttpServer server) {
    unawaited(() async {
      await for (final request in server) {
        try {
          await _handleHttpRequest(request);
        } catch (error) {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write(error.toString());
          await request.response.close();
        }
      }
    }());
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    if (request.method == 'GET' && request.uri.path == '/info') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_helloPayload()));
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && request.uri.path == '/clipboard') {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, Object?>;
      final text = json['text'] as String? ?? '';
      _receivedItems.insert(
        0,
        ReceivedItem(
          type: ReceivedItemType.clipboard,
          title: 'Clipboard text',
          detail: text,
          receivedAt: DateTime.now(),
        ),
      );
      notifyListeners();
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && request.uri.path == '/file') {
      final encodedName =
          request.headers.value('X-File-Name') ?? 'received-file';
      final safeName = _safeFileName(Uri.decodeComponent(encodedName));
      final filePath = await _saveReceivedFile(safeName, request);
      _receivedItems.insert(
        0,
        ReceivedItem(
          type: ReceivedItemType.file,
          title: safeName,
          detail: filePath,
          receivedAt: DateTime.now(),
        ),
      );
      notifyListeners();
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  Future<String> _saveReceivedFile(
    String safeName,
    Stream<List<int>> bytes,
  ) async {
    if (Platform.isAndroid) {
      return _saveAndroidDownload(safeName, bytes);
    }

    final directory = await getApplicationDocumentsDirectory();
    await directory.create(recursive: true);
    final file = File('${directory.path}/$safeName');
    final sink = file.openWrite();
    await sink.addStream(bytes);
    await sink.close();
    return file.path;
  }

  Future<String> _saveAndroidDownload(
    String safeName,
    Stream<List<int>> bytes,
  ) async {
    final tempDirectory = await getTemporaryDirectory();
    await tempDirectory.create(recursive: true);
    final tempFile = File('${tempDirectory.path}/$safeName');
    final sink = tempFile.openWrite();
    await sink.addStream(bytes);
    await sink.close();

    try {
      final result = await _platformChannel.invokeMapMethod<String, String>(
        'saveToDownloads',
        {
          'sourcePath': tempFile.path,
          'fileName': safeName,
          'relativePath': 'Download/LAN Transfer',
        },
      );
      final publicPath = result?['path'];
      if (publicPath == null || publicPath.isEmpty) {
        throw const FileSystemException('Android download path is unavailable');
      }
      return publicPath;
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  void _handleDiscoveryEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }

    Datagram? datagram;
    while ((datagram = _discoverySocket?.receive()) != null) {
      try {
        final packet = datagram!;
        final json =
            jsonDecode(utf8.decode(packet.data)) as Map<String, Object?>;
        if (json['type'] != 'hello' || json['deviceId'] == _identity.deviceId) {
          continue;
        }
        final peer = LanPeer.fromHello(json, packet.address.address);
        _peers[peer.deviceId] = peer;
        notifyListeners();
      } catch (_) {
        // Ignore packets that do not belong to this app.
      }
    }
  }

  Future<void> _bindDiscoverySocket({bool restart = false}) async {
    if (!restart && _discoverySocket != null) {
      return;
    }

    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    final previousSocket = _discoverySocket;
    _discoverySocket = null;
    previousSocket?.close();

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    socket.broadcastEnabled = true;
    _discoverySocket = socket;
    _discoverySubscription = socket.listen(_handleDiscoveryEvent);
  }

  void _startTimers() {
    _heartbeatTimer?.cancel();
    _pruneTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _sendHello();
    });
    _pruneTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _prunePeers();
    });
  }

  void _sendHelloBurst() {
    _sendHello();
    Timer(const Duration(milliseconds: 700), _sendHello);
    Timer(const Duration(milliseconds: 1600), _sendHello);
  }

  void _sendHello() {
    if (!_started) {
      return;
    }

    final socket = _discoverySocket;
    if (socket == null) {
      return;
    }

    final bytes = utf8.encode(jsonEncode(_helloPayload()));
    for (final target in _discoveryTargets()) {
      try {
        socket.send(bytes, InternetAddress(target), discoveryPort);
      } on SocketException {
        // Some platforms reject specific broadcast addresses. Try the others.
      }
    }
  }

  Map<String, Object?> _helloPayload() {
    return {
      'type': 'hello',
      'deviceId': _identity.deviceId,
      'deviceName': _identity.deviceName,
      'platform': _identity.platform,
      'port': _httpServer!.port,
      'version': 1,
    };
  }

  void _prunePeers() {
    final now = DateTime.now();
    _peers.removeWhere((_, peer) =>
        now.difference(peer.lastSeen) > const Duration(seconds: 15));
    notifyListeners();
  }

  String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'received-file' : cleaned;
  }

  Future<List<String>> _loadLocalAddresses() async {
    final interfaces = await NetworkInterface.list(
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );

    return interfaces
        .expand((interface) => interface.addresses)
        .where((address) => !address.isLoopback)
        .map((address) => address.address)
        .toSet()
        .toList()
      ..sort();
  }

  Set<String> _discoveryTargets() {
    final targets = <String>{'255.255.255.255'};

    for (final address in _localAddresses) {
      final parts = address.split('.');
      if (parts.length != 4) {
        continue;
      }

      final octets = parts.map(int.tryParse).toList();
      if (octets.any((octet) => octet == null)) {
        continue;
      }

      // Most home and office LANs use /24 subnets. Directed broadcast reaches
      // Windows and Android networks that ignore the limited broadcast address.
      targets.add('${octets[0]}.${octets[1]}.${octets[2]}.255');
    }

    return targets;
  }
}
