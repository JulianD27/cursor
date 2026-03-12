import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/window_controller.dart';
import 'features/alertas/alertas_provider.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_provider.dart';
import 'features/gases/gases_provider.dart';
import 'features/shell/sidebar_shell.dart';
import 'features/ventilacion/ventilacion_provider.dart';
import 'shared/theme.dart';

Future<void> main() async {
  await WindowController.ensureInitialized();
  runApp(const MinerApp());
}

class MinerApp extends StatelessWidget {
  const MinerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => GasesProvider()),
        ChangeNotifierProvider(create: (_) => VentilacionProvider()),
        ChangeNotifierProvider(create: (_) => AlertasProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MINER CLC',
        theme: buildMinerTheme(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isLoggedIn) return const SidebarShell();
    return const LoginScreen();
  }
}
