import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

class HomeWidgetConfig {
  static const String _appGroudId = 'group.com.example.homeWidgetApp.QrWidget';
  static const String _androidWidgetName = 'QrWidgetReceiver';
  static const String _iosWidgetName = 'QrWidget';

  static const String _keyImagePathBase = 'qr_widget_image_path';
  static const String _keyBgColorBase = 'qr_widget_bg_color';
  static const String _keyCardLabelBase = 'qr_widget_card_label';

  static const String _keyCardIdBase = 'qr_widget_card_id';
  static const String _keyActiveWidgetCards = 'qr_widget_active_cards';

  Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroudId);
  }

  Future<List<String>> activeWidgetCardIds() async {
    final data = await HomeWidget.getWidgetData<String>(_keyActiveWidgetCards);

    if (data == null || data.isEmpty) {
      return [];
    }

    return data.split(',').where((id) => id.isNotEmpty).toList();
  }

  Future<Map<String, String>> activeWidgetCards() async {
    final cardIds = await activeWidgetCardIds();
    final cards = <String, String>{};

    for (var id in cardIds) {
      final label = await HomeWidget.getWidgetData<String>(
        '${_keyCardLabelBase}_$id',
      );

      cards[id] = label ?? id;
    }

    return cards;
  }

  Future<String?> widgetCardLabel(String cardId) {
    return HomeWidget.getWidgetData<String>('${_keyCardLabelBase}_$cardId');
  }

  Future<void> _addToActiveList(String cardId) async {
    final activeCards = await activeWidgetCardIds();

    if (!activeCards.contains(cardId)) {
      activeCards.add(cardId);
    }

    await HomeWidget.saveWidgetData(
      _keyActiveWidgetCards,
      activeCards.join(','),
    );
  }

  Future<void> removeWidget(String cardId) async {
    final activeCards = await activeWidgetCardIds();

    activeCards.remove(cardId);

    await HomeWidget.saveWidgetData(
      _keyActiveWidgetCards,
      activeCards.join(','),
    );

    await HomeWidget.saveWidgetData('${_keyCardLabelBase}_$cardId', null);
    await HomeWidget.saveWidgetData('${_keyBgColorBase}_$cardId', null);
    await HomeWidget.saveWidgetData('${_keyCardLabelBase}_$cardId', null);
    await HomeWidget.saveWidgetData('${_keyCardIdBase}_$cardId', null);
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iosWidgetName,
    );
  }

  Future<void> updateWidgetForCard({
    required String cardId,
    required String qrData,
    required Color backgroundColor,
    required Color eyeColor,
    required Color dmColor,
    required String eyeShape,
    required String dataModuleShape,
    required Color widgetBgColor,
    required String cardLabel,
  }) async {
    final qrWidget = MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          color: backgroundColor,
          child: QrImageView(
            data: qrData,
            backgroundColor: backgroundColor,
            eyeStyle: QrEyeStyle(
              eyeShape: eyeShape == 'circle'
                  ? QrEyeShape.circle
                  : QrEyeShape.square,
              color: eyeColor,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: dataModuleShape == 'circle'
                  ? QrDataModuleShape.circle
                  : QrDataModuleShape.square,
              color: dmColor,
            ),
            size: 155,
            version: QrVersions.auto,
          ),
        ),
      ),
    );

    await HomeWidget.renderFlutterWidget(
      qrWidget,
      key: '${_keyImagePathBase}_$cardId',
      logicalSize: const Size(155, 155),
    );

    await HomeWidget.saveWidgetData(
      '${_keyBgColorBase}_$cardId',
      widgetBgColor.toARGB32(),
    );

    await HomeWidget.saveWidgetData('${_keyCardLabelBase}_$cardId', cardLabel);

    await _addToActiveList(cardId);

    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iosWidgetName,
    );
  }
}
