import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:home_widget_flutter/qr_widget.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure iOS App Group
  await HomeWidget.setAppGroupId('group.com.example.homeWidgetFlutter');

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Code Widget',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SafeArea(
        child: QRWidgetConfigScreen(),
      ),
    );
  }
}

