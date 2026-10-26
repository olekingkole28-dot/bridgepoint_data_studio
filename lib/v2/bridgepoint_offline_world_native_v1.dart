import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts the same-origin BridgePoint Offline World page inside the installed
/// app. Cache Storage + IndexedDB remain scoped to this WebView origin.
class BridgePointOfflineWorldEmbedV1 extends StatefulWidget {
  const BridgePointOfflineWorldEmbedV1({super.key});

  @override
  State<BridgePointOfflineWorldEmbedV1> createState() =>
      _BridgePointOfflineWorldEmbedV1State();
}

class _BridgePointOfflineWorldEmbedV1State
    extends State<BridgePointOfflineWorldEmbedV1> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _mainFrameError;

  static final Uri _offlineUri =
      Uri.parse('https://bridgepointintelligence.online/offline/');
  static const Set<String> _trustedNavigationHosts = {
    'bridgepointintelligence.online',
    'www.bridgepointintelligence.online',
  };

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF040A10))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _mainFrameError = null);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _mainFrameError = error.description);
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'https' &&
                _trustedNavigationHosts.contains(uri.host)) {
              return NavigationDecision.navigate;
            }
            unawaited(launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            ).catchError((_) => false));
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(_offlineUri);
  }

  @override
  Widget build(BuildContext context) {
    final error = _mainFrameError;
    if (error != null) {
      return ColoredBox(
        color: const Color(0xFF040A10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      color: Color(0xFF62E6FF), size: 38),
                  const SizedBox(height: 12),
                  const Text(
                    'Offline World could not open',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF91A7B5),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _mainFrameError = null);
                      _controller.loadRequest(_offlineUri);
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('RETRY OFFLINE WORLD'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
        if (_progress < 100)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Color(0xFF10212C),
              color: Color(0xFF62E6FF),
            ),
          ),
      ],
    );
  }
}
