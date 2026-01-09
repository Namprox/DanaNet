import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'create_post_screen.dart';
import 'scan_transaction_screen.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const PostDetailScreen(
      {super.key, required this.postId, required this.postData});

  // 1. Helper: Lấy tọa độ GPS
  Future<Position> _determinePosition(LanguageProvider lang) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(lang.getText('enable_gps_err'));
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(lang.getText('gps_denied_err'));
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(lang.getText('gps_permanent_denied_err'));
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  // 2. Logic: Hiện Mã QR Giao Dịch
  void _showQrCodeForBuyer(BuildContext context, LanguageProvider lang) async {
    // Hiển thị loading khi đang lấy GPS
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      // Lấy vị trí người bán
      Position position = await _determinePosition(lang);

      if (!context.mounted) return;
      Navigator.pop(context); // Tắt loading

      // Đóng gói dữ liệu để tạo QR, thêm timestamp để kiểm tra hạn 5 phút
      Map<String, dynamic> qrData = {
        'postId': postId,
        'uid': postData['uid'], // ID người bán
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch, // Thời gian tạo mã
      };

      String qrString = jsonEncode(qrData);

      // Hiển thị Dialog chứa QR Code
      showDialog(
        context: context,
        barrierDismissible: false,
        // Bắt buộc người dùng phải bấm Đóng hoặc chờ quét
        builder: (ctx) {
          // Bọc AlertDialog trong StreamBuilder để lắng nghe thay đổi trạng thái
          // Nếu người mua quét xong -> status đổi thành 'completed' -> Tự đóng dialog này
          return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('scrap_posts')
                  .doc(postId)
                  .snapshots(),
              builder: (context, snapshot) {
                // Kiểm tra nếu bài viết đã chuyển sang trạng thái 'completed'
                if (snapshot.hasData && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  if (data['status'] == 'completed') {
                    // Dùng addPostFrameCallback để đóng Dialog an toàn sau khi render xong
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Tự động đóng Dialog QR
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text(lang.getText('transaction_success_msg')),
                            backgroundColor: Colors.green));
                      }
                    });
                  }
                }

                return AlertDialog(
                  title: Text(lang.getText('qr_auth_title')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 200,
                        width: 200,
                        child: QrImageView(
                          data: qrString,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        lang.getText('qr_instruction'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),

                      // Cảnh báo thời gian hiệu lực
                      const SizedBox(height: 8),
                      Text(
                        lang.getText('qr_validity_warning'),
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text(lang.getText('waiting_buyer_scan'),
                              style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                  fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(lang.getText('close')),
                    )
                  ],
                );
              });
        },
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Đóng loading nếu lỗi GPS
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${lang.getText('error')}: $e")));
      }
    }
  }

  // 3. Logic: Hoàn tác giao dịch (Chỉ dùng khi muốn hủy giao dịch đã xong)
  Future<void> _handleUndoTransaction(
      BuildContext context, LanguageProvider lang) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Hỏi xác nhận trước khi hoàn tác
    bool? confirmUndo = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('undo_title')),
        content: Text(lang.getText('undo_msg')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang.getText('cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white),
              child: Text(lang.getText('agree_undo'))),
        ],
      ),
    );

    if (confirmUndo != true) return;

    try {
      final postRef =
          FirebaseFirestore.instance.collection('scrap_posts').doc(postId);
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Trừ lại điểm đã cộng
        transaction.update(userRef, {
          'greenPoints': FieldValue.increment(-10),
          'totalSales': FieldValue.increment(-1),
        });

        // 2. Cập nhật bài viết: Xóa sạch thông tin giao dịch cũ
        transaction.update(postRef, {
          'status': 'active',
          'isVerified': false,
          'completedAt': FieldValue.delete(),
          'transactionLocation': FieldValue.delete(),
          'pointsAwarded': FieldValue.delete(),
          'sellerId': FieldValue.delete(),
          'buyerId': FieldValue.delete(),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.getText('undo_success'))));
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${lang.getText('error')}: $e")));
    }
  }

  // Helper: Lấy danh sách lý do báo cáo
  List<String> _getReportReasons(LanguageProvider lang) {
    return [
      lang.getText('reason_scam'),
      lang.getText('reason_prohibited'),
      lang.getText('reason_spam'),
      lang.getText('reason_hate'),
      lang.getText('reason_other'),
    ];
  }

  // 4. Dialog Báo cáo vi phạm
  void _showReportDialog(BuildContext context, LanguageProvider lang) {
    final reasonController = TextEditingController();
    final List<String> reasons = _getReportReasons(lang);
    String selectedReason = reasons[0];

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('login_to_report'))));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('report_post_title')),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(lang.getText('select_reason_label'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  items: reasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedReason = v!),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                      labelText: lang.getText('report_detail_hint'),
                      border: const OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.getText('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('forum_reports')
                    .add({
                  'postId': postId,
                  'postTitle': postData['title'] ?? 'Không tiêu đề',
                  'reportedUser': postData['uid'],
                  'reporterId': currentUser.uid,
                  'reporterUid': currentUser.uid,
                  'reporterEmail': currentUser.email ?? "Không có email",
                  'reason': selectedReason,
                  'detail': reasonController.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'pending',
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(lang.getText('report_thank_you')),
                      backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("${lang.getText('error')}: $e")));
                }
              }
            },
            child: Text(lang.getText('send_report_btn')),
          ),
        ],
      ),
    );
  }

  // 5. Hàm Gọi điện thoại
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      print("Không thể gọi số $phoneNumber");
    }
  }

  // 6. Hàm Xóa bài viết
  void _deletePost(BuildContext context, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('delete_post_confirm')),
        content: Text(lang.getText('action_cannot_undo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang.getText('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('scrap_posts')
                  .doc(postId)
                  .delete();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(lang.getText('delete_post_success'))));
              }
            },
            child: Text(lang.getText('delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    User? currentUser = FirebaseAuth.instance.currentUser;
    bool isOwner = currentUser != null && currentUser.uid == postData['uid'];

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('scrap_posts')
            .doc(postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          if (!snapshot.data!.exists) {
            return Scaffold(
                body: Center(
                    child: Text(lang.getText('post_deleted_or_missing'))));
          }

          var currentData = snapshot.data!.data() as Map<String, dynamic>;
          bool isSeller = currentData['role'] == 'seller';
          bool isCompleted = currentData['status'] == 'completed';

          String userName =
              currentData['userName'] ?? lang.getText('anonymous');
          String firstLetter =
              userName.isNotEmpty ? userName[0].toUpperCase() : "A";
          String wasteType = currentData['type'] ?? lang.getText('other');

          Widget? bottomButton;

          if (isOwner) {
            if (isSeller) {
              if (isCompleted) {
                // Nếu đã hoàn thành -> Hiện nút Hoàn Tác
                bottomButton = ElevatedButton.icon(
                  onPressed: () => _handleUndoTransaction(context, lang),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.undo),
                  label: Text(lang.getText('undo_transaction_btn'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                );
              } else {
                // Nếu chưa hoàn thành -> Hiện nút Mã QR
                bottomButton = ElevatedButton.icon(
                  onPressed: () => _showQrCodeForBuyer(context, lang),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.qr_code),
                  label: Text(lang.getText('show_qr_btn'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                );
              }
            } else {
              bottomButton = null;
            }
          } else {
            // Nếu là khách (Người Mua)
            bottomButton = Row(
              children: [
                // Nút Gọi điện
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _makePhoneCall(currentData['phone'] ?? ""),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.call),
                    label: Text(lang.getText('call_btn'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                // Nút Quét QR
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isCompleted
                        ? null
                        : () {
                            // Chuyển sang màn hình quét QR
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => ScanTransactionScreen(
                                        expectedPostId: postId)));
                          },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(
                        isCompleted
                            ? lang.getText('transaction_done_btn')
                            : lang.getText('scan_qr_btn'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(lang.getText('post_detail_title')),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.black,
              actions: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CreatePostScreen(
                                  postId: postId, existingData: currentData)));
                    } else if (value == 'delete') {
                      _deletePost(context, lang);
                    } else if (value == 'report') {
                      _showReportDialog(context, lang);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    if (isOwner) {
                      return [
                        PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              const Icon(Icons.edit, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(lang.getText('edit_post_menu'))
                            ])),
                        PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              const Icon(Icons.delete, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(lang.getText('delete_post_menu'))
                            ])),
                      ];
                    } else {
                      return [
                        PopupMenuItem(
                            value: 'report',
                            child: Row(children: [
                              const Icon(Icons.flag, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(lang.getText('report_violation_menu'))
                            ])),
                      ];
                    }
                  },
                ),
              ],
            ),
            bottomNavigationBar: bottomButton != null
                ? Padding(
                    padding: const EdgeInsets.all(16.0), child: bottomButton)
                : null,
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hiển thị hình ảnh
                  if (currentData['imageBase64'] != null &&
                      currentData['imageBase64'].toString().isNotEmpty)
                    Image.memory(
                      base64Decode(currentData['imageBase64']),
                      width: double.infinity,
                      fit: BoxFit.contain,
                      color: isCompleted ? Colors.white.withOpacity(0.3) : null,
                      colorBlendMode: isCompleted ? BlendMode.modulate : null,
                      errorBuilder: (c, e, s) => Container(
                          height: 250,
                          color: Colors.grey[200],
                          child:
                              Center(child: Text(lang.getText('image_error')))),
                    )
                  else
                    Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: const Center(
                            child: Icon(Icons.image_not_supported,
                                size: 50, color: Colors.grey))),

                  // Banner thông báo đã hoàn tất
                  if (isCompleted)
                    Container(
                      width: double.infinity,
                      color: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(lang.getText('transaction_completed_banner'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag Cần Mua / Cần Bán
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: isSeller
                                  ? Colors.green.shade100
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(5)),
                          child: Text(
                              isSeller
                                  ? lang.getText('want_to_sell_tag')
                                  : lang.getText('want_to_buy_tag'),
                              style: TextStyle(
                                  color: isSeller
                                      ? Colors.green.shade900
                                      : Colors.blue.shade900,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 10),

                        // Tiêu đề
                        Text(currentData['title'] ?? "",
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null)),
                        const SizedBox(height: 10),

                        // Thông tin người đăng
                        Row(children: [
                          CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  isSeller ? Colors.green : Colors.blue,
                              child: Text(firstLetter,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold))),
                          const SizedBox(width: 8),
                          Text(userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16))
                        ]),
                        const SizedBox(height: 8),

                        // Loại phế liệu
                        Row(children: [
                          const Icon(Icons.category, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(wasteType, style: const TextStyle(fontSize: 16))
                        ]),
                        const SizedBox(height: 8),

                        // Số điện thoại
                        Row(children: [
                          const Icon(Icons.phone, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(currentData['phone'] ?? "",
                              style: const TextStyle(fontSize: 16))
                        ]),
                        const SizedBox(height: 8),

                        // Địa chỉ
                        Row(children: [
                          const Icon(Icons.location_on, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(currentData['address'] ?? "",
                                  style: const TextStyle(fontSize: 16)))
                        ]),
                        const Divider(height: 30),

                        // Mô tả
                        Text(lang.getText('description_header'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text(
                            currentData['content'] ??
                                lang.getText('no_description'),
                            style: const TextStyle(fontSize: 16, height: 1.5)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        });
  }
}