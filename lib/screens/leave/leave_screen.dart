import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/leave_type.dart';
import '../../services/omni_mobile_api.dart';
import '../../services/session_service.dart';
import '../../widgets/range_picker_dialog.dart';

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
  String _fromPeriod = 'am';
  String _toPeriod = 'pm';
  TimeOfDay _hourFrom = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _hourTo = const TimeOfDay(hour: 17, minute: 0);
  final _reasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  bool get _isHalfDay => widget.leaveType.requestUnit == 'half_day';
  bool get _isHourly => widget.leaveType.requestUnit == 'hour';

  double _todToFloat(TimeOfDay t) => t.hour + t.minute / 60.0;
  double get _hourCount => _todToFloat(_hourTo) - _todToFloat(_hourFrom);

  String get _hourLabel {
    final h = _hourCount;
    return h == h.roundToDouble()
        ? '${h.toInt()}h'
        : '${h.toStringAsFixed(1)}h';
  }

  bool get _isSameDate =>
      _dateFrom.year == _dateTo.year &&
      _dateFrom.month == _dateTo.month &&
      _dateFrom.day == _dateTo.day;

  /// Days computed to match Odoo's hr.leave half-day arithmetic.
  double get _dayCount {
    final base = _dateTo.difference(_dateFrom).inDays + 1;
    if (!_isHalfDay) return base.toDouble();
    if (_isSameDate) {
      return _fromPeriod == _toPeriod ? 0.5 : 1.0;
    }
    var d = base.toDouble();
    if (_fromPeriod == 'pm') d -= 0.5;
    if (_toPeriod == 'am') d -= 0.5;
    return d;
  }

  String get _dayCountLabel {
    final n = _dayCount;
    return n == n.roundToDouble()
        ? '${n.toInt()}d'
        : '${n.toStringAsFixed(1)}d';
  }

  /// Half-day mode rejects pm→am on the same date (would be 0 days).
  bool get _periodValid {
    if (_isHourly) return _hourCount > 0;
    if (!_isHalfDay) return true;
    if (_isSameDate && _fromPeriod == 'pm' && _toPeriod == 'am') return false;
    return _dayCount > 0;
  }

  Future<void> _pickRange() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    if (_isHourly) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _dateFrom,
        firstDate: firstDate,
        lastDate: firstDate.add(const Duration(days: 365)),
      );
      if (picked != null) {
        setState(() {
          _dateFrom = picked;
          _dateTo = picked;
          _error = null;
        });
      }
      return;
    }
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => RangePickerDialog(
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
        _error = null;
      });
    }
  }

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _hourFrom : _hourTo,
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _hourFrom = picked;
        } else {
          _hourTo = picked;
        }
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_periodValid) {
      setState(() => _error = _isHourly
          ? 'End time must be after start time.'
          : 'Afternoon → Morning on the same date is not a valid range.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
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
        dateTo: DateFormat('yyyy-MM-dd').format(
            _isHourly ? _dateFrom : _dateTo),
        reason: _reasonController.text.trim(),
        dateFromPeriod: _isHalfDay ? _fromPeriod : null,
        dateToPeriod: _isHalfDay ? _toPeriod : null,
        hourFrom: _isHourly ? _todToFloat(_hourFrom) : null,
        hourTo: _isHourly ? _todToFloat(_hourTo) : null,
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
      if (mounted) setState(() => _error = _humanizeError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _humanizeError(Object e) {
    final raw = e.toString();
    if (raw.contains('overlap') || raw.contains('already')) {
      return 'You already have a leave request on these dates.';
    }
    if (raw.contains('allocation') || raw.contains('No more')) {
      return 'Not enough allocation balance for this request.';
    }
    return raw.replaceFirst(RegExp(r'^Exception: '), '');
  }

  Widget _timeBox({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 18, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    time.format(context),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodRow({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'am',
                label: Text('Morning'),
                icon: Icon(Icons.wb_sunny_outlined, size: 16),
              ),
              ButtonSegment(
                value: 'pm',
                label: Text('Afternoon'),
                icon: Icon(Icons.wb_twilight, size: 16),
              ),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 12)),
            ),
          ),
        ),
      ],
    );
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
                        Text(_isHourly ? 'Leave date' : 'Leave dates',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          _isHourly
                              ? '${fmt.format(_dateFrom)}  ·  $_hourLabel'
                              : '${fmt.format(_dateFrom)} → ${fmt.format(_dateTo)}  ·  $_dayCountLabel',
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
          if (_isHourly) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _timeBox(
                      label: 'From', time: _hourFrom,
                      onTap: () => _pickTime(true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _timeBox(
                      label: 'To', time: _hourTo,
                      onTap: () => _pickTime(false)),
                ),
              ],
            ),
          ],
          if (_isHalfDay) ...[
            const SizedBox(height: 16),
            _periodRow(
              label: 'Start period',
              value: _fromPeriod,
              onChanged: (v) => setState(() {
                _fromPeriod = v;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            _periodRow(
              label: 'End period',
              value: _toPeriod,
              onChanged: (v) => setState(() {
                _toPeriod = v;
                _error = null;
              }),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 2,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppTheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
