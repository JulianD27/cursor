import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chatbot_service.dart';

/// Modal o pantalla interactiva del Chatbot Asistente de MINER CLC
class ChatbotDialog extends StatefulWidget {
  const ChatbotDialog({super.key, this.initialQuery});

  final String? initialQuery;

  static Future<void> show(BuildContext context, {String? initialQuery}) {
    return showDialog(
      context: context,
      builder: (_) => ChatbotDialog(initialQuery: initialQuery),
    );
  }

  @override
  State<ChatbotDialog> createState() => _ChatbotDialogState();
}

class _ChatbotDialogState extends State<ChatbotDialog> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<ChatbotMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    // Mensaje inicial de bienvenida
    _messages.add(
      ChatbotMessage(
        text: '¡Hola! ⛑️ Soy tu **Asistente Inteligente de MINER CLC**.\n\nPuedo resolver cualquier duda sobre el funcionamiento del software, límites permisibles de gases, ventilación, protocolos de emergencia y base de datos.\n\n¿En qué puedo ayudarte hoy?',
        isUser: false,
        timestamp: DateTime.now(),
        suggestions: ChatbotService.defaultSuggestions,
      ),
    );

    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSend(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _handleSend([String? presetText]) {
    final text = (presetText ?? _inputCtrl.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        ChatbotMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      if (presetText == null) {
        _inputCtrl.clear();
      }
    });

    _scrollToBottom();

    // Procesar con el motor inteligente
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final answer = ChatbotService.instance.ask(text);
      setState(() {
        _messages.add(
          ChatbotMessage(
            text: answer.text,
            isUser: false,
            timestamp: DateTime.now(),
            suggestions: answer.suggestions,
          ),
        );
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        ChatbotMessage(
          text: 'Conversación reiniciada. ¿En qué más puedo asistirte?',
          isUser: false,
          timestamp: DateTime.now(),
          suggestions: ChatbotService.defaultSuggestions,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF444444)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 620,
          maxHeight: 720,
        ),
        child: Column(
          children: [
            // ── HEADER ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF242424),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(bottom: BorderSide(color: Color(0xFF383838))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E5B88),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4A90D9)),
                    ),
                    child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'ASISTENTE MINERO CLC',
                              style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A3A1A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  CircleAvatar(radius: 3, backgroundColor: Colors.greenAccent),
                                  SizedBox(width: 4),
                                  Text(
                                    'Activo',
                                    style: TextStyle(fontSize: 10, color: Colors.greenAccent),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Soporte técnico, dudas operativas y protocolos mineros',
                          style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF9E9E9E), size: 20),
                    tooltip: 'Reiniciar conversación',
                    onPressed: _clearChat,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF9E9E9E), size: 20),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── LISTA DE MENSAJES ──
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _MessageBubble(
                    message: msg,
                    onSuggestionTap: (sug) => _handleSend(sug),
                  );
                },
              ),
            ),

            // ── CHIPS DE SUGERENCIAS RÁPIDAS (ÚLTIMAS) ──
            if (_messages.isNotEmpty && _messages.last.suggestions.isNotEmpty)
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _messages.last.suggestions.length,
                  itemBuilder: (context, i) {
                    final chipText = _messages.last.suggestions[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor: const Color(0xFF2C2C2C),
                        side: const BorderSide(color: Color(0xFF4A90D9), width: 0.8),
                        label: Text(
                          chipText,
                          style: const TextStyle(fontSize: 11, color: Color(0xFFE0E0E0)),
                        ),
                        onPressed: () => _handleSend(chipText),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 6),

            // ── BARRA DE ENTRADA ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF242424),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(top: BorderSide(color: Color(0xFF383838))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Pregunta sobre gases, ventilación, alertas o funcionamiento...',
                        hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF181818),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF444444)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF4A90D9)),
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90D9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleSend(),
                    child: const Icon(Icons.send_rounded, size: 18),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onSuggestionTap,
  });

  final ChatbotMessage message;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8, top: 2),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF2E5B88),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4A90D9), width: 1.2),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF2E5B88) : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(10).copyWith(
                  bottomRight: isUser ? Radius.zero : const Radius.circular(10),
                  bottomLeft: !isUser ? Radius.zero : const Radius.circular(10),
                ),
                border: Border.all(
                  color: isUser ? const Color(0xFF4A90D9) : const Color(0xFF3D3D3D),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFFE8E8E8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser ? Colors.white70 : const Color(0xFF888888),
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: message.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copiado al portapapeles'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF888888)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              margin: const EdgeInsets.only(left: 8, top: 2),
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF333333),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white70, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
