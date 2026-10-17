import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Open an external link, showing a snackbar if nothing can handle it.
Future<void> openExternal(BuildContext context, String url) async {
  if (url.trim().isEmpty) return;
  final uri = Uri.tryParse(url.trim());
  final messenger = ScaffoldMessenger.of(context);
  if (uri == null) {
    messenger.showSnackBar(const SnackBar(content: Text('That link is not valid.')));
    return;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}
