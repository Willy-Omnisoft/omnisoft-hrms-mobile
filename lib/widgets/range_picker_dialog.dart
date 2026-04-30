import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/theme.dart';

class RangePickerDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? Function(DateTime)? holidayName;

  const RangePickerDialog({
    super.key,
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
    this.holidayName,
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

  Widget _selectedHolidayHint() {
    final names = <String>{};
    final f = widget.holidayName;
    if (f != null && _start != null) {
      final endOrStart = _end ?? _start!;
      var d = _start!;
      while (!d.isAfter(endOrStart)) {
        final n = f(d);
        if (n != null) names.add(n);
        d = d.add(const Duration(days: 1));
      }
    }
    if (names.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy, size: 16, color: AppTheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              names.length == 1
                  ? 'Public holiday: ${names.first}'
                  : 'Public holidays: ${names.join(', ')}',
              style: TextStyle(fontSize: 12, color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
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
              holidayPredicate: (day) =>
                  widget.holidayName?.call(day) != null,
              onDaySelected: _onDayTapped,
              calendarBuilders: CalendarBuilders(
                holidayBuilder: (context, day, focusedDay) {
                  final inRange = _start != null &&
                      _end != null &&
                      !day.isBefore(_start!) &&
                      !day.isAfter(_end!);
                  final isStart =
                      _start != null && isSameDay(day, _start);
                  final isEnd = _end != null && isSameDay(day, _end);
                  final selectedOnly = _start != null &&
                      _end == null &&
                      isSameDay(day, _start);
                  if (isStart || isEnd || selectedOnly) {
                    return null; // let default range start/end render
                  }
                  return Container(
                    margin: const EdgeInsets.all(4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: inRange
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : null,
                      shape: BoxShape.rectangle,
                    ),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
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
            if (widget.holidayName != null) ...[
              const SizedBox(height: 8),
              _selectedHolidayHint(),
            ],
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
