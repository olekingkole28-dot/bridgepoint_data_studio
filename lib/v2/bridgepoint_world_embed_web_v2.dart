// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class BridgePointWorldEmbedV2 extends StatefulWidget {
  const BridgePointWorldEmbedV2({super.key});

  @override
  State<BridgePointWorldEmbedV2> createState() => _BridgePointWorldEmbedV2State();
}

class _BridgePointWorldEmbedV2State extends State<BridgePointWorldEmbedV2> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'bridgepoint-world-v2652-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final frame = html.IFrameElement()
        ..src = '/app/bridgepoint-3d-world/'
        ..title = 'BridgePoint World V2652'
        ..allow = 'geolocation; fullscreen'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block';
      frame.setAttribute('allowfullscreen', 'true');
      frame.setAttribute('data-bridgepoint-world-version', '2652');
      return frame;
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF020711),
        child: SizedBox.expand(
          child: HtmlElementView(viewType: _viewType),
        ),
      );
}
