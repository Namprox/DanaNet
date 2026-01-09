import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KycApprovalTab extends StatelessWidget {
  const KycApprovalTab({super.key});

  // Hàm cập nhật trạng thái KYC (Duyệt hoặc Từ chối)
  Future<void> _updateKycStatus(BuildContext context, String uid, String status) async {
    try {
      // Cập nhật trạng thái lên Firebase
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'kycStatus': status, // 'verified' hoặc 'rejected'
      });

      if (context.mounted) {
        String msg = status == 'verified' ? "Đã duyệt xác thực!" : "Đã từ chối yêu cầu";

        // Hiển thị thông báo
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(msg),
                backgroundColor: status == 'verified' ? Colors.green : Colors.red
            )
        );

        // Đóng hộp thoại chi tiết ngay lập tức sau khi xử lý xong
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  // Hàm hiển thị ảnh an toàn (Tránh crash khi base64 lỗi)
  Widget _buildSafeImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return Container(
        height: 150,
        width: double.infinity,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Text("Người dùng chưa tải ảnh", style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(base64String),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.red),
                  SizedBox(height: 5),
                  Text("Lỗi hiển thị ảnh", style: TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Hiển thị chi tiết hồ sơ để duyệt
  void _showKycDetailDialog(BuildContext context, Map<String, dynamic> userData, String uid) {
    String frontBase64 = userData['kycFront'] ?? "";
    String backBase64 = userData['kycBack'] ?? "";

    showDialog(
      context: context,
      barrierDismissible: false, // Bắt buộc chọn thao tác mới đóng được
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),

        title: Text("Duyệt hồ sơ: ${userData['name']}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Mặt trước CCCD:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              _buildSafeImage(frontBase64),

              const SizedBox(height: 15),

              const Text("Mặt sau CCCD:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              _buildSafeImage(backBase64),
            ],
          ),
        ),
        actions: [

          // Nút Đóng
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Đóng", style: TextStyle(color: Colors.grey)),
          ),

          // Nút Từ chối
          TextButton(
            onPressed: () => _updateKycStatus(ctx, uid, 'rejected'),
            child: const Text("Từ chối", style: TextStyle(color: Colors.red)),
          ),

          // Nút Duyệt
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => _updateKycStatus(ctx, uid, 'verified'),
            child: const Text("DUYỆT HỒ SƠ"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // Lấy users có trạng thái KYC là 'pending'
        stream: FirebaseFirestore.instance.collection('users')
            .where('kycStatus', isEqualTo: 'pending')
            .orderBy('kycTimestamp', descending: false) // Ưu tiên người gửi trước
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user, size: 60, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("Không có yêu cầu xác thực nào")
                    ]
                )
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.person_search, color: Colors.white)),
                  title: Text(data['name'] ?? "Không tên", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Email: ${data['email']}\nSĐT: ${data['phone'] ?? 'Chưa cập nhật'}"),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () => _showKycDetailDialog(context, data, doc.id),
                    child: const Text("Xem"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}