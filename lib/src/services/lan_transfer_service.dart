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
  LanTransferService({
    Duration connectionTimeout = const Duration(seconds: 10),
    Duration clipboardTimeout = const Duration(seconds: 15),
    Duration fileTimeout = const Duration(seconds: 60),
  })  : _connectionTimeout = connectionTimeout,
        _clipboardTimeout = clipboardTimeout,
        _fileTimeout = fileTimeout;

  static const int discoveryPort = 45671;
  static const int _maxStoredReceivedItems = 300;
  static const MethodChannel _platformChannel =
      MethodChannel('app.local.lan_transfer_clipboard/files');
  static const MethodChannel _androidPlatformChannel =
      MethodChannel('app.local.lan_transfer_clipboard/platform');

  final Duration _connectionTimeout;
  final Duration _clipboardTimeout;
  final Duration _fileTimeout;

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
    await _loadReceivedItems();
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
    final client = HttpClient()
      ..connectionTimeout = _connectionTimeout
      ..idleTimeout = _clipboardTimeout;
    try {
      final request = await client
          .postUrl(peer.baseUri.resolve('/clipboard'))
          .timeout(_connectionTimeout);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode({'text': text})));
      final response = await request.close().timeout(_clipboardTimeout);
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
    final client = HttpClient()
      ..connectionTimeout = _connectionTimeout
      ..idleTimeout = _fileTimeout;
    try {
      final request = await client
          .postUrl(peer.baseUri.resolve('/file'))
          .timeout(_connectionTimeout);
      request.headers.contentType = ContentType.binary;
      request.headers.set('X-File-Name', Uri.encodeComponent(fileName));
      request.contentLength = fileLength;
      await request.addStream(bytes).timeout(_fileTimeout);
      final response = await request.close().timeout(_fileTimeout);
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
      _addReceivedItem(
        ReceivedItem(
          type: ReceivedItemType.clipboard,
          title: 'Clipboard text',
          detail: text,
          receivedAt: DateTime.now(),
        ),
      );
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && request.uri.path == '/file') {
      final encodedName =
          request.headers.value('X-File-Name') ?? 'received-file';
      final safeName = _safeFileName(Uri.decodeComponent(encodedName));
      final savedFile = await _saveReceivedFile(safeName, request);
      _addReceivedItem(
        ReceivedItem(
          type: ReceivedItemType.file,
          title: savedFile.name,
          detail: savedFile.path,
          receivedAt: DateTime.now(),
        ),
      );
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  void _addReceivedItem(ReceivedItem item) {
    _receivedItems.insert(0, item);
    if (_receivedItems.length > _maxStoredReceivedItems) {
      _receivedItems.removeRange(
        _maxStoredReceivedItems,
        _receivedItems.length,
      );
    }
    notifyListeners();
    unawaited(_saveReceivedItems());
  }

  Future<File> _receivedItemsFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/received-items.json');
  }

  Future<void> _loadReceivedItems() async {
    final file = await _receivedItemsFile();
    if (!await file.exists()) {
      return;
    }

    try {
      final data = jsonDecode(await file.readAsString()) as List<Object?>;
      _receivedItems
        ..clear()
        ..addAll(
          data.whereType<Map>().map((item) {
            return ReceivedItem.fromJson(Map<String, Object?>.from(item));
          }).take(_maxStoredReceivedItems),
        );
    } catch (_) {
      // Ignore unreadable history; receiving new items will rewrite the file.
    }
  }

  Future<void> _saveReceivedItems() async {
    final file = await _receivedItemsFile();
    final data = _receivedItems
        .take(_maxStoredReceivedItems)
        .map((item) => item.toJson())
        .toList();
    await file.writeAsString(jsonEncode(data));
  }

  Future<_SavedFile> _saveReceivedFile(
    String safeName,
    Stream<List<int>> bytes,
  ) async {
    if (Platform.isAndroid) {
      return _saveAndroidDownload(safeName, bytes);
    }

    final directory = await getApplicationDocumentsDirectory();
    await directory.create(recursive: true);
    final uniqueName = _uniqueFileName(directory, safeName);
    final file = File('${directory.path}/$uniqueName');
    final sink = file.openWrite();
    await sink.addStream(bytes);
    await sink.close();
    return _SavedFile(path: file.path, name: uniqueName);
  }

  String _uniqueFileName(Directory folder, String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final base = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final ext = dotIndex > 0 ? fileName.substring(dotIndex) : '';
    var candidate = fileName;
    var index = 1;
    while (File('${folder.path}/$candidate').existsSync()) {
      candidate = '$base ($index)$ext';
      index += 1;
    }
    return candidate;
  }

  Future<_SavedFile> _saveAndroidDownload(
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
      return _SavedFile(
        path: publicPath,
        name: result?['name'] ?? _fileNameFromPath(publicPath, safeName),
      );
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
        if (!_isValidPort(peer.port)) {
          continue;
        }
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
    final addresses = <String>{};
    final androidWifiAddress = await _loadAndroidWifiAddress();
    if (androidWifiAddress != null) {
      addresses.add(androidWifiAddress);
    }

    final interfaces = await NetworkInterface.list(
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );

    addresses.addAll(interfaces
        .expand((interface) => interface.addresses)
        .where(_isUsableLanAddress)
        .map((address) => address.address)
        .where(_isUsableLanAddressText));

    return addresses.toList()..sort(_compareLanAddresses);
  }

  Future<String?> _loadAndroidWifiAddress() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final address = await _androidPlatformChannel.invokeMethod<String>(
        'getWifiIpv4Address',
      );
      if (address != null && _isUsableLanAddressText(address)) {
        return address;
      }
    } on PlatformException {
      // Fall back to NetworkInterface below.
    } on MissingPluginException {
      // Fall back to NetworkInterface below.
    }
    return null;
  }

  bool _isUsableLanAddress(InternetAddress address) {
    return !address.isLoopback && _isUsableLanAddressText(address.address);
  }

  bool _isValidPort(int port) {
    return port > 0 && port <= 65535;
  }

  bool _isUsableLanAddressText(String address) {
    if (address == '0.0.0.0' ||
        address == '127.0.0.1' ||
        address.startsWith('169.254.')) {
      return false;
    }

    final parts = address.split('.');
    if (parts.length != 4) {
      return false;
    }
    final octets = parts.map(int.tryParse).toList();
    return !octets.any((octet) => octet == null || octet < 0 || octet > 255);
  }

  int _compareLanAddresses(String a, String b) {
    final priority = _addressPriority(a).compareTo(_addressPriority(b));
    if (priority != 0) {
      return priority;
    }
    return a.compareTo(b);
  }

  int _addressPriority(String address) {
    if (address.startsWith('192.168.')) {
      return 0;
    }
    if (address.startsWith('10.')) {
      return 1;
    }
    final parts = address.split('.');
    final second = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (address.startsWith('172.') &&
        second != null &&
        second >= 16 &&
        second <= 31) {
      return 2;
    }
    return 3;
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

  String _fileNameFromPath(String path, String fallback) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    if (index < 0 || index == normalized.length - 1) {
      return fallback;
    }
    return normalized.substring(index + 1);
  }
}

class _SavedFile {
  const _SavedFile({
    required this.path,
    required this.name,
  });

  final String path;
  final String name;
}
