import 'package:flutter/material.dart';
import 'package:home_widget_app/home_widget_config.dart';

class SaveQrWidget extends StatefulWidget {
  const SaveQrWidget({super.key});

  @override
  State<SaveQrWidget> createState() => _SaveQrWidgetState();
}

class _SaveQrWidgetState extends State<SaveQrWidget> {
  final controller = TextEditingController();
  final homeWidgetConfig = HomeWidgetConfig();

  Future<void> saveWidget(String qrData) async {
    await homeWidgetConfig.updateWidgetForCard(
      cardId: '2',
      qrData: qrData,
      backgroundColor: Colors.white,
      eyeColor: Colors.blue,
      dmColor: Colors.black,
      eyeShape: 'circle',
      dataModuleShape: 'square',
      widgetBgColor: Colors.white,
      cardLabel: 'Qr Card',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(controller: controller),
        ElevatedButton(
          onPressed: () {
            saveWidget(controller.text);
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}
