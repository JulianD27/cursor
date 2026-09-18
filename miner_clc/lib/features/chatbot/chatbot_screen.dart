import 'package:flutter/material.dart';
import 'chatbot_dialog.dart';

class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: ChatbotDialog(),
    );
  }
}
