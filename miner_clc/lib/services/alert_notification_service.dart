import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../utils/logger_service.dart';

/// Modelo de configuración de notificaciones
class NotificationConfig {
  bool telegramEnabled;
  String telegramBotToken;
  String telegramChatId;
  bool twilioEnabled;
  String twilioAccountSid;
  String twilioAuthToken;
  String twilioFromPhone;
  String twilioToPhone;
  bool autoAlertOnDanger;

  NotificationConfig({
    this.telegramEnabled = true,
    this.telegramBotToken = '',
    this.telegramChatId = '',
    this.twilioEnabled = false,
    this.twilioAccountSid = '',
    this.twilioAuthToken = '',
    this.twilioFromPhone = '',
    this.twilioToPhone = '',
    this.autoAlertOnDanger = true,
  });

  Map<String, dynamic> toJson() => {
        'telegramEnabled': telegramEnabled,
        'telegramBotToken': telegramBotToken,
        'telegramChatId': telegramChatId,
        'twilioEnabled': twilioEnabled,
        'twilioAccountSid': twilioAccountSid,
        'twilioAuthToken': twilioAuthToken,
        'twilioFromPhone': twilioFromPhone,
        'twilioToPhone': twilioToPhone,
        'autoAlertOnDanger': autoAlertOnDanger,
      };

  factory NotificationConfig.fromJson(Map<String, dynamic> json) => NotificationConfig(
        telegramEnabled: json['telegramEnabled'] ?? true,
        telegramBotToken: json['telegramBotToken'] ?? '',
        telegramChatId: json['telegramChatId'] ?? '',
        twilioEnabled: json['twilioEnabled'] ?? false,
        twilioAccountSid: json['twilioAccountSid'] ?? '',
        twilioAuthToken: json['twilioAuthToken'] ?? '',
        twilioFromPhone: json['twilioFromPhone'] ?? '',
        twilioToPhone: json['twilioToPhone'] ?? '',
        autoAlertOnDanger: json['autoAlertOnDanger'] ?? true,
      );
}

/// Servicio encargado del envío de alertas móviles al celular del ingeniero
class AlertNotificationService {
  static final AlertNotificationService _instance = AlertNotificationService._internal();
  factory AlertNotificationService() => _instance;
  AlertNotificationService._internal() {
    _loadConfig();
  }

  NotificationConfig _config = NotificationConfig();
  NotificationConfig get config => _config;

  final Set<String> _recentAlertKeys = {};
  DateTime _lastDispatch = DateTime.fromMillisecondsSinceEpoch(0);

  File get _configFile => File('notification_settings.json');

  void _loadConfig() {
    try {
      if (_configFile.existsSync()) {
        final content = _configFile.readAsStringSync();
        _config = NotificationConfig.fromJson(jsonDecode(content));
      }
    } catch (e) {
      LoggerService.instance.error(
        module: 'NOTIFICATIONS',
        action: 'LOAD_CONFIG',
        message: 'Error cargando configuración de notificaciones: $e',
      );
    }
  }

  Future<void> saveConfig(NotificationConfig newConfig) async {
    _config = newConfig;
    try {
      await _configFile.writeAsString(jsonEncode(_config.toJson()), flush: true);
      LoggerService.instance.info(
        module: 'NOTIFICATIONS',
        action: 'SAVE_CONFIG',
        message: 'Configuración de notificaciones guardada exitosamente.',
      );
    } catch (e) {
      LoggerService.instance.error(
        module: 'NOTIFICATIONS',
        action: 'SAVE_CONFIG',
        message: 'Error guardando configuración de notificaciones: $e',
      );
    }
  }

  /// Envía una alerta crítica a Telegram
  Future<Map<String, dynamic>> sendTelegramAlert({
    required String zone,
    required String gas,
    required double value,
    required String level,
    String? details,
  }) async {
    if (!_config.telegramEnabled) {
      return {'success': false, 'message': 'Telegram no está habilitado'};
    }

    final token = _config.telegramBotToken.trim();
    final chatId = _config.telegramChatId.trim();

    if (token.isEmpty || chatId.isEmpty) {
      return {
        'success': false,
        'message': 'Token de Bot o Chat ID no configurados. Configúralos en Ajustes.'
      };
    }

    final nowStr = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');
    final isDanger = level.toLowerCase().contains('danger') || level.toLowerCase().contains('peligro');
    final headerEmoji = isDanger ? '🚨 *ALERTA CRÍTICA DE MINA*' : '⚠️ *ADVERTENCIA DE GASES*';

    final text = '''
$headerEmoji
*MINER CLC - Sistema de Seguridad Subterránea*
━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 *Zona Afectada:* `$zone`
⚡ *Nivel:* *${level.toUpperCase()}*
💨 *Gas Detectado:* `$gas` (${value.toStringAsFixed(2)})
⏰ *Hora de Registro:* `$nowStr`
${details != null && details.isNotEmpty ? '📝 *Detalle:* $details\n' : ''}━━━━━━━━━━━━━━━━━━━━━━━━━━
🚨 *Protocolo Operativo Sugerido:*
${isDanger ? '• EVACUAR PERSONAL DE LA GALERÍA INMEDIATAMENTE.\n• Activar ventilador de tiro forzado al 100%.\n• Notificar a brigada de rescate minero.' : '• Verificar flujo de ventilación.\n• Restringir ingreso preventivo.'}
''';

    try {
      final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': text,
          'parse_mode': 'Markdown',
        }),
      ).timeout(const Duration(seconds: 8));

      final resBody = jsonDecode(response.body);
      if (response.statusCode == 200 && resBody['ok'] == true) {
        LoggerService.instance.info(
          module: 'NOTIFICATIONS',
          action: 'TELEGRAM_DISPATCH',
          message: 'Alerta Telegram despachada exitosamente a chat $chatId',
        );
        return {'success': true, 'message': 'Mensaje enviado a Telegram correctamente'};
      } else {
        final desc = resBody['description'] ?? 'Error desconocido';
        LoggerService.instance.error(
          module: 'NOTIFICATIONS',
          action: 'TELEGRAM_ERROR',
          message: 'Error enviando Telegram: $desc',
        );
        return {'success': false, 'message': 'Error Telegram: $desc'};
      }
    } catch (e) {
      LoggerService.instance.error(
        module: 'NOTIFICATIONS',
        action: 'TELEGRAM_EXCEPTION',
        message: 'Excepción al conectar con Telegram API: $e',
      );
      return {'success': false, 'message': 'Fallo de conexión con Telegram: $e'};
    }
  }

  /// Envía un SMS a través de Twilio
  Future<Map<String, dynamic>> sendTwilioSms({
    required String body,
    String? overridePhone,
  }) async {
    if (!_config.twilioEnabled) {
      return {'success': false, 'message': 'Twilio SMS no está habilitado'};
    }

    final sid = _config.twilioAccountSid.trim();
    final auth = _config.twilioAuthToken.trim();
    final from = _config.twilioFromPhone.trim();
    final to = (overridePhone ?? _config.twilioToPhone).trim();

    if (sid.isEmpty || auth.isEmpty || from.isEmpty || to.isEmpty) {
      return {
        'success': false,
        'message': 'Credenciales Twilio incompletas (SID, AuthToken, Teléfonos).'
      };
    }

    try {
      final url = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$sid/Messages.json');
      final basicAuth = base64Encode(utf8.encode('$sid:$auth'));

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $basicAuth',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': from,
          'To': to,
          'Body': body,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        LoggerService.instance.info(
          module: 'NOTIFICATIONS',
          action: 'TWILIO_DISPATCH',
          message: 'SMS Twilio despachado exitosamente a $to',
        );
        return {'success': true, 'message': 'SMS enviado a $to correctamente'};
      } else {
        final resBody = jsonDecode(response.body);
        final msg = resBody['message'] ?? 'Error Twilio HTTP ${response.statusCode}';
        LoggerService.instance.error(
          module: 'NOTIFICATIONS',
          action: 'TWILIO_ERROR',
          message: 'Error Twilio: $msg',
        );
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      LoggerService.instance.error(
        module: 'NOTIFICATIONS',
        action: 'TWILIO_EXCEPTION',
        message: 'Excepción al conectar con Twilio: $e',
      );
      return {'success': false, 'message': 'Fallo de conexión Twilio: $e'};
    }
  }

  /// Envía una notificación de prueba para verificar conectividad con el teléfono
  Future<Map<String, dynamic>> sendTestAlert() async {
    final results = <String, dynamic>{};

    if (_config.telegramEnabled) {
      results['telegram'] = await sendTelegramAlert(
        zone: 'Norte - Nivel 1 (Prueba de Sistema)',
        gas: 'Metano CH4 (Simulado)',
        value: 2.15,
        level: 'danger',
        details: 'Esta es una prueba de verificación del API de Notificaciones Push de MINER CLC al teléfono del ingeniero.',
      );
    }

    if (_config.twilioEnabled) {
      results['twilio'] = await sendTwilioSms(
        body: 'MINER CLC: Alerta de prueba. El sistema de notificaciones SMS esta activo y conectado.',
      );
    }

    if (!_config.telegramEnabled && !_config.twilioEnabled) {
      return {
        'success': false,
        'message': 'Ningún canal (Telegram o Twilio) está habilitado. Activa al menos uno en Configuración.',
      };
    }

    final bool tgOk = results['telegram']?['success'] ?? false;
    final bool twOk = results['twilio']?['success'] ?? false;
    final bool anyOk = tgOk || twOk;

    return {
      'success': anyOk,
      'details': results,
      'message': anyOk
          ? '¡Notificación de prueba enviada con éxito a tu dispositivo!'
          : 'No se pudo entregar la alerta: ${results['telegram']?['message'] ?? results['twilio']?['message']}',
    };
  }

  /// Procesador de auto-despacho para lecturas críticas
  Future<void> evaluateAndDispatchEmergency({
    required String zone,
    required String gas,
    required double value,
    required String level,
    String? message,
  }) async {
    if (!_config.autoAlertOnDanger) return;
    if (!level.toLowerCase().contains('danger') && !level.toLowerCase().contains('peligro')) return;

    // Control de frecuencia para no saturar al ingeniero (máximo 1 alerta por zona cada 3 minutos)
    final key = '$zone-$gas';
    final now = DateTime.now();
    if (_recentAlertKeys.contains(key) && now.difference(_lastDispatch).inMinutes < 3) {
      return;
    }

    _recentAlertKeys.add(key);
    _lastDispatch = now;

    // Despacho a canales activos
    if (_config.telegramEnabled) {
      await sendTelegramAlert(
        zone: zone,
        gas: gas,
        value: value,
        level: level,
        details: message,
      );
    }

    if (_config.twilioEnabled) {
      await sendTwilioSms(
        body: 'ALERTA MINER CLC: PELIGRO CRITICO en $zone. $gas: $value. Evacue la galeria de inmediato.',
      );
    }
  }
}
