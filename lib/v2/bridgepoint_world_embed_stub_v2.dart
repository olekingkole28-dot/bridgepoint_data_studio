import 'package:flutter/material.dart';

class BridgePointWorldEmbedV2 extends StatelessWidget {
  const BridgePointWorldEmbedV2({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF020711),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'BridgePoint World V2500 uses the web 3D renderer in this build. The native app can open the same authenticated world through its web surface.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB5C6D9), height: 1.45),
            ),
          ),
        ),
      );
}
