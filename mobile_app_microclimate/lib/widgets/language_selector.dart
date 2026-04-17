import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'change_language'.tr(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _langButton(
              context,
              const Locale('en'),
              'lang_en'.tr(),
              'EN',
              'US',
            ),
            _langButton(
              context,
              const Locale('ru'),
              'lang_ru'.tr(),
              'RU',
              'RU',
            ),
            _langButton(
              context,
              const Locale('kk'),
              'lang_kk'.tr(),
              'KZ',
              'KZ',
            ),
          ],
        ),
      ],
    );
  }

  Widget _langButton(
    BuildContext context,
    Locale locale,
    String label,
    String shortCode,
    String countryCode,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentLocale = context.locale;
    final isSelected = currentLocale == locale;

    return SizedBox(
      width: 108,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async => context.setLocale(locale),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : colorScheme.outlineVariant.withValues(alpha: 0.75),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: Colors.white,
                child: Text(
                  _flagEmoji(countryCode),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                shortCode,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: isSelected ? const Color(0xFF4F46E5) : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _flagEmoji(String countryCode) {
    if (countryCode.length != 2) return '';
    final upper = countryCode.toUpperCase();
    final first = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCodes([first, second]);
  }
}
