import 'package:flutter/material.dart';
import '../attendance_history/attendance_history_screen.dart';
import '../leave_history/leave_history_screen.dart';

enum _HistoryTab { leave, attendance }

class HistoryShell extends StatefulWidget {
  const HistoryShell({super.key});

  @override
  State<HistoryShell> createState() => HistoryShellState();
}

class HistoryShellState extends State<HistoryShell> {
  _HistoryTab _tab = _HistoryTab.leave;

  final _leaveKey = GlobalKey<LeaveHistoryScreenState>();
  final _attendanceKey = GlobalKey<AttendanceHistoryScreenState>();

  /// Called by HomeShell when the user taps the History bottom-nav icon.
  /// Refreshes the currently visible sub-tab so re-tapping always pulls
  /// fresh data, matching the behavior the leave screen had on its own.
  Future<void> refresh() async {
    if (_tab == _HistoryTab.leave) {
      await _leaveKey.currentState?.refresh();
    } else {
      await _attendanceKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_HistoryTab>(
                segments: const [
                  ButtonSegment(
                    value: _HistoryTab.leave,
                    label: Text('Leave'),
                    icon: Icon(Icons.event_busy_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: _HistoryTab.attendance,
                    label: Text('Attendance'),
                    icon: Icon(Icons.fingerprint_rounded, size: 18),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
          Expanded(
            // IndexedStack keeps both screens alive — switching is instant
            // and pull-to-refresh state is preserved per tab.
            child: IndexedStack(
              index: _tab.index,
              children: [
                LeaveHistoryScreen(key: _leaveKey),
                AttendanceHistoryScreen(key: _attendanceKey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
