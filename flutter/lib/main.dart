import 'package:flutter/material.dart';

import 'pages/home_page.dart';

void main() {
  runApp(const NfcDemoApp());
}

class NfcDemoApp extends StatelessWidget {
  const NfcDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC 商家優惠券示意',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomePage(),
    );
  }
}
