import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Calendar date picker that auto-pops on selection (no OK button).
Future<DateTime?> showAutoDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (helpText != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(helpText,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            CalendarDatePicker(
              initialDate: initialDate,
              firstDate: firstDate,
              lastDate: lastDate,
              onDateChanged: (d) => Navigator.of(context).pop(d),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Two-step time picker:
/// 1) tap an hour → switches to minute grid
/// 2) tap a minute → auto-pops with the chosen TimeOfDay
Future<TimeOfDay?> showAutoTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (_) => _AutoTimePickerDialog(initialTime: initialTime),
  );
}

class _AutoTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  const _AutoTimePickerDialog({required this.initialTime});

  @override
  State<_AutoTimePickerDialog> createState() => _AutoTimePickerDialogState();
}

class _AutoTimePickerDialogState extends State<_AutoTimePickerDialog> {
  int? _hour;
  bool _showMinutes = false;

  static const _minuteSteps = [0, 15, 30, 45];

  void _onHourTap(int h) {
    setState(() {
      _hour = h;
      _showMinutes = true;
    });
  }

  void _onMinuteTap(int m) {
    Navigator.of(context).pop(TimeOfDay(hour: _hour!, minute: m));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _showMinutes
                  ? 'Select minute · ${_hour!.toString().padLeft(2, '0')}:--'
                  : 'Select hour',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (!_showMinutes)
              _hourGrid()
            else
              _minuteGrid(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  if (_showMinutes) {
                    setState(() => _showMinutes = false);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(_showMinutes ? 'Back' : 'Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hourGrid() {
    final initialHour = widget.initialTime.hour;
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.1,
      children: [
        for (var h = 0; h < 24; h++)
          _gridCell(
            label: h.toString().padLeft(2, '0'),
            selected: h == initialHour,
            onTap: () => _onHourTap(h),
          ),
      ],
    );
  }

  Widget _minuteGrid() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        for (final m in _minuteSteps)
          _gridCell(
            label: m.toString().padLeft(2, '0'),
            selected: m == widget.initialTime.minute,
            onTap: () => _onMinuteTap(m),
          ),
      ],
    );
  }

  Widget _gridCell({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.outline,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
