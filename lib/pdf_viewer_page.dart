import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

import 'api_service.dart';
import 'app_shell.dart';
import 'pdf_actions.dart';
import 'theme.dart';
import 'ui_kit.dart';

/// Prototype: shows one stored PDF inside the app (route /pdf/:fileId).
class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({super.key, required this.fileId});

  final String fileId;

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  void _retry() {
    setState(() {
      _future = _fetch();
    });
  }

  /// Asks the server for a short-lived link, then downloads the PDF bytes.
  Future<Uint8List> _fetch() async {
    final url = await FileApi.link(widget.fileId);
    http.Response res;
    try {
      res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiException(
          'Could not download the PDF. If the server was idle, wait a minute and try again.');
    }
    if (res.statusCode != 200) {
      throw ApiException('Could not download the PDF (${res.statusCode}).');
    }
    return res.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selected: 'courses',
      body: ColoredBox(
        color: AppColors.cardCream,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.label),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Text('PDF',
                        style: AppText.sans(size: 12, color: AppColors.title)),
                  ),
                  TextButton.icon(
                    onPressed: () => openPdf(context, widget.fileId),
                    icon: const Icon(Icons.open_in_new_rounded,
                        size: 16, color: AppColors.label),
                    label: Text('Open in new tab',
                        style: AppText.sans(size: 11, color: AppColors.label)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingBox();
                  }
                  if (snapshot.hasError) {
                    return CenteredMessage(errorText(snapshot.error!), onRetry: _retry);
                  }
                  return PdfViewer.data(
                    snapshot.data!,
                    sourceName: widget.fileId,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}