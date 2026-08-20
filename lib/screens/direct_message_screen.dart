import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screengate/models/message.dart' as dm;
import 'package:screengate/models/user.dart' as model_user;
import 'package:screengate/providers/app_provider.dart';
import 'package:screengate/theme.dart';

class DirectMessageScreen extends StatefulWidget {
  final model_user.User peer;
  const DirectMessageScreen({super.key, required this.peer});

  @override
  State<DirectMessageScreen> createState() => _DirectMessageScreenState();
}

class _DirectMessageScreenState extends State<DirectMessageScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Stream<List<dm.Message>>? _conversationStream;
  bool _initializedStream = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lazily create the stream when we have access to provider and current user
    if (!_initializedStream) {
      try {
        final provider = context.read<AppProvider>();
        final me = provider.currentUser;
        if (me != null) {
          // Ensure the StreamBuilder rebuilds when we attach the stream
          setState(() {
            _conversationStream = provider.messageService
                .getConversationStream(me.id, widget.peer.id);
            _initializedStream = true;
          });
          debugPrint(
              'Conversation stream initialized for ${me.id} <-> ${widget.peer.id}');
        }
      } catch (e) {
        debugPrint('Error initializing conversation stream: $e');
      }
    }
  }

  Future<void> _send() async {
    final provider = context.read<AppProvider>();
    final me = provider.currentUser;
    final text = _controller.text.trim();
    if (me == null || text.isEmpty) return;

    try {
      await provider.messageService.sendMessage(
        senderId: me.id,
        receiverId: widget.peer.id,
        content: text,
      );
      _controller.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final me = provider.currentUser;
    if (me == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                widget.peer.codename[0].toUpperCase(),
                style: context.textStyles.titleMedium!.bold.withColor(
                  Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.peer.codename,
                    style: context.textStyles.titleMedium!.semiBold),
                Text('Direct Message',
                    style: context.textStyles.labelSmall!.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<dm.Message>>(
              stream: _conversationStream ?? const Stream.empty(),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <dm.Message>[];
                // Auto-scroll when new messages arrive
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                // Mark unread incoming messages as read when visible
                final unreadForMe = messages
                    .where((m) => m.receiverId == me.id && !m.isRead)
                    .toList();
                if (unreadForMe.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    final svc = provider.messageService;
                    for (final m in unreadForMe) {
                      try {
                        await svc.markAsRead(m.id);
                      } catch (e) {
                        debugPrint(
                            'Failed to mark message ${m.id} as read: $e');
                      }
                    }
                  });
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: AppSpacing.paddingMd,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMe = m.senderId == me.id;
                    return Padding(
                      padding: AppSpacing.verticalXs,
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHigh,
                              child: Text(
                                widget.peer.codename[0].toUpperCase(),
                                style: context.textStyles.labelSmall!.bold,
                              ),
                            ),
                          if (!isMe) const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: AppSpacing.paddingMd,
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Text(m.content,
                                  style: context.textStyles.bodyMedium),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2)),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.peer.codename}...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _send,
                    style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(16)),
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
