// lib/services/ical_service.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';

import '../models/reservation_model.dart';

class ICalService {
  String _formatDate(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final mo = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final mi = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    return '${y}${mo}${d}T${h}${mi}${s}Z';
  }

  String generateIcs(ReservationModel reservation) {
    final start = _formatDate(reservation.startTime);
    final end = _formatDate(reservation.endTime);
    final description = (reservation.notes ?? '').replaceAll('\n', '\\n');
    final summary = reservation.resourceName.isNotEmpty
        ? reservation.resourceName
        : 'Réservation';

    return 'BEGIN:VCALENDAR\r\n'
        'VERSION:2.0\r\n'
        'PRODID:-//Booky//FlutterBooking//FR\r\n'
        'CALSCALE:GREGORIAN\r\n'
        'METHOD:PUBLISH\r\n'
        'BEGIN:VEVENT\r\n'
        'UID:${reservation.id}@booky.flutterbooking\r\n'
        'DTSTART:$start\r\n'
        'DTEND:$end\r\n'
        'SUMMARY:$summary\r\n'
        'DESCRIPTION:$description\r\n'
        'STATUS:CONFIRMED\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR';
  }

  Map<String, String> parseIcs(String icsContent) {
    final result = <String, String>{};
    const keys = {'UID', 'DTSTART', 'DTEND', 'SUMMARY', 'DESCRIPTION'};
    for (final line in icsContent.split('\n')) {
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) continue;
      final key = line.substring(0, colonIndex).trim();
      final value = line.substring(colonIndex + 1).trim();
      if (keys.contains(key)) result[key] = value;
    }
    return result;
  }

  Future<void> shareIcs(ReservationModel reservation) async {
    final content = generateIcs(reservation);
    final bytes = Uint8List.fromList(content.codeUnits);
    final fileName = 'reservation_${reservation.id}.ics';

    // XFile.fromData fonctionne sur Web ET Mobile sans path_provider
    final xFile = XFile.fromData(
      bytes,
      name: fileName,
      mimeType: 'text/calendar',
    );

    await Share.shareXFiles(
      [xFile],
      subject: 'Réservation ${reservation.resourceName}',
    );
  }
}
