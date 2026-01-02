import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRWidgetConfigScreen extends StatefulWidget {
  const QRWidgetConfigScreen({super.key});

  @override
  State<QRWidgetConfigScreen> createState() => _QRWidgetConfigScreenState();
}

class _QRWidgetConfigScreenState extends State<QRWidgetConfigScreen> {
  final TextEditingController _qrValueController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  bool _isUpdating = false;


  Future<void> _loadSavedData() async {
    final qrValue = await HomeWidget.getWidgetData<String>('qr_code_value');
    final label = await HomeWidget.getWidgetData<String>('qr_code_label');

    if (qrValue != null) {
      _qrValueController.text = qrValue;
    }
    if (label != null) {
      _labelController.text = label;
    }
  }

  Future<String> _getQRImagePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/qr_code_widget.png';
  }

  Future<void> _generateAndSaveQRCode() async {
    final qrValue = _qrValueController.text.trim();
    if (qrValue.isEmpty) {
      throw Exception('QR code value cannot be empty');
    }

    // Create QR painter
    final qrPainter = QrPainter(
      data: qrValue,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );

    // Convert to image
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = 1024.0; // High resolution for better scanning
    qrPainter.paint(canvas, const Size(size, size));
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());

    // Encode as PNG
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode QR code as PNG');
    }
    final pngBytes = byteData.buffer.asUint8List();

    // Save to file
    final imagePath = await _getQRImagePath();
    final file = File(imagePath);
    await file.writeAsBytes(pngBytes);
  }

  Future<void> _updateWidget() async {
    final qrValue = _qrValueController.text.trim();
    final label = _labelController.text.trim();

    // Validate input
    if (qrValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a QR code value'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // Generate and save QR code image
      await _generateAndSaveQRCode();

      // Get image path
      final imagePath = await _getQRImagePath();

      // Save data to widget storage
      await HomeWidget.saveWidgetData<String>('qr_code_value', qrValue);
      await HomeWidget.saveWidgetData<String>(
        'qr_code_label',
        label.isEmpty ? 'QR Code' : label,
      );
      await HomeWidget.saveWidgetData<String>('qr_code_image_path', imagePath);

      // Update widgets on both platforms
      await HomeWidget.updateWidget(
        name: 'HomeWidget', // iOS widget name
        androidName: 'QRWidgetProvider', // Android widget provider class
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Widget updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating widget: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

    @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _qrValueController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Widget'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How to Use',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Enter the text, URL, or data for your QR code\n'
                      '2. Add a custom label (optional)\n'
                      '3. Tap "Update Widget" to save\n'
                      '4. Add the widget to your home screen',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // QR Value Input
            TextField(
              controller: _qrValueController,
              decoration: const InputDecoration(
                labelText: 'QR Code Value',
                hintText: 'Enter text, URL, or data for QR code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              maxLines: 2,
            
            ),
            const SizedBox(height: 16),

            // Label Input
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Widget Label',
                hintText: 'Enter widget label (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            
            ),
            const SizedBox(height: 24),

            // QR Code Preview
            if (_qrValueController.text.isNotEmpty) ...[
              Text(
                'Preview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (_labelController.text.isNotEmpty) ...[
                        Text(
                          _labelController.text,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),

                        const SizedBox(height: 12),
                      ],
                      QrImageView(
                        data: _qrValueController.text,
                        version: QrVersions.auto,
                        size: 225.0,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Update Button
            FilledButton.icon(
              onPressed: _isUpdating ? null : _updateWidget,
              icon: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.update),
              label: Text(_isUpdating ? 'Updating...' : 'Update Widget'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
