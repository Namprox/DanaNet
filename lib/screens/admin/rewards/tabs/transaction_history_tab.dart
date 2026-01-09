import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TransactionHistoryTab extends StatelessWidget {
  const TransactionHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('scrap_posts')
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 40),
                  const SizedBox(height: 10),
                  const Text("Cần tạo Index trên Firebase",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SelectableText("Lỗi: ${snapshot.error}",
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Chưa có giao dịch nào hoàn tất"));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return TransactionItem(data: data);
          },
        );
      },
    );
  }
}

class TransactionItem extends StatelessWidget {
  final Map<String, dynamic> data;

  const TransactionItem({super.key, required this.data});

  Future<Map<String, dynamic>> _fetchUserInfo(String? uid) async {
    if (uid == null || uid.isEmpty) return {};
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    }
    return {};
  }

  Widget _buildPostImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
            color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          base64Decode(base64String),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
        ),
      );
    } catch (e) {
      return const Icon(Icons.broken_image);
    }
  }

  Widget _buildUserRow(String uid, String roleLabel, IconData roleIcon,
      Color iconColor, String defaultName) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchUserInfo(uid),
      builder: (context, snapshot) {
        String displayName = defaultName;
        String contactInfo = "";
        IconData contactIcon = Icons.email_outlined;
        bool isVerified = false;

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          var userData = snapshot.data!;
          displayName = userData['name'] ?? userData['userName'] ?? defaultName;

          String email = userData['email'] ?? "";
          String phone = userData['phone'] ?? "";

          if (email.isNotEmpty) {
            contactInfo = email;
            contactIcon = Icons.email_outlined;
          } else if (phone.isNotEmpty) {
            contactInfo = phone;
            contactIcon = Icons.phone_android;
          } else {
            contactInfo = "Chưa cập nhật liên hệ";
            contactIcon = Icons.info_outline;
          }
          isVerified = userData['kycStatus'] == 'verified';
        } else {
          contactInfo = "Đang tải thông tin...";
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.2),
              radius: 18,
              child: Icon(roleIcon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roleLabel,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.verified,
                              color: Colors.blue, size: 14),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(contactIcon, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          contactInfo,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String sellerId = data['uid'] ?? "";
    String buyerId = data['buyerId'] ?? "";
    String postTitle = data['title'] ?? "Bài viết không tên";
    String? postImage = data['imageBase64'];

    String time = data['completedAt'] != null
        ? DateFormat('HH:mm - dd/MM/yyyy')
            .format((data['completedAt'] as Timestamp).toDate())
        : "---";

    String postedTime = "---";
    if (data['timestamp'] != null) {
      postedTime = DateFormat('dd/MM/yyyy')
          .format((data['timestamp'] as Timestamp).toDate());
    }

    String address = data['fullAddress'] ?? "";
    if (address.isEmpty) {
      List<String> parts = [];
      if (data['address'] != null) parts.add(data['address']);
      if (data['ward'] != null) parts.add(data['ward']);
      if (data['district'] != null) parts.add(data['district']);
      if (data['city'] != null) parts.add(data['city']);
      address = parts.join(", ");
    }
    if (address.isEmpty) address = "Không có địa chỉ";

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.history, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text("GD: $time",
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.5))),
                  child: Text("+${data['pointsAwarded'] ?? 10} điểm",
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPostImage(postImage),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Sản phẩm giao dịch:",
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          postTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2.0),
                              child: Icon(Icons.location_on,
                                  size: 12, color: Colors.red),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 12, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              "Đăng: $postedTime",
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 15),
            _buildUserRow(sellerId, "Người bán (Nhận điểm)", Icons.store,
                Colors.blue, data['userName'] ?? "Người bán"),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
            ),
            _buildUserRow(
                buyerId,
                "Người mua (Quét mã)",
                Icons.qr_code_scanner,
                Colors.orange,
                "Người mua (ID: ${buyerId.length > 4 ? buyerId.substring(0, 4) : '...'})"),
          ],
        ),
      ),
    );
  }
}