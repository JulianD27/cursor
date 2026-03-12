import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/window_controller.dart';
import '../../shared/theme.dart';
import 'auth_provider.dart';

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
        return AlertDialog(
          backgroundColor: MinerColors.card,
          title: const Text(
            'Registrar nuevo usuario',
            style: TextStyle(color: MinerColors.text),
          ),
          content: SizedBox(
            width: 380,
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
                  decoration: const InputDecoration(labelText: 'Correo electrónico'),
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
              child: const Text('Registrar'),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'MINER CLC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: MinerColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Acceso al sistema',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MinerColors.text.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 18),
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
                    Text(
                      auth.error!,
                      style: const TextStyle(color: MinerColors.danger),
                      textAlign: TextAlign.center,
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
                          : const Text('Ingresar'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: auth.isLoading ? null : _openRegisterDialog,
                    child: const Text(
                      'Registrar nuevo usuario',
                      style: TextStyle(color: MinerColors.accent),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'DB: localhost:5432 / miner_clc',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: MinerColors.text.withValues(alpha: 0.55),
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

