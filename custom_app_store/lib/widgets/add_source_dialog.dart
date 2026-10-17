import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/source.dart';
import '../state/store_state.dart';

/// Modal dialog that lets the user add a repository index URL.
/// Returns true when a source was added successfully.
Future<bool> showAddSourceDialog(BuildContext context) async {
  final state = context.read<StoreState>();
  final urlController = TextEditingController();
  final nameController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var busy = false;

  final added = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit() async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            setState(() => busy = true);
            final messenger = ScaffoldMessenger.of(dialogContext);
            try {
              final url = normalizeIndexUrl(urlController.text);
              // Verify the index before committing it.
              final apps = await state.preview(url);
              await state.addSource(url, name: nameController.text);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
              messenger.showSnackBar(
                SnackBar(content: Text('Added $apps app(s) from ${Uri.parse(url).host}')),
              );
            } catch (error) {
              if (dialogContext.mounted) setState(() => busy = false);
              messenger.showSnackBar(
                SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
              );
            }
          }

          return AlertDialog(
            title: const Text('Add repository'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Point at a repository index. You can paste a full URL to a JSON file '
                      'or just a host — /repo.json is added automatically.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: urlController,
                      autofocus: true,
                      enabled: !busy,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Repository URL',
                        hintText: 'https://example.com/repo.json',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a URL';
                        }
                        final normalized = normalizeIndexUrl(value);
                        final uri = Uri.tryParse(normalized);
                        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
                          return 'That does not look like a URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Display name (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );

  urlController.dispose();
  nameController.dispose();
  return added ?? false;
}
