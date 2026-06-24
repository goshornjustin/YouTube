import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart'; // Bridge to native iOS/Android home screen widgets
import 'package:path_provider/path_provider.dart'; // Locates app's documents directory for file storage
import 'package:qr_flutter/qr_flutter.dart'; // Renders QR codes (preview widget + offscreen painter)

/// Config screen where the user enters QR data, previews it, and pushes it to
/// the native home screen widget. Stateful because it holds the text input and
/// in-progress update flag.
class QRWidgetConfigScreen extends StatefulWidget {
  const QRWidgetConfigScreen({super.key});

  @override
  State<QRWidgetConfigScreen> createState() => _QRWidgetConfigScreenState();
}

class _QRWidgetConfigScreenState extends State<QRWidgetConfigScreen> {
  // Holds the value encoded into the QR code (text, URL, etc.)
  final TextEditingController _qrValueController = TextEditingController();
  // Holds the optional label shown above the QR code on the widget
  final TextEditingController _labelController = TextEditingController();
  // True while QR generation + widget update is running; disables button + shows spinner
  bool _isUpdating = false;

  /// Pre-fills the inputs with whatever was last saved to widget storage so the
  /// screen reflects the widget's current state on open.
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

  /// Fixed on-disk location for the generated QR PNG. Same path is reused each
  /// update (overwritten) and handed to the native widget to display.
  Future<String> _getQRImagePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/qr_code_widget.png';
  }

  /// Renders the QR code to a high-res PNG and writes it to disk so the native
  /// widget can load it as an image.
  Future<void> _generateAndSaveQRCode() async {
    final qrValue = _qrValueController.text.trim();
    if (qrValue.isEmpty) {
      throw Exception('QR code value cannot be empty');
    }

    // Configure how the QR code is drawn (shapes, color, error correction)
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
      errorCorrectionLevel:
          QrErrorCorrectLevel.M, // Medium: ~15% damage tolerance
    );

    // Paint the QR painter onto an offscreen canvas to rasterize it to an image
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size =
        1024.0; // High resolution so the widget stays crisp + scannable
    qrPainter.paint(canvas, const Size(size, size));
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());

    // Encode the rasterized image as PNG bytes
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Failed to encode QR code as PNG');
    }
    final pngBytes = byteData.buffer.asUint8List();

    // Write PNG to the shared path the native widget reads from
    final imagePath = await _getQRImagePath();
    final file = File(imagePath);
    await file.writeAsBytes(pngBytes);
  }

  /// Main action: validate input, generate the QR image, persist all values to
  /// widget storage, and trigger a refresh of the native iOS/Android widgets.
  Future<void> _updateWidget() async {
    final qrValue = _qrValueController.text.trim();
    final label = _labelController.text.trim();

    // Bail early with feedback if no QR value was entered
    if (qrValue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a QR code value'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show spinner / disable button while async work runs
    setState(() {
      _isUpdating = true;
    });

    try {
      // Rasterize the QR code and write the PNG to disk
      await _generateAndSaveQRCode();

      final imagePath = await _getQRImagePath();

      // Persist the values the native widgets read (value, label, image path).
      // On iOS these land in App Group UserDefaults; on Android in SharedPreferences.
      await HomeWidget.saveWidgetData<String>('qr_code_value', qrValue);
      await HomeWidget.saveWidgetData<String>(
        'qr_code_label',
        label.isEmpty ? 'QR Code' : label, // Default label when none provided
      );
      await HomeWidget.saveWidgetData<String>('qr_code_image_path', imagePath);

      // Tell both platforms to redraw their widgets with the new data
      await HomeWidget.updateWidget(
        name: 'HomeWidget', // iOS widget name
        androidName: 'QRWidgetProvider', // Android widget provider class
      );

      // mounted guard: widget may have been disposed during the awaits above
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Widget updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Surface any failure (empty value, encode failure, file write, etc.)
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
      // Always clear the in-progress flag, success or failure
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
    _loadSavedData(); // Restore previously saved inputs on screen open
  }

  @override
  void dispose() {
    // Free controllers to avoid memory leaks
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
        // Scrollable so content fits small screens / keyboard
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instruction card explaining the 4-step flow
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
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

            // Input for the data to encode into the QR code
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

            // Input for the optional label shown above the QR on the widget
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

            // Live preview, only shown once a value has been entered.
            // Note: not wrapped in an onChanged/setState, so it refreshes on
            // rebuild rather than per keystroke.
            if (_qrValueController.text.isNotEmpty) ...[
              Text(
                'Preview',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Show the label above the preview QR when one is set
                      if (_labelController.text.isNotEmpty) ...[
                        Text(
                          _labelController.text,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
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

            // Triggers the save+update flow; disabled and shows a spinner while running
            ElevatedButton.icon(
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
            ),
          ],
        ),
      ),
    );
  }
}
