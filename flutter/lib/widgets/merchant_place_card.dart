import 'package:flutter/material.dart';

import '../models/merchant_place.dart';

class MerchantPlaceCard extends StatelessWidget {
  const MerchantPlaceCard({super.key, required this.place});

  final MerchantPlace place;

  static const _weekdayLabels = {
    'Monday': '週一',
    'Tuesday': '週二',
    'Wednesday': '週三',
    'Thursday': '週四',
    'Friday': '週五',
    'Saturday': '週六',
    'Sunday': '週日',
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final locationLine = [
      place.city,
      place.town,
    ].where((s) => s != null && s.isNotEmpty).join(' ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (place.images.isNotEmpty)
            Image.network(
              place.images.first.url,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 180,
                color: colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, size: 48),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.displayName, style: textTheme.headlineSmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ...place.identityLabels.map(
                      (label) => Chip(label: Text(label), visualDensity: VisualDensity.compact),
                    ),
                    ...place.categories.map(
                      (category) => Chip(
                        label: Text(category),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: colorScheme.secondaryContainer,
                      ),
                    ),
                    ...place.hotelClasses.map(
                      (hotelClass) => Chip(
                        label: Text(hotelClass),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: colorScheme.tertiaryContainer,
                      ),
                    ),
                  ],
                ),
                if (place.govStatus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(place.govStatus),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colorScheme.primaryContainer,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined, size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        locationLine.isEmpty ? place.displayAddress : '${place.displayAddress}（$locationLine）',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(place.displayDescription, style: textTheme.bodyMedium),
                if (place.displayPhone != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 18),
                      const SizedBox(width: 4),
                      Text(place.displayPhone!, style: textTheme.bodyMedium),
                    ],
                  ),
                ],
                if (place.displayWebsite != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.language_outlined, size: 18),
                      const SizedBox(width: 4),
                      Expanded(child: Text(place.displayWebsite!, style: textTheme.bodyMedium)),
                    ],
                  ),
                ],
                if (place.govTicketInfo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.confirmation_number_outlined, size: 18),
                      const SizedBox(width: 4),
                      Expanded(child: Text('票價：${place.govTicketInfo}', style: textTheme.bodyMedium)),
                    ],
                  ),
                ],
                if (place.govTravelInfo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.directions_outlined, size: 18),
                      const SizedBox(width: 4),
                      Expanded(child: Text('交通：${place.govTravelInfo}', style: textTheme.bodyMedium)),
                    ],
                  ),
                ],
                if (place.operatingHours.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined, size: 18),
                      const SizedBox(width: 4),
                      Text('營業時間', style: textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...place.operatingHours.map(
                    (hour) => Padding(
                      padding: const EdgeInsets.only(left: 22, top: 2),
                      child: Text(
                        '${_weekdayLabels[hour.dayOfWeek] ?? hour.dayOfWeek}　${hour.openTime}–${hour.closeTime}',
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
