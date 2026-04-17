import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class StatusBadge extends StatelessWidget {
  final bool isOnline;
  final bool isDanger;

  const StatusBadge({
    required this.isOnline,
    required this.isDanger,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDanger
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDanger ? Colors.red : Colors.green,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isDanger ? Colors.red : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isDanger ? 'danger_mode'.tr() : 'normal_mode'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDanger ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isOnline ? 'server_online'.tr() : 'server_offline'.tr(),
            style: TextStyle(
              fontSize: 11,
              color: isOnline ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
