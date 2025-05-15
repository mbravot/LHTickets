import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:universal_html/html.dart' as html;
import 'package:universal_html/parsing.dart' as html_parser;
import 'package:universal_html/rendering.dart' as html_rendering;

class TicketDetalle extends StatefulWidget {
  // ... (existing code)
}

class _TicketDetalleState extends State<TicketDetalle> {
  // ... (existing code)

  Future<void> _descargarTicketPDF(Map<String, dynamic> ticket) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Detalle del Ticket', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('ID: #${ticket['id']}'),
            pw.Text('Título: ${ticket['titulo']}'),
            pw.Text('Descripción: ${ticket['descripcion']}'),
            pw.Text('Estado: ${ticket['estado']}'),
            pw.Text('Prioridad: ${ticket['prioridad']}'),
            pw.Text('Departamento: ${ticket['departamento']}'),
            pw.Text('Agente: ${ticket['agente']}'),
            pw.Text('Usuario: ${ticket['usuario']}'),
            pw.Text('Fecha de creación: ${ticket['creado']}'),
          ],
        ),
      ),
    );

    // Genera el PDF como bytes
    final pdfBytes = await pdf.save();

    // Crea un Blob y descarga el archivo
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'ticket${ticket['id']}.pdf')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    // ... (existing code)

    return Scaffold(
      appBar: AppBar(
        title: Text(ticket['titulo'] ?? 'Detalle del Ticket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _descargarTicketPDF(ticket),
            tooltip: 'Descargar PDF',
          ),
          // ... existing code ...
        ],
      ),
      // ... (rest of the existing code)
    );
  }
} 