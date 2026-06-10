import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../models/lan_peer.dart';
import '../models/received_item.dart';
import '../services/lan_transfer_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.service, super.key});

  final LanTransferService service;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  LanPeer? _selectedPeer;
  _SendState _sendState = _SendState.idle;
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.service.addListener(_handleServiceChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_handleServiceChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.service.resumeDiscovery());
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (Platform.isAndroid || Platform.isIOS) {
        widget.service.pauseDiscoveryPruning();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _ReactiveTopBar(
        title: 'LAN Transfer',
        service: widget.service,
        selectedPeer: _selectedPeer,
      ),
      body: AnimatedBuilder(
        animation: widget.service,
        builder: (context, _) {
          final peers = widget.service.peers;
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final medium = constraints.maxWidth >= 720;

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 324,
                      child: _PeerPanel(
                        peers: peers,
                        selectedPeer: _selectedPeer,
                        onSelectPeer: _selectPeer,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _ActionPanel(
                        selectedPeer: _selectedPeer,
                        sendState: _sendState,
                        status: _status,
                        onSendClipboard: _sendClipboard,
                        onSendFile: _sendFile,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 380,
                      child: _ReceivedPanel(
                        items: widget.service.receivedItems,
                        onOpenFolder: _openReceivedFolder,
                        onCopyText: _copyReceivedText,
                        onOpenFile: _openReceivedFile,
                        onRevealFile: _revealReceivedFile,
                        openFolderTooltip: _openFolderTooltip(),
                        revealFileTooltip: _revealFileTooltip(),
                        showFolderAction: _supportsFileManagerActions,
                        showRevealFileAction: _supportsFileManagerActions,
                      ),
                    ),
                  ],
                );
              }

              if (medium) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 300,
                      child: _PeerPanel(
                        peers: peers,
                        selectedPeer: _selectedPeer,
                        onSelectPeer: _selectPeer,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _ActionPanel(
                            selectedPeer: _selectedPeer,
                            sendState: _sendState,
                            status: _status,
                            onSendClipboard: _sendClipboard,
                            onSendFile: _sendFile,
                            framed: true,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 440,
                            child: _ReceivedPanel(
                              items: widget.service.receivedItems,
                              onOpenFolder: _openReceivedFolder,
                              onCopyText: _copyReceivedText,
                              onOpenFile: _openReceivedFile,
                              onRevealFile: _revealReceivedFile,
                              openFolderTooltip: _openFolderTooltip(),
                              revealFileTooltip: _revealFileTooltip(),
                              showFolderAction: _supportsFileManagerActions,
                              showRevealFileAction: _supportsFileManagerActions,
                              framed: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SizedBox(
                    height: 320,
                    child: _PeerPanel(
                      peers: peers,
                      selectedPeer: _selectedPeer,
                      onSelectPeer: _selectPeer,
                      framed: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ActionPanel(
                    selectedPeer: _selectedPeer,
                    sendState: _sendState,
                    status: _status,
                    onSendClipboard: _sendClipboard,
                    onSendFile: _sendFile,
                    framed: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 420,
                    child: _ReceivedPanel(
                      items: widget.service.receivedItems,
                      onOpenFolder: _openReceivedFolder,
                      onCopyText: _copyReceivedText,
                      onOpenFile: _openReceivedFile,
                      onRevealFile: _revealReceivedFile,
                      openFolderTooltip: _openFolderTooltip(),
                      revealFileTooltip: _revealFileTooltip(),
                      showFolderAction: _supportsFileManagerActions,
                      showRevealFileAction: _supportsFileManagerActions,
                      framed: true,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _selectPeer(LanPeer peer) {
    setState(() {
      _selectedPeer = peer;
      _status = null;
      _sendState = _SendState.idle;
    });
  }

  Future<void> _sendClipboard() async {
    final peer = _selectedPeer;
    if (peer == null || _sendState == _SendState.sending) {
      return;
    }

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      setState(() {
        _sendState = _SendState.warning;
        _status = '剪贴板为空';
      });
      return;
    }

    await _runAction(
      () => widget.service.sendClipboard(peer, text),
      '剪贴板已发送到 ${peer.deviceName}',
    );
  }

  Future<void> _sendFile() async {
    final peer = _selectedPeer;
    if (peer == null || _sendState == _SendState.sending) {
      return;
    }

    final file = await openFile();
    if (file == null) {
      return;
    }

    await _runAction(
      () async {
        final length = await file.length();
        await widget.service.sendFile(
          peer,
          fileName: file.name,
          fileLength: length,
          bytes: file.openRead(),
        );
      },
      '文件已发送到 ${peer.deviceName}',
    );
  }

  Future<void> _runAction(
      Future<void> Function() action, String success) async {
    setState(() {
      _sendState = _SendState.sending;
      _status = '正在发送...';
    });

    try {
      await action();
      setState(() {
        _sendState = _SendState.success;
        _status = success;
      });
    } catch (error) {
      setState(() {
        _sendState = _SendState.error;
        _status = error.toString();
      });
    }
  }

  Future<void> _openReceivedFolder() async {
    final directory = await widget.service.getReceivedDirectory();
    await _openPath(directory.path, '已打开收件目录');
  }

  Future<void> _copyReceivedText(ReceivedItem item) async {
    await Clipboard.setData(ClipboardData(text: item.detail));
    _showMessage('已复制到剪贴板');
  }

  Future<void> _openReceivedFile(ReceivedItem item) async {
    if (item.type == ReceivedItemType.file &&
        !await File(item.detail).exists()) {
      _showMessage('文件不存在，可能已被移动或删除');
      return;
    }

    final result = await OpenFilex.open(item.detail);
    if (result.type == ResultType.done) {
      _showMessage('已打开文件');
      return;
    }

    _showMessage(result.message);
  }

  Future<void> _revealReceivedFile(ReceivedItem item) async {
    if (!await File(item.detail).exists()) {
      _showMessage('文件不存在，可能已被移动或删除');
      return;
    }

    await _revealPath(item.detail);
  }

  Future<void> _openPath(String path, String success) async {
    if (Platform.isMacOS) {
      await _runPlatformCommand('open', [path], success);
      return;
    }

    if (Platform.isWindows) {
      await _runPlatformCommand(
        'explorer.exe',
        [path],
        success,
        ignoreExitCode: true,
      );
      return;
    }

    _showMessage('当前平台暂不支持此操作');
  }

  Future<void> _revealPath(String path) async {
    if (Platform.isMacOS) {
      await _runPlatformCommand('open', ['-R', path], '已在 Finder 中显示');
      return;
    }

    if (Platform.isWindows) {
      await _runPlatformCommand(
        'explorer.exe',
        ['/select,"${File(path).absolute.path}"'],
        '已在资源管理器中显示',
        ignoreExitCode: true,
      );
      return;
    }

    _showMessage('当前平台暂不支持此操作');
  }

  Future<void> _runPlatformCommand(
    String executable,
    List<String> arguments,
    String success, {
    // explorer.exe reports exit code 1 even on success, so callers that
    // already validated the target can opt out of exit-code checking.
    bool ignoreExitCode = false,
  }) async {
    try {
      final result = await Process.run(executable, arguments);
      if (result.exitCode == 0 || ignoreExitCode) {
        _showMessage(success);
        return;
      }

      final error = result.stderr.toString().trim();
      _showMessage(error.isEmpty ? '操作失败' : error);
    } on ProcessException catch (error) {
      _showMessage(error.message);
    }
  }

  String _fileManagerName() {
    if (Platform.isMacOS) {
      return 'Finder';
    }
    if (Platform.isWindows) {
      return '资源管理器';
    }
    return '文件管理器';
  }

  String _revealFileTooltip() {
    final fileManager = _fileManagerName();
    if (fileManager == 'Finder') {
      return '在 Finder 中显示';
    }
    return '在$fileManager中显示';
  }

  String _openFolderTooltip() {
    final fileManager = _fileManagerName();
    if (fileManager == 'Finder') {
      return '打开收件目录';
    }
    return '在$fileManager中打开收件目录';
  }

  bool get _supportsFileManagerActions {
    return Platform.isMacOS || Platform.isWindows;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleServiceChanged() {
    if (!mounted) {
      return;
    }

    final current = _selectedPeer;
    if (current == null) {
      return;
    }

    LanPeer? updated;
    for (final peer in widget.service.peers) {
      if (peer.deviceId == current.deviceId) {
        updated = peer;
        break;
      }
    }

    if (updated == null) {
      setState(() {
        _selectedPeer = null;
        _sendState = _SendState.warning;
        _status = '目标设备已离线';
      });
      return;
    }

    if (updated.host != current.host ||
        updated.port != current.port ||
        updated.deviceName != current.deviceName ||
        updated.platform != current.platform) {
      setState(() {
        _selectedPeer = updated;
      });
    }
  }
}

enum _SendState { idle, sending, success, warning, error }

class _ReactiveTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _ReactiveTopBar({
    required this.title,
    required this.service,
    required this.selectedPeer,
  });

  final String title;
  final LanTransferService service;
  final LanPeer? selectedPeer;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final selected = _currentSelectedPeer();
        return _TopBar(
          title: title,
          selectedPeer: selected,
          peerCount: service.peers.length,
          localDeviceName: service.localDeviceName,
          localPort: service.localPort,
          localAddresses: service.localAddresses,
        );
      },
    );
  }

  LanPeer? _currentSelectedPeer() {
    final selected = selectedPeer;
    if (selected == null) {
      return null;
    }

    for (final peer in service.peers) {
      if (peer.deviceId == selected.deviceId) {
        return peer;
      }
    }
    return selected;
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar({
    required this.title,
    required this.peerCount,
    required this.selectedPeer,
    required this.localDeviceName,
    required this.localPort,
    required this.localAddresses,
  });

  final String title;
  final int peerCount;
  final LanPeer? selectedPeer;
  final String localDeviceName;
  final int? localPort;
  final List<String> localAddresses;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = selectedPeer;
    final endpoint = _localEndpoint(localAddresses, localPort);

    return AppBar(
      toolbarHeight: preferredSize.height,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.hub_outlined, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  selected == null
                      ? '$localDeviceName · $endpoint'
                      : '目标 ${selected.deviceName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _StatusPill(
            icon: Icons.wifi_tethering,
            label: '$peerCount 在线',
            color: colors.tertiary,
          ),
        ),
      ],
    );
  }

  String _localEndpoint(List<String> addresses, int? port) {
    final address = addresses.isEmpty ? '0.0.0.0' : addresses.first;
    return '$address:${port ?? '--'}';
  }
}

class _PeerPanel extends StatelessWidget {
  const _PeerPanel({
    required this.peers,
    required this.selectedPeer,
    required this.onSelectPeer,
    this.framed = false,
  });

  final List<LanPeer> peers;
  final LanPeer? selectedPeer;
  final ValueChanged<LanPeer> onSelectPeer;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      framed: framed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.devices_other,
            title: '设备',
            trailing: _CountBadge(value: peers.length),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: peers.isEmpty
                ? const _EmptyState(
                    icon: Icons.radar,
                    title: '正在扫描',
                    message: '同一局域网内的设备会显示在这里',
                  )
                : ListView.separated(
                    itemCount: peers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final peer = peers[index];
                      return _PeerTile(
                        peer: peer,
                        selected: selectedPeer?.deviceId == peer.deviceId,
                        onTap: () => onSelectPeer(peer),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.selectedPeer,
    required this.sendState,
    required this.status,
    required this.onSendClipboard,
    required this.onSendFile,
    this.framed = false,
  });

  final LanPeer? selectedPeer;
  final _SendState sendState;
  final String? status;
  final VoidCallback onSendClipboard;
  final VoidCallback onSendFile;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final peer = selectedPeer;
    final disabled = peer == null || sendState == _SendState.sending;
    final colors = Theme.of(context).colorScheme;

    return _PanelShell(
      framed: framed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.send_to_mobile,
            title: '发送',
            trailing: _StatusPill(
              icon: peer == null ? Icons.link_off : Icons.link,
              label: peer == null ? '未选择' : '已连接',
              color: peer == null ? colors.outline : colors.primary,
            ),
          ),
          const SizedBox(height: 18),
          _TargetSummary(peer: peer),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.content_paste_go,
                  label: '剪贴板',
                  accent: colors.primary,
                  onPressed: disabled ? null : onSendClipboard,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.upload_file,
                  label: '文件',
                  accent: colors.tertiary,
                  onPressed: disabled ? null : onSendFile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TransferStatus(state: sendState, status: status),
        ],
      ),
    );
  }
}

class _ReceivedPanel extends StatefulWidget {
  const _ReceivedPanel({
    required this.items,
    required this.onOpenFolder,
    required this.onCopyText,
    required this.onOpenFile,
    required this.onRevealFile,
    required this.openFolderTooltip,
    required this.revealFileTooltip,
    required this.showFolderAction,
    required this.showRevealFileAction,
    this.framed = false,
  });

  final List<ReceivedItem> items;
  final VoidCallback onOpenFolder;
  final ValueChanged<ReceivedItem> onCopyText;
  final ValueChanged<ReceivedItem> onOpenFile;
  final ValueChanged<ReceivedItem> onRevealFile;
  final String openFolderTooltip;
  final String revealFileTooltip;
  final bool showFolderAction;
  final bool showRevealFileAction;
  final bool framed;

  @override
  State<_ReceivedPanel> createState() => _ReceivedPanelState();
}

class _ReceivedPanelState extends State<_ReceivedPanel> {
  static const int _pageSize = 20;

  int _visibleCount = _pageSize;

  @override
  void didUpdateWidget(covariant _ReceivedPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length < oldWidget.items.length &&
        _visibleCount > widget.items.length) {
      _visibleCount =
          widget.items.length < _pageSize ? _pageSize : widget.items.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleCount = widget.items.length < _visibleCount
        ? widget.items.length
        : _visibleCount;
    final visibleItems = widget.items.take(visibleCount).toList();
    final hiddenCount = widget.items.length - visibleCount;

    return _PanelShell(
      framed: widget.framed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icon: Icons.move_to_inbox,
            title: '收件箱',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CountBadge(value: widget.items.length),
                if (widget.showFolderAction) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: widget.openFolderTooltip,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onOpenFolder,
                      icon: const Icon(Icons.folder_open),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: widget.items.isEmpty
                ? const _EmptyState(
                    icon: Icons.inbox_outlined,
                    title: '暂无内容',
                    message: '收到的文本和文件会显示在这里',
                  )
                : ListView.separated(
                    itemCount: visibleItems.length + (hiddenCount > 0 ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == visibleItems.length) {
                        return _ShowMoreButton(
                          hiddenCount: hiddenCount,
                          onPressed: _showMore,
                        );
                      }

                      return _ReceivedTile(
                        item: visibleItems[index],
                        onCopyText: widget.onCopyText,
                        onOpenFile: widget.onOpenFile,
                        onRevealFile: widget.onRevealFile,
                        revealFileTooltip: widget.revealFileTooltip,
                        showRevealFileAction: widget.showRevealFileAction,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showMore() {
    setState(() {
      _visibleCount += _pageSize;
    });
  }
}

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({
    required this.hiddenCount,
    required this.onPressed,
  });

  final int hiddenCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final count = hiddenCount > _ReceivedPanelState._pageSize
        ? _ReceivedPanelState._pageSize
        : hiddenCount;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.expand_more),
        label: Text('显示更多 $count 条'),
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.child,
    required this.framed,
  });

  final Widget child;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: child,
    );

    if (!framed) {
      return content;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: content,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 22, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        trailing,
      ],
    );
  }
}

class _PeerTile extends StatelessWidget {
  const _PeerTile({
    required this.peer,
    required this.selected,
    required this.onTap,
  });

  final LanPeer peer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tileColor =
        selected ? colors.primaryContainer : colors.surfaceContainerLowest;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;

    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              _DeviceAvatar(platform: peer.platform, selected: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      peer.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${peer.platform} · ${peer.host}:${peer.port}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? foreground.withValues(alpha: 0.72)
                            : colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceAvatar extends StatelessWidget {
  const _DeviceAvatar({
    required this.platform,
    required this.selected,
  });

  final String platform;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: selected ? colors.primary : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _platformIcon(platform),
        color: selected ? colors.onPrimary : colors.onSurfaceVariant,
      ),
    );
  }
}

class _TargetSummary extends StatelessWidget {
  const _TargetSummary({required this.peer});

  final LanPeer? peer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final peer = this.peer;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: peer == null
          ? Row(
              children: [
                Icon(Icons.ads_click, color: colors.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '请选择目标设备',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                _DeviceAvatar(platform: peer.platform, selected: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        peer.deviceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${peer.platform} · ${peer.host}:${peer.port}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: enabled ? accent : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: enabled ? colors.onPrimary : colors.onSurfaceVariant,
                size: 30,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled ? colors.onPrimary : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferStatus extends StatelessWidget {
  const _TransferStatus({
    required this.state,
    required this.status,
  });

  final _SendState state;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color, label) = switch (state) {
      _SendState.idle => (Icons.radio_button_unchecked, colors.outline, '等待发送'),
      _SendState.sending => (Icons.sync, colors.primary, status ?? '正在发送...'),
      _SendState.success => (
          Icons.check_circle,
          const Color(0xff2e7d32),
          status ?? '发送完成'
        ),
      _SendState.warning => (
          Icons.info,
          const Color(0xffb26a00),
          status ?? '请检查状态'
        ),
      _SendState.error => (Icons.error, colors.error, status ?? '发送失败'),
    };

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceivedTile extends StatelessWidget {
  const _ReceivedTile({
    required this.item,
    required this.onCopyText,
    required this.onOpenFile,
    required this.onRevealFile,
    required this.revealFileTooltip,
    required this.showRevealFileAction,
  });

  final ReceivedItem item;
  final ValueChanged<ReceivedItem> onCopyText;
  final ValueChanged<ReceivedItem> onOpenFile;
  final ValueChanged<ReceivedItem> onRevealFile;
  final String revealFileTooltip;
  final bool showRevealFileAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isFile = item.type == ReceivedItemType.file;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isFile
                    ? colors.tertiaryContainer
                    : colors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isFile ? Icons.insert_drive_file : Icons.content_paste,
                color: isFile
                    ? colors.onTertiaryContainer
                    : colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatReceivedTime(item.receivedAt),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isFile)
              _TileActions(
                actions: [
                  _TileAction(
                    tooltip: '打开文件',
                    icon: Icons.open_in_new,
                    onPressed: () => onOpenFile(item),
                  ),
                  if (showRevealFileAction)
                    _TileAction(
                      tooltip: revealFileTooltip,
                      icon: Icons.drive_file_move_outline,
                      onPressed: () => onRevealFile(item),
                    ),
                ],
              )
            else
              _TileActions(
                actions: [
                  _TileAction(
                    tooltip: '复制文本',
                    icon: Icons.copy,
                    onPressed: () => onCopyText(item),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TileActions extends StatelessWidget {
  const _TileActions({required this.actions});

  final List<_TileAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: actions.map((action) {
        return Tooltip(
          message: action.tooltip,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: action.onPressed,
            icon: Icon(action.icon, size: 19),
          ),
        );
      }).toList(),
    );
  }
}

class _TileAction {
  const _TileAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: colors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 34, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _platformIcon(String platform) {
  final normalized = platform.toLowerCase();
  if (normalized.contains('android')) {
    return Icons.android;
  }
  if (normalized.contains('ios')) {
    return Icons.phone_iphone;
  }
  if (normalized.contains('windows')) {
    return Icons.desktop_windows;
  }
  if (normalized.contains('mac')) {
    return Icons.laptop_mac;
  }
  return Icons.devices;
}

String formatReceivedTime(DateTime value, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final sameDay = value.year == reference.year &&
      value.month == reference.month &&
      value.day == reference.day;
  if (sameDay) {
    return '$hour:$minute';
  }
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
