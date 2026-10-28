import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import 'ui_kit.dart';

const int maxPdfBytes = 10 * 1024 * 1024; // the server refuses anything bigger

/// Gets a short-lived link from the server and opens the PDF in a new tab (or the phone's viewer).
Future<void> openPdf(BuildContext context, String fileId) async {
  try {
    final url = await FileApi.link(fileId);
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && context.mounted) {
      showSnack(context,
          'Could not open the PDF. If your browser blocked a pop-up, allow pop-ups for this site and try again.');
    }
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(e));
  }
}

/// Lets the person choose a PDF and uploads it to a module or a quiz (kind: 'module' or 'quiz').
/// Returns true when the upload worked.
Future<bool> pickAndUploadPdf(
  BuildContext context, {
  required String kind,
  required String ownerId,
}) async {
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isEmpty) return false; // the person cancelled

    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxPdfBytes) {
      if (context.mounted) showSnack(context, 'That PDF is larger than 10 MB.');
      return false;
    }

    await FileApi.upload(kind, ownerId, file.name, bytes);
    if (context.mounted) showSnack(context, 'PDF uploaded.');
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(e));
    return false;
  }
}

/// A PDF the person chose but that is not uploaded yet.
class PickedPdf {
  PickedPdf(this.name, this.bytes);
  final String name;
  final List<int> bytes;
}

/// Lets the person choose a PDF. Returns null if they cancel or the file is over 10 MB.
Future<PickedPdf?> pickPdf(BuildContext context) async {
  try {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isEmpty) return null;

    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxPdfBytes) {
      if (context.mounted) showSnack(context, 'That PDF is larger than 10 MB.');
      return null;
    }
    return PickedPdf(file.name, bytes);
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(e));
    return null;
  }
}