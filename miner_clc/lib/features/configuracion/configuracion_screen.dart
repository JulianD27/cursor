import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme.dart';
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