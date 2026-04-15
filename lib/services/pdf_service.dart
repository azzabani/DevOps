// lib/services/pdf_service.dart
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/reservation_model.dart';
import '../models/resource_model.dart';

class PdfService {
  /// Génère un PDF de confirmation et retourne ses bytes.
  Future<Uint8List> generateConfirmationPdf(
    ReservationModel reservation,
    ResourceModel resource,
  ) async {
    final pdf = pw.Document();
    final dtFmt = DateFormat('dd/MM/yyyy HH:mm');
    final tFmt = DateFormat('HH:mm');

    // Charger une police Google Fonts qui supporte les accents
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    final baseStyle = pw.TextStyle(font: font, fontSize: 11);
    final boldStyle = pw.TextStyle(font: fontBold, fontSize: 11);
    final titleStyle = pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.white);
    final subtitleStyle = pw.TextStyle(font: font, fontSize: 10, color: PdfColors.white);
    final statusStyle = pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.green700);
    final labelStyle = pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey700);
    final footerStyle = pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Booky - Confirmation de reservation',
                            style: titleStyle,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Genere le ${dtFmt.format(DateTime.now())}',
                            style: subtitleStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Statut
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green100,
                  borderRadius: pw.BorderRadius.circular(20),
                  border: pw.Border.all(color: PdfColors.green700),
                ),
                child: pw.Text(
                  'Reservation Confirmee',
                  style: statusStyle,
                ),
              ),

              pw.SizedBox(height: 20),

              // Détails
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _row('Ressource', resource.name, labelStyle, baseStyle),
                    _divider(),
                    _row('Categorie', resource.category, labelStyle, baseStyle),
                    _divider(),
                    _row('Utilisateur', reservation.userName, labelStyle, baseStyle),
                    _divider(),
                    _row('Date de debut', dtFmt.format(reservation.startTime), labelStyle, baseStyle),
                    _divider(),
                    _row('Heure de fin', tFmt.format(reservation.endTime), labelStyle, baseStyle),
                    if (reservation.validatedAt != null) ...[
                      _divider(),
                      _row('Validee le', dtFmt.format(reservation.validatedAt!), labelStyle, baseStyle),
                    ],
                    if (reservation.validatedBy != null) ...[
                      _divider(),
                      _row('Validee par', reservation.validatedBy!, labelStyle, baseStyle),
                    ],
                    if (reservation.notes != null && reservation.notes!.isNotEmpty) ...[
                      _divider(),
                      _row('Notes', reservation.notes!, labelStyle, baseStyle),
                    ],
                  ],
                ),
              ),

              pw.Spacer(),

              // Pied de page
              pw.Divider(color: PdfColors.grey300),
              pw.Text(
                'ID de reservation : ${reservation.id}',
                style: footerStyle,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Partage ou télécharge le PDF selon la plateforme.
  Future<void> sharePdf(Uint8List pdfBytes, String fileName) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }

  pw.Widget _row(String label, String value, pw.TextStyle labelStyle, pw.TextStyle valueStyle) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(label, style: labelStyle),
          ),
          pw.Expanded(
            child: pw.Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }

  pw.Widget _divider() => pw.Divider(color: PdfColors.grey200, height: 1);
}
