import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RedemptionHistoryTab extends StatefulWidget {
  const RedemptionHistoryTab({super.key});

  @override
  State<RedemptionHistoryTab> createState() => _RedemptionHistoryTabState();
}

class _RedemptionHistoryTabState extends State<RedemptionHistoryTab> {
  // Hàm hiển thị Dialog xác nhận
  Future<bool> _confirmDialog(String msg) async {
    return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Xác nhận"),
            content: Text(msg),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Không")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Có")),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('redemptions')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Chưa có lượt đổi quà"));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            return RedemptionItem(
              data: data,
              docId: doc.id,
              onConfirm: () async {
                if (await _confirmDialog("Xác nhận đã gửi quà cho user?")) {
                  await FirebaseFirestore.instance
                      .collection('redemptions')
                      .doc(doc.id)
                      .update({'status': 'completed'});
                }
              },
            );
          },
        );
      },
    );
  }
}

class RedemptionItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onConfirm;

  const RedemptionItem({
    super.key,
    required this.data,
    required this.docId,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    String uid = data['uid'] ?? "";
    bool isPending = (data['status'] ?? 'pending') == 'pending';

    // Xử lý hiển thị thời gian
    String timeString = "---";
    if (data['timestamp'] != null) {
      Timestamp t = data['timestamp'];
      DateTime date = t.toDate();
      timeString = DateFormat('HH:mm - dd/MM/yyyy').format(date);
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        String name = "Đang tải...";
        String contact = "";
        String address = "";
        int currentPoints = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          // Lấy trường 'name' theo dữ liệu cung cấp
          name = userData['name'] ?? userData['userName'] ?? "User ẩn danh";

          // Lấy email hoặc sđt
          String email = userData['email'] ?? "";
          String phone = userData['phone'] ?? "";
          contact = email.isNotEmpty ? email : phone;

          address = userData['address'] ?? "Chưa cập nhật địa chỉ";
          currentPoints = userData['greenPoints'] ?? 0;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['rewardTitle'] ?? "Voucher",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),

                      const SizedBox(height: 4),

                      // Hiển thị dòng thời gian
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 14, color: Colors.blueGrey),
                          const SizedBox(width: 4),
                          Text(
                            timeString,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      // Hiển thị tên user và điểm hiện tại
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: textColor, fontSize: 13),
                          children: [
                            const WidgetSpan(
                                child: Icon(Icons.person,
                                    size: 14, color: Colors.grey)),
                            const TextSpan(text: " "),
                            TextSpan(
                                text: name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            TextSpan(
                                text: " (Hiện có: $currentPoints điểm)",
                                style: const TextStyle(color: Colors.green)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Hiển thị liên hệ
                      if (contact.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.contact_mail,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(contact,
                                    style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      // Hiển thị địa chỉ
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2.0),
                            child: Icon(Icons.location_on,
                                size: 14, color: Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(address,
                                  style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text("Đã trừ: ${data['pointsSpent']} điểm",
                          style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                ),
                // Nút xác nhận
                if (isPending)
                  IconButton(
                    icon: const Icon(Icons.check_box_outline_blank,
                        color: Colors.orange, size: 30),
                    tooltip: "Xác nhận đã gửi quà",
                    onPressed: onConfirm,
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.check_box, color: Colors.green, size: 30),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}