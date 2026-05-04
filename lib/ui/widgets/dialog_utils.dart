import 'package:flutter/material.dart';

/// Shows a dialog that requires the user to type a specific word to confirm a dangerous action.
Future<bool> showTextConfirmationDialog({
  required BuildContext context,
  required String title,
  required String content,
  required String confirmationWord,
  String confirmLabel = 'Confirm',
  Color? confirmColor,
}) async {
  String input = '';
  
  return await showDialog<bool>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final bool isValid = input.toUpperCase() == confirmationWord.toUpperCase();
          final colorScheme = Theme.of(context).colorScheme;
          
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(content),
                const SizedBox(height: 20),
                Text(
                  'Type "$confirmationWord" to enable the button:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: confirmationWord,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => input = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isValid ? () => Navigator.pop(context, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: isValid ? (confirmColor ?? colorScheme.error) : null,
                ),
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  ) ?? false;
}
