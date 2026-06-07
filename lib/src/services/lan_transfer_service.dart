import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/lan_peer.dart';
import '../models/received_item.dart';
import 'device_identity.dart';

class LanTransferService extends ChangeNotifier {
  static const int discoveryPort = 45671;

  final Map<String, LanPeer> _peers = {};
  final List<ReceivedItem> _receivedItems = [];
  List<String> _localAddresses = const [];

  RawDatagramSocket? _discoverySocket;
  HttpServer? _httpServer;
  Timer? _heartbeatTimer;
  Timer? _pruneTimer;
  late final DeviceIdentity _identity;

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

  Future<Directory> getReceivedDirectory() {
    return getApplicationDocumentsDirectory();
  }

  Future<void> start() async {
    _identity = await DeviceIdentity.load();
    _localAddresses = await _loadLocalAddresses();
    _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _serveHttp(_httpServer!);

    _discoverySocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _discoverySocket!.broadcastEnabled = true;
    _discoverySocket!.listen(_handleDiscoveryEvent);

    _sendHello();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _sendHello();
    });
    _pruneTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _prunePeers();
    });
  }

  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _pruneTimer?.cancel();
    _discoverySocket?.close();
    await _httpServer?.close(force: true);
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
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$safeName');
      final sink = file.openWrite();
      await sink.addStream(request);
      await sink.close();
      _receivedItems.insert(
        0,
        ReceivedItem(
          type: ReceivedItemType.file,
          title: safeName,
          detail: file.path,
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

  void _sendHello() {
    final socket = _discoverySocket;
    if (socket == null) {
      return;
    }
    final bytes = utf8.encode(jsonEncode(_helloPayload()));
    socket.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);
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
}
