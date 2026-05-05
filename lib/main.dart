import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'services/face_recognition_service.dart';
import 'services/holiday_service.dart';
import 'services/omni_mobile_api.dart';
import 'services/session_service.dart';
import 'screens/company_code/company_code_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/login/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionService();
  await session.load();

  // When any /api/v1 call returns invalid_session, wipe the local
  // auth session so the top-level Consumer below re-renders to the
  // Login screen. SaaS routing (company code) is preserved.
  OmniMobileApi.onInvalidSession = () {
    session.clearSession();
  };

  runApp(OmniHrApp(session: session));
}

class OmniHrApp extends StatelessWidget {
  final SessionService session;
  const OmniHrApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => HolidayService()),
        ChangeNotifierProvider(create: (_) => FaceRecognitionService()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        // Reactive routing: rebuilds when session state changes.
        //   no company resolved      → CompanyCodeScreen
        //   company set, not signed  → LoginScreen
        //   signed in                → HomeShell
        home: Consumer<SessionService>(
          builder: (_, s, __) {
            if (!s.hasCompany) return const CompanyCodeScreen();
            if (!s.isLoggedIn) return const LoginScreen();
            return const HomeShell();
          },
        ),
      ),
    );
  }
}
