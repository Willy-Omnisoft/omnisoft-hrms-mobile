import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'services/face_recognition_service.dart';
import 'services/holiday_service.dart';
import 'services/session_service.dart';
import 'screens/company_code/company_code_screen.dart';
import 'screens/home/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionService();
  await session.load();
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
        home: session.isLoggedIn
            ? const HomeShell()
            : const CompanyCodeScreen(),
      ),
    );
  }
}
