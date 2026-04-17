import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

String localizedProfileName(BuildContext context, String rawName) {
  switch (rawName) {
    case '💊 Аптека':
    case 'pharmacy':
      return 'preset_pharmacy'.tr();
    case '🏢 Офис':
    case 'office':
      return 'preset_office'.tr();
    case '🏠 Дом':
    case 'home':
      return 'preset_home'.tr();
    case '🌱 Теплица':
    case 'greenhouse':
      return 'preset_greenhouse'.tr();
    default:
      return rawName;
  }
}
