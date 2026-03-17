import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/web_intent_parser.dart';
import '../../models/chat_folder.dart';
import '../../models/chat_thread.dart';
import '../../models/user_plan.dart';
import '../localization/app_i18n.dart';
import '../controllers/chat_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_chat_background.dart';
import '../widgets/desktop_window_bar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.controller});

  final ChatController controller;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputController = TextEditingController();
  final _searchController = TextEditingController();
  final _messageScrollController = ScrollController();
  final _inputFocusNode = FocusNode();

  String? _hoverFolderDropId;
  bool _hoverRootDrop = false;

  String _lastThreadId = '';
  int _lastMessageCount = 0;
  bool _lastLoadingState = false;
  bool _composerNeedsWeb = false;

  AppI18n get _i18n => AppI18n(widget.controller.settings.languageCode);

  String _t(String key, [Map<String, String> params = const {}]) {
    return _i18n.t(key, params);
  }

  @override
  void initState() {
    super.initState();
    final controller = widget.controller;
    _searchController.text = controller.searchQuery;
    _lastThreadId = controller.activeThreadId;
    _lastMessageCount = controller.messages.length;
    _lastLoadingState = controller.isLoading;
    _inputController.addListener(_handleComposerChanged);
    _handleComposerChanged();

    controller.addListener(_handleControllerChanged);
    if (!controller.isInitialized) {
      unawaited(controller.initialize());
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(jump: true),
    );
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }

    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);

    _searchController.text = widget.controller.searchQuery;
    _lastThreadId = widget.controller.activeThreadId;
    _lastMessageCount = widget.controller.messages.length;
    _lastLoadingState = widget.controller.isLoading;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _inputController.removeListener(_handleComposerChanged);
    _inputController.dispose();
    _searchController.dispose();
    _messageScrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    final needsWeb = WebIntentParser.requestsWeb(_inputController.text);
    if (_composerNeedsWeb == needsWeb) {
      return;
    }
    setState(() {
      _composerNeedsWeb = needsWeb;
    });
  }

  void _handleControllerChanged() {
    final controller = widget.controller;
    if (_searchController.text != controller.searchQuery) {
      _searchController.text = controller.searchQuery;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    }

    final hasChanged =
        controller.activeThreadId != _lastThreadId ||
        controller.messages.length != _lastMessageCount ||
        controller.isLoading != _lastLoadingState;
    if (!hasChanged) {
      return;
    }

    _lastThreadId = controller.activeThreadId;
    _lastMessageCount = controller.messages.length;
    _lastLoadingState = controller.isLoading;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_messageScrollController.hasClients) {
      return;
    }
    final target = _messageScrollController.position.maxScrollExtent + 160;
    if (jump) {
      _messageScrollController.jumpTo(target);
      return;
    }
    _messageScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  bool _isWideLayout(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 980;
  }

  Future<void> _openSettings() async {
    final controller = widget.controller;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) {
          return SettingsScreen(
            initialSettings: controller.settings,
            onSave: controller.applySettings,
            onClearHistory: controller.clearHistory,
          );
        },
      ),
    );
  }

  Future<void> _sendMessage() async {
    final controller = widget.controller;
    final text = _inputController.text.trim();
    if (text.isEmpty || controller.isLoading) {
      return;
    }

    if (WebIntentParser.requestsWeb(text) &&
        !controller.settings.webSearchEnabled) {
      _showSnack(_t('internetDisabledReason'));
    }

    _inputController.clear();
    final error = await controller.sendMessage(text);
    if (!mounted || error == null) {
      return;
    }
    _showSnack(error);
  }

  KeyEventResult _handleComposerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isEnter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) {
      return KeyEventResult.ignored;
    }

    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
    if (isCtrlPressed) {
      _insertNewLineAtCursor();
      return KeyEventResult.handled;
    }

    unawaited(_sendMessage());
    return KeyEventResult.handled;
  }

  void _insertNewLineAtCursor() {
    final value = _inputController.value;
    final selection = value.selection;
    final text = value.text;

    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final nextText = text.replaceRange(start, end, '\n');
    final nextOffset = start + 1;

    _inputController.value = value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
  }

  Future<void> _createThread() async {
    final previousError = widget.controller.lastError;
    await widget.controller.createThread();
    if (!mounted) {
      return;
    }
    final nextError = widget.controller.lastError;
    if (nextError != null && nextError != previousError) {
      _showSnack(nextError);
    }
    _inputFocusNode.requestFocus();
  }

  Future<void> _renameThread(ChatThread thread) async {
    final name = await _showNameDialog(
      title: 'Переименовать чат',
      actionLabel: 'Сохранить',
      initialValue: thread.title,
      hintText: 'Название чата',
    );
    if (name == null) {
      return;
    }
    await widget.controller.renameThread(threadId: thread.id, newTitle: name);
  }

  Future<void> _deleteThread(ChatThread thread) async {
    final approved = await _confirmAction(
      title: 'Удалить чат?',
      message:
          'Чат "${thread.title}" будет удалён без возможности восстановления.',
      approveLabel: 'Удалить',
    );
    if (!approved) {
      return;
    }
    await widget.controller.deleteThread(thread.id);
  }

  Future<void> _createFolder() async {
    final name = await _showNameDialog(
      title: 'Новая папка',
      actionLabel: 'Создать',
      hintText: 'Название папки',
    );
    if (name == null) {
      return;
    }
    final previousError = widget.controller.lastError;
    await widget.controller.createFolder(name);
    if (!mounted) {
      return;
    }
    final nextError = widget.controller.lastError;
    if (nextError != null && nextError != previousError) {
      _showSnack(nextError);
    }
  }

  Future<void> _renameFolder(ChatFolder folder) async {
    final name = await _showNameDialog(
      title: 'Переименовать папку',
      actionLabel: 'Сохранить',
      initialValue: folder.name,
      hintText: 'Название папки',
    );
    if (name == null) {
      return;
    }
    await widget.controller.renameFolder(folderId: folder.id, newName: name);
  }

  Future<void> _deleteFolder(ChatFolder folder) async {
    final approved = await _confirmAction(
      title: 'Удалить папку?',
      message:
          'Папка "${folder.name}" будет удалена. Чаты останутся и переместятся в корень.',
      approveLabel: 'Удалить',
    );
    if (!approved) {
      return;
    }
    await widget.controller.deleteFolder(folder.id);
  }

  Future<void> _moveThreadWithSheet(ChatThread thread) async {
    final folders = widget.controller.folders;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_off_rounded),
              title: const Text('Без папки (корень)'),
              trailing: thread.folderId == null
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: thread.folderId == null
                  ? null
                  : () => Navigator.of(context).pop(null),
            ),
            const Divider(height: 1),
            ...folders.map((folder) {
              final disabled = folder.id == thread.folderId;
              return ListTile(
                leading: const Icon(Icons.folder_rounded),
                title: Text(folder.name),
                trailing: disabled ? const Icon(Icons.check_rounded) : null,
                onTap: disabled
                    ? null
                    : () => Navigator.of(context).pop(folder.id),
              );
            }),
          ],
        );
      },
    );

    if (selected == thread.folderId) {
      return;
    }
    await widget.controller.moveThreadToFolder(
      threadId: thread.id,
      folderId: selected,
    );
  }

  Future<String?> _showNameDialog({
    required String title,
    required String actionLabel,
    required String hintText,
    String initialValue = '',
  }) async {
    final textController = TextEditingController(text: initialValue);
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(hintText: hintText),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                final value = textController.text.trim();
                if (value.isNotEmpty) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  final value = textController.text.trim();
                  if (value.isEmpty) {
                    return;
                  }
                  Navigator.of(dialogContext).pop(value);
                },
                child: Text(actionLabel),
              ),
            ],
          );
        },
      );
    } finally {
      textController.dispose();
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String approveLabel,
  }) async {
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(approveLabel),
                ),
              ],
            );
          },
        ) ??
        false;
    return approved;
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _selectFolder(
    String? folderId, {
    required bool closeDrawer,
  }) async {
    await widget.controller.selectFolder(folderId);
    if (!mounted || !closeDrawer) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _selectThread(
    String threadId, {
    required bool closeDrawer,
  }) async {
    await widget.controller.selectThread(threadId);
    if (!mounted || !closeDrawer) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _updateSearch(String value) {
    widget.controller.updateSearchQuery(value);
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty && !widget.controller.hasSearchQuery) {
      return;
    }
    _searchController.clear();
    widget.controller.clearSearch();
  }

  Future<void> _onThreadMenuSelected(
    _ThreadMenuAction action,
    ChatThread thread,
  ) async {
    switch (action) {
      case _ThreadMenuAction.favorite:
        await widget.controller.toggleThreadFavorite(thread.id);
      case _ThreadMenuAction.rename:
        await _renameThread(thread);
      case _ThreadMenuAction.move:
        await _moveThreadWithSheet(thread);
      case _ThreadMenuAction.delete:
        await _deleteThread(thread);
    }
  }

  Future<void> _onFolderMenuSelected(
    _FolderMenuAction action,
    ChatFolder folder,
  ) async {
    switch (action) {
      case _FolderMenuAction.rename:
        await _renameFolder(folder);
      case _FolderMenuAction.delete:
        await _deleteFolder(folder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _isWideLayout(context);
    final controller = widget.controller;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: isWide
          ? null
          : Drawer(
              width: 340,
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: SafeArea(
                child: _buildSidebar(
                  context,
                  closeDrawerOnSelect: true,
                  enableDragAndDrop: false,
                ),
              ),
            ),
      appBar: isWide || DesktopWindowBar.isSupported
          ? null
          : AppBar(
              title: Text(
                controller.activeThread.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              leading: IconButton(
                tooltip: 'Чаты',
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              actions: [
                IconButton(
                  tooltip: 'Новый чат',
                  icon: const Icon(Icons.add_comment_rounded),
                  onPressed: _createThread,
                ),
                IconButton(
                  tooltip: 'Настройки',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: _openSettings,
                ),
              ],
            ),
      body: AnimatedChatBackground(
        child: SafeArea(
          top: !DesktopWindowBar.isSupported,
          bottom: false,
          child: Column(
            children: [
              if (DesktopWindowBar.isSupported)
                DesktopWindowBar(
                  title: "Goodog's AI",
                  onOpenSettings: _openSettings,
                  settingsTooltip: _t('windowSettings'),
                  minimizeTooltip: _t('windowMinimize'),
                  maximizeTooltip: _t('windowMaximize'),
                  restoreTooltip: _t('windowRestore'),
                  closeTooltip: _t('windowClose'),
                ),
              Expanded(
                child: controller.isInitialized
                    ? isWide
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 350,
                                  child: _buildSidebar(
                                    context,
                                    closeDrawerOnSelect: false,
                                    enableDragAndDrop: true,
                                  ),
                                ),
                                Expanded(
                                  child: _buildChatArea(context, isWide: true),
                                ),
                              ],
                            )
                          : _buildChatArea(context, isWide: false)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context, {
    required bool closeDrawerOnSelect,
    required bool enableDragAndDrop,
  }) {
    final controller = widget.controller;
    final colors = Theme.of(context).colorScheme;
    final chatTheme = Theme.of(context).extension<ChatThemeExtension>();

    final folders = controller.filteredFolders;
    final favoriteThreads = controller.favoriteThreads;
    final favoriteIds = favoriteThreads.map((thread) => thread.id).toSet();
    final regularThreads = controller.visibleThreads
        .where((thread) => !favoriteIds.contains(thread.id))
        .toList(growable: false);
    final allThreadsCount = controller.allThreads.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  chatTheme?.panelColor ??
                  colors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color:
                    chatTheme?.panelBorderColor ??
                    colors.outlineVariant.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Рабочее пространство',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Настройки',
                            onPressed: _openSettings,
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: colors.primary.withValues(
                                  alpha: 0.2,
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 16,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.profile.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${controller.profile.plan.title} • ID: ${controller.profile.id}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                    if (controller.account != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '@${controller.account!.login}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Синхронизировать права',
                                onPressed: () {
                                  unawaited(controller.syncProfile());
                                },
                                icon: const Icon(Icons.sync_rounded),
                              ),
                              if (controller.settings.lanGatewayEnabled)
                                IconButton(
                                  tooltip: 'Выйти',
                                  onPressed: () async {
                                    await controller.logout();
                                    if (!mounted) {
                                      return;
                                    }
                                    _showSnack('Вы вышли из аккаунта.');
                                  },
                                  icon: const Icon(Icons.logout_rounded),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _searchController,
                        onChanged: _updateSearch,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Поиск по чатам и папкам',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: controller.hasSearchQuery
                              ? IconButton(
                                  tooltip: 'Очистить поиск',
                                  onPressed: _clearSearch,
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: controller.canCreateThread
                                  ? _createThread
                                  : null,
                              icon: const Icon(Icons.add_comment_rounded),
                              label: const Text('Новый чат'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: controller.canCreateFolder
                                  ? _createFolder
                                  : null,
                              icon: const Icon(Icons.create_new_folder_rounded),
                              label: const Text('Папка'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                    children: [
                      _buildFolderDropTile(
                        context,
                        label: 'Все чаты',
                        icon: Icons.forum_rounded,
                        count: allThreadsCount,
                        isSelected: controller.selectedFolderId == null,
                        isHovering: _hoverRootDrop,
                        enableDragAndDrop: enableDragAndDrop,
                        onTap: () => _selectFolder(
                          null,
                          closeDrawer: closeDrawerOnSelect,
                        ),
                        onAcceptThread: (threadId) {
                          unawaited(
                            controller.moveThreadToFolder(
                              threadId: threadId,
                              folderId: null,
                            ),
                          );
                        },
                        onCanAcceptThread: (threadId) {
                          return controller.canMoveThreadToFolder(
                            threadId: threadId,
                            folderId: null,
                          );
                        },
                        onHoverChanged: (hovering) {
                          setState(() {
                            _hoverRootDrop = hovering;
                          });
                        },
                      ),
                      const SizedBox(height: 6),
                      ...folders.map((folder) {
                        final folderThreads = controller.allThreads
                            .where((thread) => thread.folderId == folder.id)
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildFolderDropTile(
                            context,
                            label: folder.name,
                            icon: Icons.folder_rounded,
                            count: folderThreads,
                            isSelected:
                                controller.selectedFolderId == folder.id,
                            isHovering: _hoverFolderDropId == folder.id,
                            enableDragAndDrop: enableDragAndDrop,
                            onTap: () => _selectFolder(
                              folder.id,
                              closeDrawer: closeDrawerOnSelect,
                            ),
                            onMenuSelected: (action) {
                              unawaited(_onFolderMenuSelected(action, folder));
                            },
                            onAcceptThread: (threadId) {
                              unawaited(
                                controller.moveThreadToFolder(
                                  threadId: threadId,
                                  folderId: folder.id,
                                ),
                              );
                            },
                            onCanAcceptThread: (threadId) {
                              return controller.canMoveThreadToFolder(
                                threadId: threadId,
                                folderId: folder.id,
                              );
                            },
                            onHoverChanged: (hovering) {
                              setState(() {
                                _hoverFolderDropId = hovering
                                    ? folder.id
                                    : null;
                              });
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      if (favoriteThreads.isNotEmpty)
                        _buildSectionLabel(context, 'Избранные'),
                      ...favoriteThreads.map((thread) {
                        return _buildThreadTile(
                          context,
                          thread: thread,
                          closeDrawerOnSelect: closeDrawerOnSelect,
                          enableDragAndDrop: enableDragAndDrop,
                        );
                      }),
                      if (regularThreads.isNotEmpty)
                        _buildSectionLabel(
                          context,
                          controller.hasSearchQuery
                              ? 'Результаты поиска'
                              : 'Чаты',
                        ),
                      ...regularThreads.map((thread) {
                        return _buildThreadTile(
                          context,
                          thread: thread,
                          closeDrawerOnSelect: closeDrawerOnSelect,
                          enableDragAndDrop: enableDragAndDrop,
                        );
                      }),
                      if (favoriteThreads.isEmpty && regularThreads.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colors.outlineVariant.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Ничего не найдено. Попробуйте другой запрос или создайте новый чат.',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildFolderDropTile(
    BuildContext context, {
    required String label,
    required IconData icon,
    required int count,
    required bool isSelected,
    required bool isHovering,
    required bool enableDragAndDrop,
    required VoidCallback onTap,
    required bool Function(String threadId) onCanAcceptThread,
    required void Function(String threadId) onAcceptThread,
    required void Function(bool hovering) onHoverChanged,
    void Function(_FolderMenuAction action)? onMenuSelected,
  }) {
    final colors = Theme.of(context).colorScheme;

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isSelected
                ? colors.primary.withValues(alpha: 0.17)
                : isHovering
                ? colors.secondary.withValues(alpha: 0.18)
                : colors.surface.withValues(alpha: 0.28),
            border: Border.all(
              color: isHovering
                  ? colors.secondary.withValues(alpha: 0.55)
                  : isSelected
                  ? colors.primary.withValues(alpha: 0.4)
                  : colors.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (onMenuSelected != null) ...[
                const SizedBox(width: 4),
                PopupMenuButton<_FolderMenuAction>(
                  tooltip: 'Действия с папкой',
                  onSelected: onMenuSelected,
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: _FolderMenuAction.rename,
                        child: Text('Переименовать'),
                      ),
                      PopupMenuItem(
                        value: _FolderMenuAction.delete,
                        child: Text('Удалить'),
                      ),
                    ];
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!enableDragAndDrop) {
      return tile;
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final canAccept = onCanAcceptThread(details.data);
        onHoverChanged(canAccept);
        return canAccept;
      },
      onAcceptWithDetails: (details) {
        onHoverChanged(false);
        onAcceptThread(details.data);
      },
      onLeave: (_) => onHoverChanged(false),
      builder: (context, candidateData, rejectedData) {
        final hovered = isHovering || candidateData.isNotEmpty;
        return AnimatedScale(
          scale: hovered ? 1.01 : 1,
          duration: const Duration(milliseconds: 130),
          child: tile,
        );
      },
    );
  }

  Widget _buildThreadTile(
    BuildContext context, {
    required ChatThread thread,
    required bool closeDrawerOnSelect,
    required bool enableDragAndDrop,
  }) {
    final controller = widget.controller;
    final colors = Theme.of(context).colorScheme;
    final isSelected = thread.id == controller.activeThreadId;

    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () =>
              _selectThread(thread.id, closeDrawer: closeDrawerOnSelect),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.2)
                  : colors.surface.withValues(alpha: 0.25),
              border: Border.all(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.48)
                    : colors.outlineVariant.withValues(alpha: 0.23),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  thread.isFavorite
                      ? Icons.star_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: thread.isFavorite ? colors.tertiary : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        thread.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                PopupMenuButton<_ThreadMenuAction>(
                  tooltip: 'Действия с чатом',
                  onSelected: (action) {
                    unawaited(_onThreadMenuSelected(action, thread));
                  },
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem<_ThreadMenuAction>(
                        value: _ThreadMenuAction.favorite,
                        child: Text(
                          thread.isFavorite
                              ? 'Убрать из избранного'
                              : 'Добавить в избранное',
                        ),
                      ),
                      const PopupMenuItem<_ThreadMenuAction>(
                        value: _ThreadMenuAction.rename,
                        child: Text('Переименовать'),
                      ),
                      const PopupMenuItem<_ThreadMenuAction>(
                        value: _ThreadMenuAction.move,
                        child: Text('Переместить'),
                      ),
                      const PopupMenuItem<_ThreadMenuAction>(
                        value: _ThreadMenuAction.delete,
                        child: Text('Удалить'),
                      ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!enableDragAndDrop) {
      return tile;
    }

    return LongPressDraggable<String>(
      data: thread.id,
      maxSimultaneousDrags: 1,
      feedback: _buildDragFeedback(context, thread),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }

  Widget _buildDragFeedback(BuildContext context, ChatThread thread) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 250,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.primary.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.drive_file_move_rounded, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                thread.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea(BuildContext context, {required bool isWide}) {
    final colors = Theme.of(context).colorScheme;
    final chatTheme = Theme.of(context).extension<ChatThemeExtension>();
    final controller = widget.controller;
    final messages = controller.messages;

    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 8 : 12, 8, 12, 10),
      child: Column(
        children: [
          _buildChatHeader(context, isWide: isWide),
          if (controller.lastError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: DecoratedBox(
                  key: ValueKey<String>(controller.lastError!),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: colors.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.lastError!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          chatTheme?.panelColor ??
                          colors.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color:
                            chatTheme?.panelBorderColor ??
                            colors.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: messages.isEmpty && !controller.isLoading
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.smart_toy_rounded,
                                    size: 50,
                                    color: colors.primary.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _t('startDialogTitle'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _t('startDialogSubtitle'),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _messageScrollController,
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                            itemCount:
                                messages.length +
                                (controller.isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index < messages.length) {
                                final message = messages[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: MessageBubble(
                                    message: message,
                                    index: index,
                                  ),
                                );
                              }
                              return const Padding(
                                padding: EdgeInsets.only(top: 4, bottom: 10),
                                child: TypingIndicator(),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ),
          _buildComposer(context),
        ],
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context, {required bool isWide}) {
    final controller = widget.controller;
    final colors = Theme.of(context).colorScheme;
    final chatTheme = Theme.of(context).extension<ChatThemeExtension>();
    final thread = controller.activeThread;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                chatTheme?.panelColor ?? colors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  chatTheme?.panelBorderColor ??
                  colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _scopeSubtitle(controller),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _buildContextUsageCircle(context, controller),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: thread.isFavorite
                      ? 'Убрать из избранного'
                      : 'Добавить в избранное',
                  onPressed: () {
                    unawaited(controller.toggleThreadFavorite(thread.id));
                  },
                  icon: Icon(
                    thread.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Переименовать чат',
                  onPressed: () => _renameThread(thread),
                  icon: const Icon(Icons.drive_file_rename_outline_rounded),
                ),
                if (!controller.autoContextRefreshEnabled)
                  IconButton(
                    tooltip: 'Сбросить память ИИ и обновить контекст',
                    onPressed: () {
                      unawaited(controller.refreshContextForActiveThread());
                      _showSnack(
                        'Память ИИ для этого чата сброшена. Лимит контекста начат заново.',
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                if (isWide)
                  IconButton(
                    tooltip: 'Новый чат',
                    onPressed: _createThread,
                    icon: const Icon(Icons.add_comment_rounded),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _scopeSubtitle(ChatController controller) {
    final selectedFolderId = controller.selectedFolderId;
    final folderName = selectedFolderId == null
        ? 'Все чаты'
        : _folderNameById(controller, selectedFolderId) ?? 'Папка';

    final contextInfo =
        '${controller.activeContextMessagesCount}/${controller.limits.maxContextMessages}';
    final contextMode = controller.autoContextRefreshEnabled
        ? 'авто-контекст'
        : 'ручной контекст (до сброса)';
    final tier = controller.profile.plan.title;
    final mark = controller.activeThread.isFavorite ? ' • избранный' : '';
    return '$folderName • $tier • $contextMode $contextInfo$mark';
  }

  Widget _buildContextUsageCircle(
    BuildContext context,
    ChatController controller,
  ) {
    final colors = Theme.of(context).colorScheme;
    final current = controller.activeContextMessagesCount;
    final max = controller.limits.maxContextMessages;
    final ratio = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    final label = current > 99 ? '99+' : current.toString();
    final tooltip = controller.autoContextRefreshEnabled
        ? 'Контекст: $current/$max'
        : 'Лимит отправок до сброса памяти: $current/$max';

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: ratio,
              strokeWidth: 3,
              backgroundColor: colors.outlineVariant.withValues(alpha: 0.35),
            ),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  String? _folderNameById(ChatController controller, String folderId) {
    for (final folder in controller.folders) {
      if (folder.id == folderId) {
        return folder.name;
      }
    }
    return null;
  }

  Widget _buildComposer(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chatTheme = Theme.of(context).extension<ChatThemeExtension>();
    final controller = widget.controller;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                chatTheme?.panelColor ?? colors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  chatTheme?.panelBorderColor ??
                  colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!controller.autoContextRefreshEnabled)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.secondary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_toggle_off_rounded,
                          color: colors.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Лимит контекста ограничен тарифом. Когда круг достигнет максимума, нажмите кнопку обновления в заголовке, чтобы сбросить память ИИ и начать контекст заново.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!controller.autoContextRefreshEnabled)
                  const SizedBox(height: 10),
                if (_composerNeedsWeb && !controller.settings.webSearchEnabled)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.tertiary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: colors.onTertiaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _t('internetDisabledReason'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onTertiaryContainer),
                          ),
                        ),
                        TextButton(
                          onPressed: _openSettings,
                          child: Text(_t('enable')),
                        ),
                      ],
                    ),
                  ),
                if (_composerNeedsWeb && !controller.settings.webSearchEnabled)
                  const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Focus(
                        onKeyEvent: _handleComposerKey,
                        child: TextField(
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          enabled: !controller.isCurrentUserBanned,
                          minLines: 1,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: _t('inputHint'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 50,
                      width: 50,
                      child: FilledButton(
                        onPressed: controller.isCurrentUserBanned
                            ? null
                            : (controller.isLoading
                                  ? controller.stopGenerating
                                  : _sendMessage),
                        style: FilledButton.styleFrom(
                          backgroundColor: controller.isLoading
                              ? colors.error
                              : null,
                          foregroundColor: controller.isLoading
                              ? colors.onError
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Icon(
                          controller.isLoading
                              ? Icons.stop_rounded
                              : Icons.send_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ThreadMenuAction { favorite, rename, move, delete }

enum _FolderMenuAction { rename, delete }
