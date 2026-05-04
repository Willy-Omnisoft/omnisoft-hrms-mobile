import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import '../leave/leave_screen.dart';
import '../leave_history/leave_history_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/face_recognition_service.dart';
import '../../services/holiday_service.dart';
import '../../services/session_service.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _homeKey = GlobalKey<HomeScreenState>();
  final _leaveKey = GlobalKey<LeaveScreenState>();
  final _historyKey = GlobalKey<LeaveHistoryScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeKey),
      LeaveScreen(key: _leaveKey),
      LeaveHistoryScreen(key: _historyKey),
      const ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionService>();
      context.read<HolidayService>().loadFromSession(session);
      context
          .read<FaceRecognitionService>()
          .refreshEnrolledStatus(session);
    });
  }

  void _onTabTap(int i) {
    setState(() => _index = i);
    // Refresh data when switching to these tabs
    if (i == 0) _homeKey.currentState?.refresh();
    if (i == 1) _leaveKey.currentState?.refresh();
    if (i == 2) _historyKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTabTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_rounded),
            label: 'Leave',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
