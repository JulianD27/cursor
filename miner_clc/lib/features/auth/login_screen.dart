import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/window_controller.dart';
import '../../shared/theme.dart';
import 'auth_provider.dart';
import 'google_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Ensure correct window size on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WindowController.showLoginWindow();
    });
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    if (!ok) return;
    // Navigation handled by root based on auth state.
  }

  /// Diálogo para iniciar sesión o registrarse con cuenta de Google REAL
  Future<void> _openGoogleSignInDialog() async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String? validationError;
    bool isValidGoogle = false;

    final auth = context.read<AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: MinerColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Image.network(
                      'https://www.gstatic.com/images/branding/product/1x/gsa_542px.png',
                      height: 22,
                      width: 22,
                      errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Colors.red, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Acceder con Google',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: MinerColors.text,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ingresa tu cuenta de Google real para registrarte o iniciar sesión en MINER CLC.',
                      style: TextStyle(fontSize: 13, color: MinerColors.textWithAlpha),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      decoration: InputDecoration(
                        labelText: 'Correo de Google (*@gmail.com o corporativo)',
                        prefixIcon: const Icon(Icons.email_outlined),
                        errorText: validationError,
                        helperText: isValidGoogle ? '✓ Cuenta de Google válida' : null,
                        helperStyle: const TextStyle(color: Colors.green),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (val) {
                        final res = GoogleAuthService.validateGoogleEmail(val);
                        setModalState(() {
                          if (!res.isValid) {
                            validationError = res.error;
                            isValidGoogle = false;
                          } else {
                            validationError = null;
                            isValidGoogle = true;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo (como figura en Google)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.verified_user_outlined, color: Colors.blueAccent, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'El sistema valida que sea una cuenta de Google real y no un correo temporal.',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                  ),
                  onPressed: () {
                    final res = GoogleAuthService.validateGoogleEmail(emailCtrl.text);
                    if (!res.isValid) {
                      setModalState(() {
                        validationError = res.error;
                      });
                      return;
                    }
                    Navigator.pop(dialogCtx, true);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.login, size: 18),
                      SizedBox(width: 6),
                      Text('Continuar con Google', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final success = await auth.signInWithGoogle(
      email: emailCtrl.text.trim(),
      fullName: nameCtrl.text.trim(),
    );

    if (!mounted) return;
    if (!success && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error!),
          backgroundColor: MinerColors.danger,
        ),
      );
    }
  }

  Future<void> _openRegisterDialog() async {
    final userCtrl = TextEditingController();
    final nombreCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final auth = context.read<AuthProvider>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        String? emailError;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: MinerColors.card,
              title: const Text(
                'Registrar nuevo usuario',
                style: TextStyle(color: MinerColors.text),
              ),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: userCtrl,
                        decoration: const InputDecoration(labelText: 'Usuario (login)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nombreCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre completo'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: correoCtrl,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico real',
                          errorText: emailError,
                        ),
                        onChanged: (val) {
                          if (val.trim().isNotEmpty) {
                            final res = GoogleAuthService.validateGoogleEmail(val);
                            setModalState(() {
                              emailError = res.isValid ? null : res.error;
                            });
                          } else {
                            setModalState(() => emailError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: docCtrl,
                        decoration: const InputDecoration(labelText: 'Documento de identidad'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contraseña'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: confirmCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.g_mobiledata, color: Colors.red, size: 22),
                        label: const Text('¿Prefieres registrarte con Google?'),
                        onPressed: () {
                          Navigator.pop(context, false);
                          _openGoogleSignInDialog();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (correoCtrl.text.trim().isNotEmpty) {
                      final val = GoogleAuthService.validateGoogleEmail(correoCtrl.text.trim());
                      if (!val.isValid) {
                        setModalState(() => emailError = val.error);
                        return;
                      }
                    }

                    if (passCtrl.text != confirmCtrl.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Las contraseñas no coinciden')),
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Registrar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    await auth.register(
      username: userCtrl.text.trim(),
      password: passCtrl.text,
      nombre: nombreCtrl.text.trim(),
      correo: correoCtrl.text.trim(),
      documento: docCtrl.text.trim(),
    );
  }

  Future<void> _openResetPasswordDialog() async {
    final userCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final auth = context.read<AuthProvider>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: MinerColors.card,
          title: const Text(
            'Recuperar contraseña',
            style: TextStyle(color: MinerColors.text),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: docCtrl,
                  decoration: const InputDecoration(labelText: 'Documento de identidad'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Las contraseñas no coinciden')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Restablecer'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final success = await auth.resetPassword(
      username: userCtrl.text.trim(),
      identificacion: docCtrl.text.trim(),
      newPassword: passCtrl.text,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Contraseña restablecida correctamente. Ingresa con la nueva contraseña.'
            : auth.error ?? 'No se pudo restablecer la contraseña.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF333333)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.construction, color: MinerColors.accent, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'MINER CLC',
                        style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: MinerColors.text,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sistema de Gestión y Seguridad Minera',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: MinerColors.text.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // BOTÓN OFICIAL DE GOOGLE SIGN-IN
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1F1F1F),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: auth.isLoading ? null : _openGoogleSignInDialog,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.network(
                          'https://www.gstatic.com/images/branding/product/1x/gsa_542px.png',
                          height: 20,
                          width: 20,
                          errorBuilder: (_, __, ___) => const Icon(Icons.account_circle, color: Colors.blueAccent, size: 20),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Continuar con Google',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFF444444))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'O CON USUARIO LOCAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: MinerColors.text.withValues(alpha: 0.5),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFF444444))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _userCtrl,
                    enabled: !auth.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    enabled: !auth.isLoading,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 14),
                  if (auth.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MinerColors.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: MinerColors.danger.withOpacity(0.5)),
                      ),
                      child: Text(
                        auth.error!,
                        style: const TextStyle(color: MinerColors.danger, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Ingresar con Credenciales'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: auth.isLoading ? null : _openRegisterDialog,
                        child: const Text(
                          'Registrar usuario',
                          style: TextStyle(color: MinerColors.accent, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: auth.isLoading ? null : _openResetPasswordDialog,
                        child: const Text(
                          'Olvidé mi contraseña',
                          style: TextStyle(color: MinerColors.accent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF333333)),
                  const SizedBox(height: 4),
                  Text(
                    'DB: PostgreSQL / miner_clc (Seguridad Activa)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: MinerColors.text.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
