import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../user_management/presentation/providers/auth_provider.dart';
import '../../data/services/ai_assistant_service.dart';

class AiAssistantRecommendationsPage extends ConsumerStatefulWidget {
  const AiAssistantRecommendationsPage({super.key});

  @override
  ConsumerState<AiAssistantRecommendationsPage> createState() => _AiAssistantRecommendationsPageState();
}

class _AiAssistantRecommendationsPageState extends ConsumerState<AiAssistantRecommendationsPage> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AiAssistantService _aiService;
  bool _isTyping = false;

  final Color bgIvory = const Color(0xFFF5F3EE);
  final Color surfaceWhite = const Color(0xFFFFFFFF);
  final Color borderSubtle = const Color(0xFFDCD8D0);
  final Color textPrimary = const Color(0xFF1B1B19);
  final Color textMuted = const Color(0xFF716F68);
  final Color accentGold = const Color(0xFF8C692E);
  final Color accentChampagne = const Color(0xFFD7BC83);

  @override
  void initState() {
    super.initState();
    _aiService = AiAssistantService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        setState(() {
          _messages.add({
            'sender': 'ai',
            'text': 'Bonjour ${user.name} ! ✨ Je suis votre assistant CINEA personnel. Comment puis-je vous guider dans votre catalogue ou votre abonnement ce soir ?'
          });
        });
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    _messageController.clear();
    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isTyping = true;
    });
    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);

    final aiResponse = await _aiService.askAssistant(message: text, currentUser: user);

    setState(() {
      _isTyping = false;
      _messages.add({'sender': 'ai', 'text': aiResponse});
    });
    Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgIvory,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: borderSubtle, width: 1)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFFE8F2EB), shape: BoxShape.circle),
              child: const Text('🧠', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Text(
              'ASSISTANT CONSEILLER CINEA',
              style: TextStyle(color: accentGold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['sender'] == 'user';

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: isUser ? textPrimary : surfaceWhite,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isUser ? 18 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 18),
                        ),
                        border: isUser ? null : Border.all(color: borderSubtle),
                        boxShadow: isUser ? null : [
                          BoxShadow(
                            color: const Color(0xFF272116).withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Text(
                        msg['text']!,
                        style: TextStyle(
                          color: isUser ? surfaceWhite : textPrimary,
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Cinea Assistant analyse le catalogue...',
                    style: TextStyle(color: textMuted, fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              color: surfaceWhite, // 💡 CORRIGÉ : Propriété valide pour la couleur de fond
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Posez une question sur un film, votre offre...',
                        hintStyle: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.normal),
                        filled: true,
                        fillColor: bgIvory,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentChampagne, width: 1)),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(color: textPrimary, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
