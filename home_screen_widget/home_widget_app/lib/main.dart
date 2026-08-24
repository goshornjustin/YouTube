import 'package:flutter/material.dart';
import 'package:home_widget_app/save_qr_widget.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(appBar: AppBar(), body: SaveQrWidget()),
    );
  }
}
