import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart' show rootBundle;

class AarcModal {
  static Future<void> show(BuildContext ctx) async {
    // Load your HTML as a string
    final html = await rootBundle.loadString('assets/aarc_iframe.html');

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).canvasColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: InAppWebView(
            initialData: InAppWebViewInitialData(data: html),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                javaScriptEnabled: true,
                transparentBackground: true,
              ),
            ),
            onWebViewCreated: (controller) {
              // Register callback handlers
              controller.addJavaScriptHandler(
                handlerName: 'onAarcSuccess',
                callback: (args) {
                  Navigator.of(ctx).pop();            // close the sheet
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Payment successful!'))
                  );
                },
              );
              controller.addJavaScriptHandler(
                handlerName: 'onAarcError',
                callback: (args) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Payment failed. Try again.'))
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
