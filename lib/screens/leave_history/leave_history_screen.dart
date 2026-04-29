import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/leave_record.dart';
import '../../services/omni_mobile_api.dart';
import '../../services/session_service.dart';

class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => LeaveHistoryScreenState();
}

class LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  List<LeaveRecord> _leaves = [];
  bool _loading = true;
  String? _error;
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  Future<void> refresh() async {
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
                  onRefresh: refresh,
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
    final expanded = _expandedId == r.id;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(
            () => _expandedId = expanded ? null : r.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.leaveType,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          '${r.dateFrom ?? ''} → ${r.dateTo ?? ''}  ·  ${r.numberOfDays.toStringAsFixed(0)}d',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _stateColor(r.state).withValues(alpha: 0.1),
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
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppTheme.outline,
                    size: 20,
                  ),
                ],
              ),
              // Expanded details
              if (expanded) ...[
                const Divider(height: 24),
                if (r.reason.isNotEmpty)
                  _detailRow('Reason', r.reason),
                if (r.requiresAllocation &&
                    r.allocationTotal != null) ...[
                  _detailRow(
                    'Allocation',
                    '${r.allocationTotal!.toStringAsFixed(0)} days total',
                  ),
                  _detailRow(
                    'Used',
                    '${(r.allocationTaken ?? 0).toStringAsFixed(0)} days',
                  ),
                  _detailRow(
                    'Remaining',
                    '${(r.allocationRemaining ?? 0).toStringAsFixed(0)} days',
                  ),
                  const SizedBox(height: 8),
                  _balanceBar(r),
                ],
                if (!r.requiresAllocation)
                  _detailRow('Allocation', 'No allocation required'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _balanceBar(LeaveRecord r) {
    final total = r.allocationTotal ?? 0;
    final taken = r.allocationTaken ?? 0;
    final fraction = total > 0 ? (taken / total).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 6,
        backgroundColor: AppTheme.surfaceContainer,
        valueColor: AlwaysStoppedAnimation<Color>(
          fraction > 0.8 ? AppTheme.error : AppTheme.primary,
        ),
      ),
    );
  }
}
