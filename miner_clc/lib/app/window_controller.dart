import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowController {
  static Future<void> ensureInitialized() async {
    if (!kIsWeb) {
      WidgetsFlutterBinding.ensureInitialized();
      await windowManager.ensureInitialized();
    }
  }

  static Future<void> setMinimumMainSize() async {
    if (kIsWeb) return;
    await windowManager.setMinimumSize(const Size(1024, 768));
  }

  static Future<void> showLoginWindow() async {
    if (kIsWeb) return;
    await windowManager.setMinimumSize(const Size(400, 500));
    await windowManager.maximize();
    await windowManager.setFullScreen(false);
    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> showMainWindow() async {
    if (kIsWeb) return;
    await windowManager.setMinimumSize(const Size(1024, 768));
    await windowManager.maximize();
    await windowManager.setFullScreen(false);
    await windowManager.show();
    await windowManager.focus();
  }

  /// Minimiza la ventana principal (solo escritorio).
  static Future<void> minimize() async {
    if (kIsWeb) return;
    await windowManager.minimize();
  }

  /// Alterna entre maximizada y restaurada (solo escritorio).
  static Future<void> toggleMaximize() async {
    if (kIsWeb) return;
    final isMax = await windowManager.isMaximized();
    if (isMax) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  /// Cierra la ventana / aplicación (solo escritorio).
  static Future<void> close() async {
    if (kIsWeb) return;
    await windowManager.close();
  }
}

