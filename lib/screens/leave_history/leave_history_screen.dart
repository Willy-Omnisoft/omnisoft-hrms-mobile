import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/leave_record.dart';
import '../../services/omni_mobile_api.dart';
import '../../services/session_service.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  List<LeaveRecord> _leaves = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = context.read<SessionService>();
      final api = OmniMobileApi(
        baseUrl: session.clientUrl,
        db: session.clientDb,
        token: session.token,
      );
      _leaves = await api.getLeaveHistory();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _stateColor(String state) {
    switch (state) {
      case 'validate':
      case 'validate1':
        return AppTheme.primary;
      case 'refuse':
        return AppTheme.error;
      case 'confirm':
        return AppTheme.secondary;
      default:
        return AppTheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _leaves.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 100),
                          Center(child: Text('No leave records yet')),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _leaves.length,
                          itemBuilder: (_, i) => _buildItem(_leaves[i]),
                        ),
                ),
    );
  }

  Widget _buildItem(LeaveRecord r) {
    return Card(
      child: ListTile(
        title: Text(r.leaveType,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${r.dateFrom ?? ''} → ${r.dateTo ?? ''}  ·  ${r.numberOfDays.toStringAsFixed(0)}d',
          style: const TextStyle(fontSize: 13),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _stateColor(r.state).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            r.stateLabel,
            style: TextStyle(
              color: _stateColor(r.state),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
