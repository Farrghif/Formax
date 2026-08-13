import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import 'fillformpage.dart';

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({super.key});

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> {
  bool _isProcessing = false;
  String? _errorText;
  
  // Kontroler untuk MobileScanner
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB4C5D4),
        title: const Text('Scan QR', style: TextStyle(color: Colors.white)),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (capture) async {
                if (_isProcessing) return;
                
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;

                final link = barcodes.first.rawValue ?? '';
                if (link.isEmpty) return;

                setState(() => _isProcessing = true);
                
                final result = await ApiService.validateFormLink(link);
                if (result['success'] == true) {
                  final slug = result['data']['slug'] ?? '';
                  if (mounted && slug.isNotEmpty) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FillFormPage(slug: slug)));
                  } else {
                    setState(() => _errorText = 'Form tidak ditemukan');
                  }
                } else {
                  setState(() => _errorText = result['message'] ?? 'Link tidak valid');
                }
                
                if (mounted) {
                  setState(() => _isProcessing = false);
                  // Optionally restart the scanner after a failure so they can try again.
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted && _errorText != null) {
                      setState(() => _errorText = null);
                    }
                  });
                }
              },
            ),
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
