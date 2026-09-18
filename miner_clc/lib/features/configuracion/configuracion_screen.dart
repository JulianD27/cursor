import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/alert_notification_service.dart';
import '../auth/auth_provider.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombreCtrl;
  late TextEditingController _correoCtrl;
  late TextEditingController _documentoCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _ubicacionCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _passwordConfirmCtrl;

  // Controladores para Notificaciones de Emergencia
  late TextEditingController _tgTokenCtrl;
  late TextEditingController _tgChatIdCtrl;
  late TextEditingController _twSidCtrl;
  late TextEditingController _twAuthCtrl;
  late TextEditingController _twFromCtrl;
  late TextEditingController _twToCtrl;

  bool _tgEnabled = true;
  bool _twEnabled = false;
  bool _autoDangerAlert = true;
  bool _testingAlert = false;
  bool _savingNotifs = false;

  bool _showPassword = false;
  bool _showPasswordConfirm = false;
  bool _saving = false;
  String? _successMsg;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nombreCtrl    = TextEditingController(text: auth.displayName ?? '');
    _correoCtrl    = TextEditingController(text: auth.email ?? '');
    _documentoCtrl = TextEditingController(text: auth.document ?? '');
    _telefonoCtrl  = TextEditingController();
    _ubicacionCtrl = TextEditingController();
    _passwordCtrl        = TextEditingController();
    _passwordConfirmCtrl = TextEditingController();

    // Inicializar configuración de notificaciones
    final notifService = AlertNotificationService();
    final cfg = notifService.config;
    _tgEnabled = cfg.telegramEnabled;
    _tgTokenCtrl = TextEditingController(text: cfg.telegramBotToken);
    _tgChatIdCtrl = TextEditingController(text: cfg.telegramChatId);
    _twEnabled = cfg.twilioEnabled;
    _twSidCtrl = TextEditingController(text: cfg.twilioAccountSid);
    _twAuthCtrl = TextEditingController(text: cfg.twilioAuthToken);
    _twFromCtrl = TextEditingController(text: cfg.twilioFromPhone);
    _twToCtrl = TextEditingController(text: cfg.twilioToPhone);
    _autoDangerAlert = cfg.autoAlertOnDanger;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _documentoCtrl.dispose();
    _telefonoCtrl.dispose();
    _ubicacionCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();

    _tgTokenCtrl.dispose();
    _tgChatIdCtrl.dispose();
    _twSidCtrl.dispose();
    _twAuthCtrl.dispose();
    _twFromCtrl.dispose();
    _twToCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar contraseñas si se quiere cambiar
    if (_passwordCtrl.text.isNotEmpty &&
        _passwordCtrl.text != _passwordConfirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden'),
          backgroundColor: Color(0xFFE74C3C),
        ),
      );
      return;
    }

    setState(() { _saving = true; _successMsg = null; });

    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      nombre:    _nombreCtrl.text.trim(),
      correo:    _correoCtrl.text.trim(),
      documento: _documentoCtrl.text.trim(),
    );

    setState(() { _saving = false; });

    if (ok) {
      setState(() => _successMsg = '✅ Perfil actualizado correctamente');
      _passwordCtrl.clear();
      _passwordConfirmCtrl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Error al guardar'),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    }
  }

  Future<void> _guardarNotificaciones() async {
    setState(() => _savingNotifs = true);
    final notifService = AlertNotificationService();
    final newCfg = NotificationConfig(
      telegramEnabled: _tgEnabled,
      telegramBotToken: _tgTokenCtrl.text.trim(),
      telegramChatId: _tgChatIdCtrl.text.trim(),
      twilioEnabled: _twEnabled,
      twilioAccountSid: _twSidCtrl.text.trim(),
      twilioAuthToken: _twAuthCtrl.text.trim(),
      twilioFromPhone: _twFromCtrl.text.trim(),
      twilioToPhone: _twToCtrl.text.trim(),
      autoAlertOnDanger: _autoDangerAlert,
    );

    await notifService.saveConfig(newCfg);
    setState(() => _savingNotifs = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Configuración de notificaciones móviles guardada con éxito'),
          backgroundColor: Color(0xFF2ECC71),
        ),
      );
    }
  }

  Future<void> _probarNotificacionCelular() async {
    await _guardarNotificaciones();
    setState(() => _testingAlert = true);
    final res = await AlertNotificationService().sendTestAlert();
    setState(() => _testingAlert = false);

    if (mounted) {
      final bool ok = res['success'] == true;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: ok ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C)),
          ),
          title: Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.error_outline,
                color: ok ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
              ),
              const SizedBox(width: 8),
              Text(
                ok ? '¡Alerta Entregada!' : 'Fallo de Entrega',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                res['message'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (ok)
                const Text(
                  'Revisa tu aplicación de Telegram o SMS en tu celular. Deberías haber recibido la alarma crítica de prueba con sonido.',
                  style: TextStyle(color: Color(0xFF2ECC71), fontSize: 12, fontWeight: FontWeight.bold),
                )
              else
                const Text(
                  'Verifica que el Token del Bot y el Chat ID sean correctos y que le hayas dado clic en /start al bot en Telegram.',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _mostrarAyudaTelegram() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF4A90D9)),
        ),
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: Color(0xFF4A90D9)),
            SizedBox(width: 8),
            Text('¿Cómo configurar Telegram Bot?', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Telegram te permite recibir notificaciones instantáneas de gases en tu celular 100% gratis:\n',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                '1️⃣ Obtener Token del Bot:\n'
                '• Abre Telegram en tu celular o PC y busca el usuario @BotFather.\n'
                '• Escribe el comando /newbot y sigue las instrucciones para asignarle un nombre.\n'
                '• @BotFather te responderá con tu Token HTTP API (ejemplo: 7123456789:AAHk...).\n',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                '2️⃣ Obtener tu Chat ID:\n'
                '• En Telegram busca el bot @userinfobot y presiona /start.\n'
                '• Te responderá con tu ID numérico (ejemplo: 569812345).\n',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                '3️⃣ Iniciar conversación con tu Bot:\n'
                '• Busca el bot que creaste en el paso 1 y presiona /start para autorizar que te envíe mensajes.\n'
                '• Pega aquí el Token y tu Chat ID y haz clic en "Enviar Alerta de Prueba".',
                style: TextStyle(color: Color(0xFF2ECC71), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Color(0xFF4A90D9))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── ENCABEZADO PERFIL ──────────────────────────
                Row(
                  children: [
                    // Avatar grande
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2A2A2A),
                        border: Border.all(
                            color: const Color(0xFF4A90D9), width: 2),
                      ),
                      child: const Icon(Icons.person,
                          size: 38, color: Color(0xFFE0E0E0)),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.displayName ?? auth.username ?? 'Usuario',
                          style: const TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID de usuario: ${auth.userId ?? '—'}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888888)),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── SECCIÓN: INFORMACIÓN PERSONAL ─────────────
                _SectionTitle(
                    icon: Icons.person_outline, label: 'Información personal'),
                const SizedBox(height: 14),

                // Nombre completo
                _Field(
                  label: 'Nombre completo',
                  controller: _nombreCtrl,
                  icon: Icons.badge_outlined,
                  hint: 'Tu nombre completo',
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    // Documento
                    Expanded(
                      child: _Field(
                        label: 'Documento de identidad',
                        controller: _documentoCtrl,
                        icon: Icons.credit_card_outlined,
                        hint: 'CC, CE, NIT...',
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Teléfono
                    Expanded(
                      child: _Field(
                        label: 'Teléfono',
                        controller: _telefonoCtrl,
                        icon: Icons.phone_outlined,
                        hint: '+57 300 000 0000',
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Correo
                _Field(
                  label: 'Correo electrónico',
                  controller: _correoCtrl,
                  icon: Icons.email_outlined,
                  hint: 'correo@empresa.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !v.contains('@')) {
                      return 'Correo no válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Ubicación / Zona
                _Field(
                  label: 'Zona / Ubicación',
                  controller: _ubicacionCtrl,
                  icon: Icons.location_on_outlined,
                  hint: 'Ej: Zona Norte — Nivel 2',
                ),

                const SizedBox(height: 28),

                // ── SECCIÓN: CAMBIAR CONTRASEÑA ────────────────
                _SectionTitle(
                    icon: Icons.lock_outline, label: 'Cambiar contraseña'),
                const SizedBox(height: 6),
                Text(
                  'Deja en blanco si no deseas cambiar tu contraseña.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _PasswordField(
                        label: 'Nueva contraseña',
                        controller: _passwordCtrl,
                        show: _showPassword,
                        onToggle: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PasswordField(
                        label: 'Confirmar contraseña',
                        controller: _passwordConfirmCtrl,
                        show: _showPasswordConfirm,
                        onToggle: () => setState(
                            () => _showPasswordConfirm = !_showPasswordConfirm),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── MENSAJE DE ÉXITO ───────────────────────────
                if (_successMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3A1A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF27AE60).withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Color(0xFF2ECC71), size: 18),
                        const SizedBox(width: 10),
                        Text(_successMsg!,
                            style: const TextStyle(
                                color: Color(0xFF2ECC71), fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── BOTONES ────────────────────────────────────
                Row(
                  children: [
                    // Cancelar / Resetear
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () {
                              final a = context.read<AuthProvider>();
                              _nombreCtrl.text = a.displayName ?? '';
                              _correoCtrl.text = a.email ?? '';
                              _documentoCtrl.text = a.document ?? '';
                              _telefonoCtrl.clear();
                              _ubicacionCtrl.clear();
                              _passwordCtrl.clear();
                              _passwordConfirmCtrl.clear();
                              setState(() => _successMsg = null);
                            },
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF444444)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Guardar
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _guardar,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 16),
                        label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // ── SECCIÓN NOTIFICACIONES DE EMERGENCIA A CELULAR (TELEGRAM & SMS) ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF333333)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.phonelink_ring_outlined, color: Color(0xFF4A90D9), size: 20),
                          const SizedBox(width: 10),
                          const Text(
                            'NOTIFICACIONES DE EMERGENCIA AL CELULAR',
                            style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.help_outline, color: Color(0xFF4A90D9), size: 20),
                            tooltip: '¿Cómo configurar Telegram Bot?',
                            onPressed: _mostrarAyudaTelegram,
                          ),
                        ],
                      ),
                      const Text(
                        'Despacho automático de alertas críticas de gases (CH4, CO, O2, H2S) directamente al smartphone del ingeniero de turno.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF2C2C2C)),
                      const SizedBox(height: 12),

                      // 1. TELEGRAM BOT
                      Row(
                        children: [
                          Switch(
                            value: _tgEnabled,
                            activeColor: const Color(0xFF2ECC71),
                            onChanged: (v) => setState(() => _tgEnabled = v),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.send_rounded, color: Color(0xFF4A90D9), size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Alertas Push por Telegram Bot (100% Gratis)',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _mostrarAyudaTelegram,
                            icon: const Icon(Icons.info_outline, size: 14, color: Color(0xFF4A90D9)),
                            label: const Text('Instrucciones', style: TextStyle(color: Color(0xFF4A90D9), fontSize: 11)),
                          ),
                        ],
                      ),
                      if (_tgEnabled) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _Field(
                                label: 'TOKEN DEL BOT (DE @BOTFATHER)',
                                controller: _tgTokenCtrl,
                                icon: Icons.vpn_key_outlined,
                                hint: 'Ej: 7123456789:AAHk1234567890abcdef...',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: _Field(
                                label: 'CHAT ID DEL INGENIERO (DE @USERINFOBOT)',
                                controller: _tgChatIdCtrl,
                                icon: Icons.chat_bubble_outline,
                                hint: 'Ej: 569812345',
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFF2C2C2C)),
                      const SizedBox(height: 12),

                      // 2. TWILIO SMS
                      Row(
                        children: [
                          Switch(
                            value: _twEnabled,
                            activeColor: const Color(0xFF2ECC71),
                            onChanged: (v) => setState(() => _twEnabled = v),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.sms_outlined, color: Colors.orangeAccent, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Alertas por SMS tradicional (Twilio REST API)',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (_twEnabled) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _Field(
                                label: 'TWILIO ACCOUNT SID',
                                controller: _twSidCtrl,
                                icon: Icons.account_circle_outlined,
                                hint: 'ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _Field(
                                label: 'TWILIO AUTH TOKEN',
                                controller: _twAuthCtrl,
                                icon: Icons.lock_outline,
                                hint: 'your_auth_token',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _Field(
                                label: 'TELÉFONO REMITENTE (TWILIO)',
                                controller: _twFromCtrl,
                                icon: Icons.phone_forwarded,
                                hint: '+1234567890',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _Field(
                                label: 'TELÉFONO INGENIERO (DESTINO)',
                                controller: _twToCtrl,
                                icon: Icons.phone_android,
                                hint: '+573001234567',
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),
                      // Switch de auto-alerta
                      Row(
                        children: [
                          Checkbox(
                            value: _autoDangerAlert,
                            activeColor: const Color(0xFFE74C3C),
                            onChanged: (v) => setState(() => _autoDangerAlert = v ?? true),
                          ),
                          const Expanded(
                            child: Text(
                              'Enviar alerta al celular automáticamente cuando cualquier sensor entre en estado de PELIGRO CRÍTICO (DANGER)',
                              style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      // Botones de acción de notificaciones
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _savingNotifs ? null : _guardarNotificaciones,
                            icon: _savingNotifs
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_outlined, size: 16),
                            label: const Text('Guardar Ajustes'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF4A90D9)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _testingAlert ? null : _probarNotificacionCelular,
                            icon: _testingAlert
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.notifications_active_outlined, size: 16),
                            label: Text(_testingAlert ? 'Enviando alerta...' : '📲 Enviar Alerta de Prueba a mi Celular'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE67E22),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WIDGETS AUXILIARES
// ─────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4A90D9), size: 18),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A90D9),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: Color(0xFF444444))),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF888888),
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF888888)),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF444444)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF444444)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF4A90D9), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool show;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.show,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF888888),
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: !show,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline,
                size: 18, color: Color(0xFF888888)),
            suffixIcon: IconButton(
              icon: Icon(
                show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF888888),
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF444444)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF444444)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF4A90D9), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}