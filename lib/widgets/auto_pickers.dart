import 'package:flutter/material.dart';

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
