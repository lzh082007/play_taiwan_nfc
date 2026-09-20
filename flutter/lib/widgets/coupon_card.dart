import 'package:flutter/material.dart';

import '../models/coupon.dart';

class CouponCard extends StatelessWidget {
  const CouponCard({super.key, required this.coupon});

  final Coupon coupon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    coupon.couponName,
                    style: textTheme.titleLarge?.copyWith(color: colorScheme.onPrimaryContainer),
                  ),
                ),
                if (!coupon.isActive)
                  Chip(label: const Text('已下架'), backgroundColor: colorScheme.errorContainer),
              ],
            ),
            const SizedBox(height: 4),
            Text(coupon.discountLabel, style: textTheme.headlineSmall?.copyWith(color: colorScheme.onPrimaryContainer)),
            const SizedBox(height: 8),
            Text('適用：${coupon.discountCommodity}', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text('代碼：${coupon.couponCode}', style: textTheme.bodySmall?.copyWith(color: colorScheme.onPrimaryContainer)),
            if (coupon.validTo != null) ...[
              const SizedBox(height: 4),
              Text('有效期限至：${_formatDate(coupon.validTo!)}', style: textTheme.bodySmall?.copyWith(color: colorScheme.onPrimaryContainer)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}';
  }
}
