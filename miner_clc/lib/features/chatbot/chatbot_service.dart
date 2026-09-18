import 'chatbot_knowledge.dart';

class ChatbotAnswer {
  const ChatbotAnswer({
    required this.text,
    required this.suggestions,
    this.matchedTopic,
    this.category = 'General',
  });

  final String text;
  final List<String> suggestions;
  final ChatbotTopic? matchedTopic;
  final String category;
}

class ChatbotMessage {
  ChatbotMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestions = const [],
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestions;
}

class ChatbotService {
  ChatbotService._();
  static final ChatbotService instance = ChatbotService._();

  static const List<String> defaultSuggestions = [
    'Límites de gases permitidos',
    '¿Cómo funciona la ventilación automática?',
    'Protocolo ante alerta de metano (CH4)',
    '¿Cómo inicio con cuenta de Google?',
    '¿Cómo hacer un respaldo de la base de datos?',
    '¿Cómo resolver una alerta activa?',
    '¿Cuáles son las zonas mineras?',
  ];

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Procesa una pregunta del usuario y retorna la mejor respuesta estructurada
  ChatbotAnswer ask(String userQuery) {
    final clean = _normalize(userQuery);

    if (clean.isEmpty) {
      return const ChatbotAnswer(
        text: '¡Hola! Soy el **Asistente Inteligente de MINER CLC**. Puedo ayudarte con dudas sobre el monitoreo de gases, ventilación, alertas, respaldo de datos y funcionamiento del software. ¿En qué te puedo orientar hoy?',
        suggestions: defaultSuggestions,
      );
    }

    // Saludos y cortesías
    final greetings = {'hola', 'buenos dias', 'buenas tardes', 'buenas noches', 'que tal', 'saludos', 'hi', 'hello'};
    if (greetings.contains(clean) || clean.startsWith('hola ') || clean.startsWith('buenas ')) {
      return const ChatbotAnswer(
        text: '¡Hola, colega minero! ⛑️ Estoy aquí para resolver tus dudas operativas o técnicas sobre el sistema **MINER CLC**. Puedes preguntarme sobre valores de gases, ventilación, alertas, respaldos o cuentas de usuario.',
        suggestions: [
          'Límites de gases permitidos',
          '¿Cómo funciona la ventilación automática?',
          '¿Cómo acceder con Google?',
        ],
      );
    }

    // Agradecimientos
    if (clean.contains('gracias') || clean.contains('muchas gracias') || clean.contains('perfecto')) {
      return const ChatbotAnswer(
        text: '¡Con gusto! La seguridad en mina subterránea es nuestra máxima prioridad. Si tienes otra duda sobre el sistema o los sensores, aquí estaré para asistirte.',
        suggestions: [
          '¿Cuáles son las zonas mineras?',
          'Protocolo ante alerta de metano (CH4)',
        ],
      );
    }

    // Búsqueda por coincidencia de temas
    ChatbotTopic? bestMatch;
    int maxScore = 0;

    final queryWords = clean.split(' ').where((w) => w.length > 2).toSet();

    for (final topic in ChatbotKnowledge.topics) {
      int score = 0;

      // Coincidencia por palabras clave
      for (final kw in topic.keywords) {
        final normKw = _normalize(kw);
        if (clean.contains(normKw)) {
          score += 15;
        } else {
          final kwWords = normKw.split(' ');
          for (final kwWord in kwWords) {
            if (queryWords.contains(kwWord)) {
              score += 4;
            }
          }
        }
      }

      // Coincidencia por título o resumen
      final normTitle = _normalize(topic.title);
      if (clean.contains(normTitle) || normTitle.contains(clean)) {
        score += 20;
      }

      for (final w in queryWords) {
        if (normTitle.contains(w)) {
          score += 3;
        }
      }

      if (score > maxScore) {
        maxScore = score;
        bestMatch = topic;
      }
    }

    // Si encontramos una coincidencia con puntaje suficiente
    if (bestMatch != null && maxScore >= 8) {
      return ChatbotAnswer(
        text: bestMatch.fullResponse,
        suggestions: bestMatch.suggestions,
        matchedTopic: bestMatch,
        category: bestMatch.category,
      );
    }

    // Si no hubo coincidencia precisa, respuesta asistida con recomendaciones
    return ChatbotAnswer(
      text: '''
No encontré una respuesta exacta para tu consulta, pero puedo ayudarte con los siguientes aspectos de **MINER CLC**:

• **Monitoreo de Gases:** Valores y umbrales de CO, O2, CO2, CH4, H2S y temperatura.
• **Sistema de Ventilación:** Modos AUTO y MANUAL, control de potencia 0-100%.
• **Alertas:** Niveles de riesgo y cómo resolverlas en el sistema.
• **Acceso y Google:** Registro con cuenta real de Google y recuperación de contraseñas.
• **Base de Datos y Respaldos:** Generación de copias y logs de auditoría.

*Selecciona una de las opciones sugeridas o reformula tu pregunta con palabras clave como "gases", "ventilación", "metano" o "respaldo".*
''',
      suggestions: defaultSuggestions.take(4).toList(),
      category: 'Ayuda General',
    );
  }
}
