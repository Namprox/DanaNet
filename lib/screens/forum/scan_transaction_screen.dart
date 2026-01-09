import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class ScanTransactionScreen extends StatefulWidget {
  final String expectedPostId;

  const ScanTransactionScreen({
    super.key,
    required this.expectedPostId,
  });

  @override
  State<ScanTransactionScreen> createState() => _ScanTransactionScreenState();
}

class _ScanTransactionScreenState extends State<ScanTransactionScreen>
    with WidgetsBindingObserver {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  bool isScanning = true;

  @override
  void reassemble() {
    super.reassemble();
    if (mounted) {
      controller.stop();
      controller.start();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // Hàm xử lý khi quét được QR
  void _onDetect(BarcodeCapture capture) async {
    if (!isScanning) return;
    // Lấy Provider để dịch text
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    setState(() => isScanning = false);
    final String? code = barcodes.first.rawValue;

    if (code == null) {
      _showError(lang.getText('qr_invalid'));
      return;
    }

    try {
      Map<String, dynamic> data = jsonDecode(code);

      // Kiểm tra dữ liệu có đủ ko, bao gồm timestamp
      if (data['postId'] == null ||
          data['lat'] == null ||
          data['lng'] == null ||
          data['uid'] == null ||
          data['timestamp'] == null) {
        _showError(lang.getText('qr_missing_info'));
        return;
      }

      String scannedPostId = data['postId'];
      int qrTimestamp = data['timestamp'];

      // Kiểm tra mã QR có đúng là của bài viết đang xem ko
      if (scannedPostId != widget.expectedPostId) {
        _showError(lang.getText('qr_wrong_post'));
        return;
      }

      // Kiểm tra thời hạn mã QR (5 phút = 300000 ms)
      int currentTime = DateTime.now().millisecondsSinceEpoch;
      if (currentTime - qrTimestamp > 300000) {
        _showError(lang.getText('qr_expired'));
        return;
      }

      double sellerLat = double.parse(data['lat'].toString());
      double sellerLng = double.parse(data['lng'].toString());
      String sellerId = data['uid'];

      // Lấy vị trí hiện tại của Người Mua
      Position myPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Tính khoảng cách
      double distanceInMeters = Geolocator.distanceBetween(
          sellerLat, sellerLng, myPosition.latitude, myPosition.longitude);

      // Kiểm tra điều kiện 15 mét
      if (distanceInMeters > 15) {
        _showError(
            "${lang.getText('fraud_warning_1')} ${distanceInMeters.toStringAsFixed(1)}${lang.getText('fraud_warning_2')}");
        return;
      }

      // Nếu hợp lệ -> Gọi Transaction cập nhật Database
      await _confirmTransaction(scannedPostId, sellerId, myPosition);
    } catch (e) {
      _showError("QR Data Error: $e");
    }
  }

  Future<void> _confirmTransaction(
      String postId, String sellerId, Position myPos) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showError(lang.getText('login_required_action'));
      return;
    }

    try {
      await fs.FirebaseFirestore.instance.runTransaction((transaction) async {
        fs.DocumentReference postRef =
            fs.FirebaseFirestore.instance.collection('scrap_posts').doc(postId);
        fs.DocumentReference sellerRef =
            fs.FirebaseFirestore.instance.collection('users').doc(sellerId);

        // Đọc dữ liệu bài đăng trước khi cập nhật
        fs.DocumentSnapshot postSnapshot = await transaction.get(postRef);

        if (!postSnapshot.exists) {
          throw Exception(lang.getText('post_deleted_or_missing'));
        }

        // Kiểm tra trạng thái bài đăng
        if (postSnapshot.get('status') == 'completed') {
          throw Exception(lang.getText('transaction_already_completed'));
        }

        // Cập nhật bài viết
        transaction.update(postRef, {
          'status': 'completed',
          'buyerId': currentUser.uid,
          'completedAt': fs.FieldValue.serverTimestamp(),
          'transactionLocation': fs.GeoPoint(myPos.latitude, myPos.longitude),
          'isVerified': true,
          'pointsAwarded': 10,
        });

        // Cộng điểm cho Người Bán
        transaction.update(sellerRef, {
          'greenPoints': fs.FieldValue.increment(10),
          'totalSales': fs.FieldValue.increment(1),
        });
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(lang.getText('transaction_success_title')),
            content: Text(lang.getText('transaction_success_detail')),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context); // Đóng màn hình Scan
                    Navigator.pop(context); // Quay về màn hình Post Detail
                  },
                  child: const Text("OK"))
            ],
          ),
        );
      }
    } catch (e) {
      // Hiển thị lỗi từ transaction (VD: Đã hoàn thành)
      String errorMessage = e.toString();
      if (errorMessage.contains("Exception:")) {
        errorMessage = errorMessage.replaceAll("Exception: ", "");
      }
      _showError(errorMessage);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('notification'),
            style: const TextStyle(color: Colors.red)),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => isScanning = true); // Cho phép quét lại
              },
              child: Text(lang.getText('retry')))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('scan_confirm_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: _onDetect,
        errorBuilder: (context, error, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                Text(
                  "${lang.getText('camera_error_title')}\nError: ${error.errorCode}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    lang.getText('camera_perm_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        },
        overlayBuilder: (context, constraints) {
          return Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.green,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          );
        },
      ),
    );
  }
}

// Class vẽ khung overlay
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;
  final double cutOutBottomOffset;

  QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
    this.cutOutBottomOffset = 0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path _getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return _getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final _cutOutBottomOffset = cutOutBottomOffset + borderOffset;
    final _cutOutSize = cutOutSize + borderOffset * 2;
    final _borderLength = borderLength > _cutOutSize / 2 + borderWidth * 2
        ? _cutOutSize / 2 + borderWidth * 2
        : borderLength;
    final _cutOutWidth = _cutOutSize;
    final _cutOutHeight = _cutOutSize;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromCenter(
      center: rect.center.translate(0, -_cutOutBottomOffset / 2),
      width: _cutOutWidth,
      height: _cutOutHeight,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
        boxPaint,
      )
      ..restore();

    final borderPath = Path()
      ..moveTo(cutOutRect.left, cutOutRect.top + _borderLength)
      ..lineTo(cutOutRect.left, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(
        cutOutRect.left,
        cutOutRect.top,
        cutOutRect.left + borderRadius,
        cutOutRect.top,
      )
      ..lineTo(cutOutRect.left + _borderLength, cutOutRect.top)
      ..moveTo(cutOutRect.right, cutOutRect.top + _borderLength)
      ..lineTo(cutOutRect.right, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(
        cutOutRect.right,
        cutOutRect.top,
        cutOutRect.right - borderRadius,
        cutOutRect.top,
      )
      ..lineTo(cutOutRect.right - _borderLength, cutOutRect.top)
      ..moveTo(cutOutRect.right, cutOutRect.bottom - _borderLength)
      ..lineTo(cutOutRect.right, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(
        cutOutRect.right,
        cutOutRect.bottom,
        cutOutRect.right - borderRadius,
        cutOutRect.bottom,
      )
      ..lineTo(cutOutRect.right - _borderLength, cutOutRect.bottom)
      ..moveTo(cutOutRect.left, cutOutRect.bottom - _borderLength)
      ..lineTo(cutOutRect.left, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(
        cutOutRect.left,
        cutOutRect.bottom,
        cutOutRect.left + borderRadius,
        cutOutRect.bottom,
      )
      ..lineTo(cutOutRect.left + _borderLength, cutOutRect.bottom);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
      borderRadius: borderRadius,
      borderLength: borderLength,
      cutOutSize: cutOutSize,
      cutOutBottomOffset: cutOutBottomOffset,
    );
  }
}