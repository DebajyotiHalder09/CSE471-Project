import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/bus_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/bus.dart';

class QRScreen extends StatefulWidget {
  static const routeName = '/qr';

  const QRScreen({super.key});

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  String? _userFriendCode;
  bool _isLoading = true;

  String? _scanError;
  bool _isScanning = false;
  Map<String, dynamic>? _matchedBusRaw;
  Bus? _matchedBus;
  String? _lastScanned;

  @override
  void initState() {
    super.initState();
    _loadUserFriendCode();
  }

  Future<void> _loadUserFriendCode() async {
    try {
      final friendCode = await AuthService.getCurrentUserFriendCode();
      setState(() {
        _userFriendCode = friendCode;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openScanner() async {
    setState(() {
      _scanError = null;
      _matchedBus = null;
      _matchedBusRaw = null;
    });

    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => _QRScannerView()),
    );

    if (result == null || result.isEmpty) return;

    setState(() {
      _isScanning = true;
      _lastScanned = result;
    });

    try {
      final busInfoId = result.trim();
      final response = await BusService.getAllBuses();
      if (response['success'] == true && response['data'] is List) {
        final list = response['data'] as List<dynamic>;
        final match = list.firstWhere(
          (b) => (b as Map<String, dynamic>)['_id'] == busInfoId,
          orElse: () => {},
        );
        if (match is Map<String, dynamic> && match.isNotEmpty) {
          setState(() {
            _matchedBusRaw = match;
            _matchedBus = Bus.fromJson(match);
          });
        } else {
          setState(() {
            _scanError = 'No bus found for this QR';
          });
        }
      } else {
        setState(() {
          _scanError = 'Failed to fetch buses';
        });
      }
    } catch (e) {
      setState(() {
        _scanError = 'Failed to process QR: $e';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'QR Code',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(),
                  SizedBox(height: 32),
                  _buildQRCodeSection(),
                  SizedBox(height: 32),
                  _buildScanSection(),
                  SizedBox(height: 32),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.purple[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.qr_code,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Bus QR with Camera',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Point the camera at a QR to identify the bus',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Friend Code',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              _userFriendCode ?? 'Loading...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.blue[700],
                letterSpacing: 2,
              ),
            ),
          ),
          if (_lastScanned != null) ...[
            SizedBox(height: 12),
            Text(
              'Last scanned: $_lastScanned',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildScanSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.purple[600]),
              SizedBox(width: 8),
              Text(
                'Camera Scanner',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              TextButton.icon(
                onPressed: _isScanning ? null : _openScanner,
                icon: Icon(Icons.qr_code_scanner),
                label: Text('Scan QR'),
              ),
            ],
          ),
          if (_isScanning) ...[
            SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Processing QR...'),
              ],
            ),
          ],
          if (_scanError != null) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[600], size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _scanError!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_matchedBus != null) ...[
            SizedBox(height: 12),
            Divider(),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.directions_bus, color: Colors.green[600]),
                SizedBox(width: 8),
                Text(
                  'Matched Bus',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _matchedBus!.busName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.green[800],
                    ),
                  ),
                  SizedBox(height: 6),
                  if (_matchedBusRaw != null &&
                      _matchedBusRaw!['routeNumber'] != null)
                    Text(
                      'Route: ${_matchedBusRaw!['routeNumber']}',
                      style: TextStyle(fontSize: 14, color: Colors.green[700]),
                    ),
                  SizedBox(height: 8),
                  Text(
                    'Stops: ${_matchedBus!.stopNames.take(3).join(' → ')}${_matchedBus!.stops.length > 3 ? ' …' : ''}',
                    style: TextStyle(fontSize: 13, color: Colors.green[700]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openScanner,
            icon: Icon(Icons.qr_code_scanner),
            label: Text(
              'Scan QR',
              style: TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QRScannerView extends StatefulWidget {
  @override
  State<_QRScannerView> createState() => _QRScannerViewState();
}

class _QRScannerViewState extends State<_QRScannerView> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Scan QR', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_handled) return;
          final barcodes = capture.barcodes;
          if (barcodes.isEmpty) return;
          final value = barcodes.first.rawValue ?? '';
          if (value.isEmpty) return;
          _handled = true;
          Navigator.of(context).pop(value);
        },
      ),
    );
  }
}
