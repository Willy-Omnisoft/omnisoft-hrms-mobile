import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/theme.dart';
import '../../models/leave_type.dart';
import '../../services/omni_mobile_api.dart';
import '../../services/session_service.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  List<LeaveType> _types = [];
  bool _loading = true;
  String? _error;

  OmniMobileApi _api(SessionService s) => OmniMobileApi(
        baseUrl: s.clientUrl,
        db: s.clientDb,
        token: s.token,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTypes());
  }

  Future<void> _loadTypes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = context.read<SessionService>();
      _types = await _api(session).getLeaveTypes();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openApplyForm(LeaveType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ApplyLeaveSheet(leaveType: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _loadTypes,
                  child: _buildList(),
                ),
    );
  }

  Widget _buildList() {
    // Group by category
    final groups = <String, List<LeaveType>>{};
    for (final t in _types) {
      groups.putIfAbsent(t.mobileCategory, () => []).add(t);
    }
    final categoryOrder = [
      'annual',
      'medical',
      'family',
      'unpaid',
      'compassionate',
      'other'
    ];
    final sorted = categoryOrder.where((c) => groups.containsKey(c)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final cat in sorted) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
            child: Text(
              _categoryLabel(cat),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          for (final type in groups[cat]!)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Icon(_categoryIcon(cat), color: AppTheme.primary),
                ),
                title: Text(type.name),
                subtitle: type.mobileRequiresDocument
                    ? const Text('Document required',
                        style: TextStyle(fontSize: 12, color: AppTheme.error))
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openApplyForm(type),
              ),
            ),
        ],
      ],
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'annual':
        return 'Annual';
      case 'medical':
        return 'Medical';
      case 'family':
        return 'Family';
      case 'unpaid':
        return 'Unpaid';
      case 'compassionate':
        return 'Compassionate';
      default:
        return 'Other';
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'annual':
        return Icons.beach_access;
      case 'medical':
        return Icons.local_hospital;
      case 'family':
        return Icons.family_restroom;
      case 'unpaid':
        return Icons.money_off;
      case 'compassionate':
        return Icons.volunteer_activism;
      default:
        return Icons.event;
    }
  }
}

class _ApplyLeaveSheet extends StatefulWidget {
  final LeaveType leaveType;
  const _ApplyLeaveSheet({required this.leaveType});

  @override
  State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
  DateTime _dateFrom = DateTime.now().add(const Duration(days: 1));
  DateTime _dateTo = DateTime.now().add(const Duration(days: 1));
  final _reasonController = TextEditingController();
  bool _submitting = false;

  int get _dayCount => _dateTo.difference(_dateFrom).inDays + 1;

  Future<void> _pickRange() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => _RangePickerDialog(
        initialStart: _dateFrom,
        initialEnd: _dateTo,
        firstDate: firstDate,
        lastDate: firstDate.add(const Duration(days: 365)),
      ),
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final session = context.read<SessionService>();
      final api = OmniMobileApi(
        baseUrl: session.clientUrl,
        db: session.clientDb,
        token: session.token,
      );
      final result = await api.applyLeave(
        holidayStatusId: widget.leaveType.id,
        dateFrom: DateFormat('yyyy-MM-dd').format(_dateFrom),
        dateTo: DateFormat('yyyy-MM-dd').format(_dateTo),
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();

      var msg = 'Leave submitted successfully';
      if (result['document_required'] == true) {
        msg +=
            '\n\nSupporting document required. Upload will be available in next version.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.primary),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.leaveType.name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (widget.leaveType.mobileRequiresDocument)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Supporting document required. Upload will be available in next version.',
                style: TextStyle(fontSize: 12, color: AppTheme.error),
              ),
            ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickRange,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Leave dates',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          '${fmt.format(_dateFrom)} → ${fmt.format(_dateTo)}  ·  ${_dayCount}d',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppTheme.outline),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Leave'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangePickerDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;

  const _RangePickerDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_RangePickerDialog> createState() => _RangePickerDialogState();
}

class _RangePickerDialogState extends State<_RangePickerDialog> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _focused;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    _focused = widget.initialStart;
  }

  void _onDayTapped(DateTime selected, DateTime focused) {
    final tapped = DateTime(selected.year, selected.month, selected.day);
    setState(() {
      _focused = focused;
      if (_start == null || _end != null) {
        _start = tapped;
        _end = null;
      } else if (tapped.isBefore(_start!)) {
        _start = tapped;
        _end = null;
      } else {
        _end = tapped;
      }
    });
    if (_start != null && _end != null) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          Navigator.of(context).pop(
              DateTimeRange(start: _start!, end: _end!));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM');
    final headerText = _start == null
        ? 'Select start date'
        : _end == null
            ? '${fmt.format(_start!)} → ?'
            : '${fmt.format(_start!)} → ${fmt.format(_end!)}  ·  ${_end!.difference(_start!).inDays + 1}d';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(headerText,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            TableCalendar(
              firstDay: widget.firstDate,
              lastDay: widget.lastDate,
              focusedDay: _focused,
              rangeStartDay: _start,
              rangeEndDay: _end,
              rangeSelectionMode: RangeSelectionMode.toggledOff,
              selectedDayPredicate: (day) =>
                  _start != null && _end == null && isSameDay(day, _start),
              onDaySelected: _onDayTapped,
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
                rangeStartDecoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                rangeEndDecoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                withinRangeDecoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.rectangle,
                ),
                rangeStartTextStyle:
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                rangeEndTextStyle:
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                todayDecoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(color: AppTheme.primary),
                outsideDaysVisible: false,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              availableGestures: AvailableGestures.horizontalSwipe,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
