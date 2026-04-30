import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/theme.dart';

class RangePickerDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;

  const RangePickerDialog({
    super.key,
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<RangePickerDialog> createState() => _RangePickerDialogState();
}

class _RangePickerDialogState extends State<RangePickerDialog> {
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
                rangeStartTextStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
                rangeEndTextStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
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
