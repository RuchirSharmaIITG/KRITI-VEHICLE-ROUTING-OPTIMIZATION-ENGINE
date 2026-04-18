import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'services/app_state.dart';
import 'screens/landing_page.dart';
import 'screens/dashboard_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF020617),
  ));
  runApp(const VeloraApp());
}

class VeloraApp extends StatelessWidget {
  const VeloraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'VELORA',
        debugShowCheckedModeBanner: false,
        theme: veloraTheme(),
        home: const VeloraHome(),
      ),
    );
  }
}

class VeloraHome extends StatelessWidget {
  const VeloraHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        // Mirrors the view === 'dashboard' check in page.js
        if (state.view == 'dashboard') {
          return const DashboardPage();
        }
        return const LandingPage();
      },
    );
  }
}
