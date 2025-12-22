import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Conditional imports - these will be replaced at compile time
import 'dart:io' if (dart.library.html) 'dart:html' as platform;
import 'package:path_provider/path_provider.dart' if (dart.library.html) '../services/path_provider_stub.dart' show getTemporaryDirectory;
import 'package:open_file/open_file.dart' if (dart.library.html) '../services/open_file_stub.dart' show OpenFile;
import 'receipt_service_web.dart' if (dart.library.io) 'receipt_service_web_stub.dart' as web_helper;

class ReceiptService {
  static Future<String> generateAndSaveReceipt({
    required String busName,
    required String busCode,
    required String source,
    required String destination,
    required double distance,
    required double fare,
    required String date,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              pw.SizedBox(height: 20),
              _buildReceiptTitle(),
              pw.SizedBox(height: 30),
              _buildTransactionDetails(
                busName: busName,
                busCode: busCode,
                source: source,
                destination: destination,
                distance: distance,
                fare: fare,
                date: date,
              ),
              pw.SizedBox(height: 40),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'bus_receipt_${busCode}_$timestamp.pdf';

    if (kIsWeb) {
      // Web: Download directly to browser using dart:html
      _downloadPdfWeb(pdfBytes, fileName);
      return fileName; // Return filename for web
    } else {
      // Mobile/Desktop: Save to file system using dart:io
      final output = await getTemporaryDirectory();
      final file = platform.File('${output.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      return file.path;
    }
  }

  static void _downloadPdfWeb(List<int> bytes, String fileName) {
    if (kIsWeb) {
      // Use web helper for download
      web_helper.downloadPdfWeb(bytes, fileName);
    }
  }

  static Future<String> getReceiptFileName({
    required String busCode,
    required String date,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'bus_receipt_${busCode}_$timestamp.pdf';
  }

  static pw.Widget _buildHeader() {
    return pw.Container(
      padding: pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        children: [
          pw.Icon(
            pw.IconData(0xe530), // Bus icon
            color: PdfColors.white,
            size: 30,
          ),
          pw.SizedBox(width: 15),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SmartCommute Dhaka',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Official Receipt',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReceiptTitle() {
    return pw.Center(
      child: pw.Text(
        'PAYMENT RECEIPT',
        style: pw.TextStyle(
          fontSize: 28,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _buildTransactionDetails({
    required String busName,
    required String busCode,
    required String source,
    required String destination,
    required double distance,
    required double fare,
    required String date,
  }) {
    return pw.Container(
      padding: pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Receipt Date:', date, PdfColors.grey700),
          pw.SizedBox(height: 15),
          _buildDetailRow('Transaction ID:',
              'TXN${DateTime.now().millisecondsSinceEpoch}', PdfColors.grey700),
          pw.SizedBox(height: 15),
          _buildDetailRow('Bus Name:', busName, PdfColors.blue),
          pw.SizedBox(height: 15),
          _buildDetailRow('Bus Code:', busCode, PdfColors.blue),
          pw.SizedBox(height: 15),
          _buildDetailRow('Source:', source, PdfColors.green),
          pw.SizedBox(height: 15),
          _buildDetailRow('Destination:', destination, PdfColors.red),
          pw.SizedBox(height: 15),
          _buildDetailRow('Distance:', '${distance.toStringAsFixed(1)} km',
              PdfColors.orange),
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey400, thickness: 2),
          pw.SizedBox(height: 20),
          _buildDetailRow(
              'Total Fare:', '৳${fare.toStringAsFixed(0)}', PdfColors.green,
              isTotal: true),
          pw.SizedBox(height: 10),
          _buildDetailRow(
              'Payment Method:', 'Wallet Balance', PdfColors.grey700),
          pw.SizedBox(height: 10),
          _buildDetailRow('Status:', 'PAID', PdfColors.green),
        ],
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value, PdfColor color,
      {bool isTotal = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: pw.EdgeInsets.all(20),
      child: pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 20),
          pw.Text(
            'Thank you for using our service!',
            style: pw.TextStyle(
              fontSize: 16,
              color: PdfColors.grey600,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'This is an official receipt for your bus journey.',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey500,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static Future<void> openReceipt(String filePath) async {
    try {
      if (kIsWeb) {
        // On web, the file is already downloaded, so we don't need to open it
        // The download happens automatically in generateAndSaveReceipt
        return;
      } else {
        // On mobile/desktop, open the file
        await OpenFile.open(filePath);
      }
    } catch (e) {
      print('Error opening file: $e');
    }
  }
}
