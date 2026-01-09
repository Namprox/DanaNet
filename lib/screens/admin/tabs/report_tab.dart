import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportListTab extends StatelessWidget {
  final String statusFilter;

  const ReportListTab({super.key, required this.statusFilter});

  void _confirmUndo(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận hủy"),
        content: const Text("Bạn có chắc chắn muốn hủy trạng thái 'Đã thu gom' và đưa báo cáo này về 'Đang chờ' không?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Không")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () {
              FirebaseFirestore.instance.collection('reports').doc(docId).update({'status': 'pending'});
              Navigator.of(ctx).pop();
            },
            child: const Text("Đồng ý hủy"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final borderColor = isDarkMode ? Colors.grey.shade700 : Colors.transparent;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey[700];

    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('reports').where('status', isEqualTo: statusFilter).snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusFilter == 'pending' ? Icons.done_all : Icons.history, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(statusFilter == 'pending' ? "Tuyệt vời! Đã hết việc" : "Chưa có lịch sử thu gom", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var reportDoc = snapshot.data!.docs[index];
            var data = reportDoc.data() as Map<String, dynamic>;

            // Trích xuất dữ liệu
            String name = data['name'] ?? data['username'] ?? "Người dùng ẩn danh";
            String email = data['email'] ?? "";
            String phone = data['phone'] ?? "";

            String uid = data['uid'] ?? "";

            // Xác dịnh liên hệ
            String contactInfo = "";
            IconData contactIcon = Icons.email;

            if (email.isNotEmpty) {
              contactInfo = email;
              contactIcon = Icons.email_outlined;
            } else if (phone.isNotEmpty) {
              contactInfo = phone;
              contactIcon = Icons.phone_android;
            }

            DateTime? date = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null;
            String timeStr = date != null ? "${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.day}/${date.month}/${date.year}" : "Vừa xong";

            bool isDone = data['status'] == 'done';
            String? imageBase64 = data['imageBase64'];
            String? imagePath = data['imagePath'];

            return Card(
              margin: const EdgeInsets.only(bottom: 20),
              elevation: 4,
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor, width: 1)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    tileColor: isDarkMode ? Colors.black26 : (isDone ? Colors.green.shade50 : Colors.blue.shade50),
                    leading: CircleAvatar(
                        backgroundColor: isDone ? Colors.green : Colors.blue,
                        child: Icon(isDone ? Icons.check : Icons.person, color: Colors.white)
                    ),

                    // HIển thị tên và liên hệ
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dùng StreamBuilder để hiển thị Tên + Tích xanh
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Logic kiểm tra KYC
                            if (uid.isNotEmpty)
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                                builder: (context, userSnapshot) {
                                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                    var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                    if (userData['kycStatus'] == 'verified') {
                                      return const Padding(
                                        padding: EdgeInsets.only(left: 4.0),
                                        child: Icon(Icons.verified, color: Colors.blue, size: 16),
                                      );
                                    }
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                          ],
                        ),

                        // Nếu có thông tin liên hệ
                        if (contactInfo.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Icon(contactIcon, size: 12, color: subTextColor),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    contactInfo,
                                    style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.normal),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: isDone ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(12)),
                      child: Text(isDone ? "ĐÃ XỬ LÝ" : "CHỜ XỬ LÝ", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // Phần hiển thị ảnh
                  if (imageBase64 != null && imageBase64.isNotEmpty)
                    Container(height: 250, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200]), child: Image.memory(base64Decode(imageBase64), fit: BoxFit.contain, errorBuilder: (c, e, s) => const Center(child: Text("Lỗi ảnh"))))
                  else if (imagePath != null && imagePath.isNotEmpty)
                    Container(height: 200, width: double.infinity, color: Colors.grey[300], child: const Center(child: Text("Ảnh cũ", style: TextStyle(color: Colors.grey)))),

                  // Phần nội dung và địa chỉ
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [const Icon(Icons.location_on, color: Colors.red, size: 20), const SizedBox(width: 5), Expanded(child: Text("${data['address']}, ${data['ward']}, ${data['district']}, ${data['city']}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)))]),
                        const Divider(color: Colors.grey),
                        Text("Nội dung: ${data['content']}", style: TextStyle(fontSize: 16, color: textColor)),
                      ],
                    ),
                  ),

                  // Nút bấm xác nhận/hủy
                  Container(
                    color: isDarkMode ? Colors.black12 : Colors.grey.shade50,
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.centerRight,
                    child: !isDone
                        ? ElevatedButton.icon(onPressed: () => FirebaseFirestore.instance.collection('reports').doc(reportDoc.id).update({'status': 'done'}), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), icon: const Icon(Icons.check_circle), label: const Text("Xác nhận đã thu gom"))
                        : ElevatedButton.icon(onPressed: () => _confirmUndo(context, reportDoc.id), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), icon: const Icon(Icons.undo), label: const Text("Hủy xác nhận")),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}