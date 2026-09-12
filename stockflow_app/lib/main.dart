import 'dart:developer' as dev;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables safely
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional; fallback defaults are used in ApiEndpoints
  }

  // Initialize Firebase — gracefully disabled if config is absent
  try {
    await Firebase.initializeApp();
    dev.log('[Firebase] Initialized successfully.', name: 'StockFlow.Firebase');
  } catch (e) {
    dev.log(
      '[Firebase] Not configured — notifications disabled. Error: $e',
      name: 'StockFlow.Firebase',
    );
  }

  runApp(
    const ProviderScope(
      child: StockFlowApp(),
    ),
  );
}

class StockFlowApp extends ConsumerWidget {
  const StockFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'StockFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
