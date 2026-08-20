import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:screengate/providers/app_provider.dart';
import 'package:screengate/models/chat_message.dart';
import 'package:screengate/theme.dart';
import 'package:screengate/models/mission.dart';

class HandlerChatScreen extends StatefulWidget {
  const HandlerChatScreen({super.key});

  @override
  State<HandlerChatScreen> createState() => _HandlerChatScreenState();
}

class _HandlerChatScreenState extends State<HandlerChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure the view is anchored to the latest messages on first paint
    _scrollToBottom();
  }

  Future<void> _loadMessages() async {
    final provider = context.read<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return;

    final messages = await provider.chatService.getMessagesByUserId(user.id);
    setState(() => _messages = messages);

    if (_messages.isEmpty) {
      await _addHandlerMessage(provider.currentHandler!.greetingMessage);
    }

    _scrollToBottom();
  }

  Future<void> _addHandlerMessage(String content) async {
    final provider = context.read<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return;

    final message = await provider.chatService.addMessage(
      userId: user.id,
      role: ChatRole.handler,
      content: content,
    );

    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final provider = context.read<AppProvider>();
    final user = provider.currentUser;
    final handler = provider.currentHandler;
    if (user == null || handler == null) return;

    final userMessage = await provider.chatService.addMessage(
      userId: user.id,
      role: ChatRole.user,
      content: _messageController.text,
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    final conversationHistory = _messages
        .map((m) => {
              'role': m.role.name,
              'content': m.content,
            })
        .toList();

    // Build user profile context
    final userProfileContext = '''
Codename: ${user.codename}
Life Goals: ${user.lifeGoals}
Current Level: ${user.level} (${user.totalStars} stars earned)
Current Streak: ${user.currentStreak} days
Longest Streak: ${user.longestStreak} days
''';

    final response = await provider.aiService.chatWithHandler(
      handler: handler,
      userMessage: userMessage.content,
      conversationHistory: conversationHistory,
      userProfileContext: userProfileContext,
    );

    // No auto-assignment - user must explicitly accept suggested missions
    await _addHandlerMessage(response);
    setState(() => _isLoading = false);
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberpunkColors.surface,
        title: const Text('Clear chat?'),
        content: const Text('This will remove all messages with your handler.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clearChat();
    }
  }

  Future<void> _clearChat() async {
    final provider = context.read<AppProvider>();
    final user = provider.currentUser;
    final handler = provider.currentHandler;
    if (user == null || handler == null) return;

    setState(() => _isLoading = true);
    try {
      await provider.chatService.clearUserMessages(user.id);
      final greeting = await provider.chatService.addMessage(
        userId: user.id,
        role: ChatRole.handler,
        content: handler.greetingMessage,
      );
      setState(() {
        _messages = [greeting];
        _isLoading = false;
      });
      _scrollToBottom();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat cleared')),
        );
      }
    } catch (e) {
      debugPrint('Error clearing chat: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not clear chat: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      try {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } catch (e) {
        // In rare cases (during layout changes), fallback to jump.
        debugPrint('animateTo bottom failed, jumping instead: $e');
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(target);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyberpunkColors.background,
      appBar: AppBar(
        backgroundColor: CyberpunkColors.background,
        automaticallyImplyLeading: false,
        title: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final handler = provider.currentHandler;
            return Row(
              children: [
                if (handler != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CyberpunkColors.neonGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              CyberpunkColors.neonGreen.withValues(alpha: 0.3)),
                    ),
                    child: Text(handler.avatar,
                        style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          handler.name.toUpperCase(),
                          style: context.textStyles.titleSmall!.copyWith(
                            color: CyberpunkColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: CyberpunkColors.neonGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ONLINE',
                              style: context.textStyles.labelSmall!.copyWith(
                                color: CyberpunkColors.neonGreen,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: _isLoading ? null : _confirmClearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: AppSpacing.paddingMd,
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: CyberpunkColors.surface,
              border: Border(
                top: BorderSide(color: CyberpunkColors.border),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: context.textStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: context.textStyles.bodyMedium!
                            .copyWith(color: CyberpunkColors.textMuted),
                        filled: true,
                        fillColor: CyberpunkColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: CyberpunkColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(color: CyberpunkColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide(
                              color: CyberpunkColors.neonTeal, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: CyberpunkColors.neonTeal,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              CyberpunkColors.neonTeal.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      icon: Icon(Icons.send, color: CyberpunkColors.background),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == ChatRole.user;

    // Prepare content: remove any JSON blocks so we don't show raw payload
    final List<Map<String, String>> missions = isUser
        ? const <Map<String, String>>[]
        : _parseSuggestedMissions(message.content);

    String cleanedText;
    if (isUser) {
      cleanedText = message.content;
    } else {
      // Remove any mission JSON payloads; if nothing remains but we have missions, add a short lead-in.
      final stripped = _stripJsonBlocks(message.content).trim();
      cleanedText = stripped.isNotEmpty
          ? stripped
          : (missions.isNotEmpty ? 'Here are missions tailored for you:' : '');
    }

    return Padding(
      padding: AppSpacing.verticalSm,
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Consumer<AppProvider>(
              builder: (context, provider, _) {
                return Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: CyberpunkColors.neonGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            CyberpunkColors.neonGreen.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    provider.currentHandler?.avatar ?? '🤖',
                    style: const TextStyle(fontSize: 20),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: isUser
                    ? CyberpunkColors.neonTeal.withValues(alpha: 0.15)
                    : CyberpunkColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isUser
                      ? CyberpunkColors.neonTeal.withValues(alpha: 0.3)
                      : CyberpunkColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cleanedText.isNotEmpty)
                    Text(
                      cleanedText,
                      style: context.textStyles.bodyMedium!.copyWith(
                        color: CyberpunkColors.textPrimary,
                      ),
                    ),
                  if (!isUser)
                    ..._buildMissionsFromText(context, message.content,
                        preParsed: missions),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMissionsFromText(BuildContext context, String text,
      {List<Map<String, String>>? preParsed}) {
    final missions = preParsed ?? _parseSuggestedMissions(text);
    if (missions.isEmpty) return const [];

    return [
      const SizedBox(height: 12),
      Text('Suggested Missions',
          style: context.textStyles.labelSmall!.semiBold),
      const SizedBox(height: 8),
      ...missions.map((m) => Padding(
            padding: AppSpacing.verticalXs,
            child: _SuggestedMissionTile(
                mission: m, onAccept: () => _acceptSuggestedMission(m)),
          )),
    ];
  }

  List<Map<String, dynamic>> _extractAllJsonObjects(String text) {
    final List<Map<String, dynamic>> results = [];
    try {
      // 1) Parse fenced code blocks first (```json ... ``` or ``` ... ```)
      final fence = RegExp(r"```(?:json)?\s*([\s\S]*?)```", multiLine: true);
      for (final m in fence.allMatches(text)) {
        final inside = m.group(1);
        if (inside == null) continue;
        try {
          final decoded = jsonDecode(inside.trim());
          if (decoded is Map<String, dynamic>) results.add(decoded);
        } catch (_) {
          // not a pure map or invalid; ignore
        }
      }

      // 2) Scan remaining text for balanced JSON objects using brace counting
      final cleaned = text.replaceAll(fence, '');
      final buffer = StringBuffer();
      int depth = 0;
      bool inString = false;
      bool escaped = false;

      void flushIfJson() {
        final candidate = buffer.toString().trim();
        if (candidate.isEmpty) return;
        try {
          final decoded = jsonDecode(candidate);
          if (decoded is Map<String, dynamic>) {
            results.add(decoded);
          }
        } catch (_) {
          // ignore
        }
      }

      for (int i = 0; i < cleaned.length; i++) {
        final ch = cleaned[i];

        if (inString) {
          buffer.write(ch);
          if (escaped) {
            escaped = false;
          } else if (ch == '\\') {
            escaped = true;
          } else if (ch == '"') {
            inString = false;
          }
          continue;
        }

        if (ch == '"') {
          inString = true;
          buffer.write(ch);
          continue;
        }

        if (ch == '{') {
          depth++;
          buffer.write(ch);
          continue;
        }

        if (depth > 0) {
          buffer.write(ch);
          if (ch == '}') {
            depth--;
            if (depth == 0) {
              // End of a JSON object
              flushIfJson();
              buffer.clear();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('extractAllJsonObjects failed: $e');
    }
    return results;
  }

  String _stripJsonBlocks(String text) {
    try {
      var cleaned = text;

      // Remove fenced code blocks first
      final fence = RegExp(r"```(?:json)?\s*[\s\S]*?```", multiLine: true);
      cleaned = cleaned.replaceAll(fence, '');

      // Iteratively remove any JSON object that contains mission keys
      const keys = ['"missions"', '"suggestions"', '"tasks"'];
      bool removed;
      do {
        removed = false;
        int start = cleaned.length;
        for (final key in keys) {
          final idx = cleaned.indexOf(key);
          if (idx == -1) continue;
          // Find the nearest '{' before the key
          final braceStart = cleaned.lastIndexOf('{', idx);
          if (braceStart == -1) continue;
          final relativeEnd = _findClosingBrace(cleaned.substring(braceStart));
          if (relativeEnd == -1) continue;
          final braceEnd = braceStart + relativeEnd;
          cleaned = cleaned.replaceRange(braceStart, braceEnd + 1, '');
          removed = true;
          start = braceStart;
          break;
        }
        if (removed && start < cleaned.length) {
          // Continue scanning after the last removal to catch multiple blocks
          cleaned = cleaned;
        }
      } while (removed && keys.any((k) => cleaned.contains(k)));

      // Collapse excessive newlines/spaces
      cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      return cleaned;
    } catch (e) {
      debugPrint('stripJsonBlocks failed: $e');
      return text;
    }
  }

  int _findClosingBrace(String text) {
    int depth = 0;
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == '\\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }

      if (ch == '"') {
        inString = true;
        continue;
      }

      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          return i;
        }
      }
    }

    return -1; // No matching closing brace found
  }

  List<Map<String, String>> _parseSuggestedMissions(String text) {
    final List<Map<String, String>> missions = [];

    try {
      // First try to extract from fenced code blocks
      final fence = RegExp(r"```(?:json)?\s*([\s\S]*?)```", multiLine: true);
      for (final match in fence.allMatches(text)) {
        final jsonText = match.group(1);
        if (jsonText != null) {
          try {
            final decoded = jsonDecode(jsonText.trim());
            if (decoded is Map<String, dynamic>) {
              _extractMissionsFromJson(decoded, missions);
            }
          } catch (_) {}
        }
      }

      // Then try to find inline JSON objects
      final blocks = _extractAllJsonObjects(text);
      for (final b in blocks) {
        _extractMissionsFromJson(b, missions);
      }
    } catch (e) {
      debugPrint('parseSuggestedMissions failed: $e');
    }

    return missions;
  }

  void _extractMissionsFromJson(
      Map<String, dynamic> json, List<Map<String, String>> missions) {
    final list = (json['missions'] ?? json['suggestions'] ?? json['tasks']);
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          missions.add({
            'title': (item['title'] ?? '').toString(),
            'description': (item['description'] ?? '').toString(),
            'done': (item['done'] ??
                    item['completedState'] ??
                    'Provide a quick proof of completion.')
                .toString(),
          });
        } else if (item is String) {
          missions.add({
            'title': item,
            'description': '',
            'done': 'Provide a quick proof of completion.',
          });
        }
      }
    }
  }

  Future<void> _acceptSuggestedMission(Map<String, String> m) async {
    final provider = context.read<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return;

    final title = m['title'] ?? 'AI Mission';
    final description = m['description'] ?? 'Suggested by your handler';
    final done = m['done'] ??
        m['completedState'] ??
        'You can clearly show it is finished.';

    try {
      final mission = await provider.missionService.createMission(
        userId: user.id,
        title: title,
        description: description,
        completedState: done,
        type: MissionType.aiSuggested,
      );
      await provider.addMission(mission);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mission added: $title')),
        );
      }
    } catch (e) {
      debugPrint('Error accepting suggested mission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add mission: $e')),
        );
      }
    }
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: AppSpacing.verticalSm,
      child: Row(
        children: [
          Consumer<AppProvider>(
            builder: (context, provider, _) {
              return Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: CyberpunkColors.neonGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: CyberpunkColors.neonGreen.withValues(alpha: 0.3)),
                ),
                child: Text(
                  provider.currentHandler?.avatar ?? '🤖',
                  style: const TextStyle(fontSize: 20),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: CyberpunkColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: CyberpunkColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(),
                const SizedBox(width: 4),
                _buildDot(delay: 200),
                const SizedBox(width: 4),
                _buildDot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot({int delay = 0}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      builder: (context, value, child) {
        return Opacity(
          opacity: (value * 2).clamp(0.0, 1.0),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: CyberpunkColors.neonTeal,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: CyberpunkColors.neonTeal.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () => setState(() {}),
    );
  }
}

class _SuggestedMissionTile extends StatelessWidget {
  final Map<String, String> mission;
  final VoidCallback onAccept;
  const _SuggestedMissionTile({required this.mission, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final title = mission['title'] ?? 'Mission';
    final desc = mission['description'] ?? '';
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: CyberpunkColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:
            Border.all(color: CyberpunkColors.neonTeal.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CyberpunkColors.neonTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.flag_outlined,
                  color: CyberpunkColors.neonTeal, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: context.textStyles.labelMedium!.copyWith(
                      color: CyberpunkColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      style: context.textStyles.bodySmall!
                          .copyWith(color: CyberpunkColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAccept,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CyberpunkColors.neonTeal,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: CyberpunkColors.neonTeal.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  'ACCEPT',
                  style: context.textStyles.labelSmall!.copyWith(
                    color: CyberpunkColors.background,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
