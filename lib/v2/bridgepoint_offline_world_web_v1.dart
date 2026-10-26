// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Uses the same-origin offline route so the browser's service worker,
/// IndexedDB and Cache Storage persist the downloaded packs on the device.
class BridgePointOfflineWorldEmbedV1 extends StatefulWidget {
  const BridgePointOfflineWorldEmbedV1({super.key});

  @override
  State<BridgePointOfflineWorldEmbedV1> createState() =>
      _BridgePointOfflineWorldEmbedV1State();
}

class _BridgePointOfflineWorldEmbedV1State
    extends State<BridgePointOfflineWorldEmbedV1> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'bridgepoint-offline-world-v1-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final frame = html.IFrameElement()
        ..src = '/offline/'
        ..title = 'BridgePoint Offline World and Download Packages'
        ..allow = 'fullscreen'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block';
      frame.setAttribute('allowfullscreen', 'true');
      frame.setAttribute('data-bridgepoint-offline-version', 'v1');
      return frame;
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF040A10),
        child: SizedBox.expand(
          child: HtmlElementView(viewType: _viewType),
        ),
      );
}
