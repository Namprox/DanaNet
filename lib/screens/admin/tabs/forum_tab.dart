import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForumManagementTab extends StatelessWidget {
  const ForumManagementTab({super.key});

  void _deletePost(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa bài viết vi phạm?"),
        content: const Text(
            "Hành động này sẽ xóa vĩnh viễn bài đăng khỏi hệ thống. Bạn có chắc chắn không?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('scrap_posts')
                  .doc(docId)
                  .delete();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Đã xóa bài viết thành công!")));
              }
            },
            child: const Text("Xóa ngay"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final borderColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('scrap_posts')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(child: Text("Diễn đàn chưa có bài viết nào"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            bool isSeller = data['role'] == 'seller';
            // Kiểm tra trạng thái đã giao dịch
            bool isCompleted = data['status'] == 'completed';

            String userName = data['userName'] ?? "Ẩn danh";
            String userEmail = data['userEmail'] ?? "";
            String userId = data['uid'] ?? data['userId'] ?? "";

            String firstLetter =
                userName.isNotEmpty ? userName[0].toUpperCase() : "?";
            String? imageBase64 = data['imageBase64'];
            DateTime? date = data['timestamp'] != null
                ? (data['timestamp'] as Timestamp).toDate()
                : null;
            String timeStr = date != null
                ? "${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute}"
                : "Vừa xong";

            return Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor, width: 1)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                        backgroundColor: isSeller ? Colors.green : Colors.blue,
                        child: Text(firstLetter,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold))),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        userId.isEmpty
                            ? Text(userName,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor))
                            : StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .snapshots(),
                                builder: (context, userSnapshot) {
                                  bool isVerified = false;
                                  if (userSnapshot.hasData &&
                                      userSnapshot.data!.exists) {
                                    var userData = userSnapshot.data!.data()
                                        as Map<String, dynamic>;
                                    if (userData['kycStatus'] == 'verified') {
                                      isVerified = true;
                                    }
                                  }

                                  return Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          userName,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: textColor),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isVerified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified,
                                            color: Colors.blue, size: 16),
                                      ]
                                    ],
                                  );
                                },
                              ),
                        if (userEmail.isNotEmpty)
                          Text(userEmail,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.normal)),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: isSeller
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(isSeller ? "Cần Bán" : "Cần Mua",
                                style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        isSeller ? Colors.green : Colors.blue,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text(timeStr,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        tooltip: "Xóa bài viết vi phạm",
                        onPressed: () => _deletePost(context, doc.id)),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['title'] ?? "Không tiêu đề",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null // Gạch ngang nếu đã xong
                                )),
                        const SizedBox(height: 5),
                        Text(data['content'] ?? "",
                            style: TextStyle(
                                color: isDarkMode
                                    ? Colors.grey.shade300
                                    : Colors.black87)),
                        const SizedBox(height: 10),

                        // Ảnh bài viết
                        if (imageBase64 != null && imageBase64.isNotEmpty)
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.grey.shade300)),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                        base64Decode(imageBase64),
                                        fit: BoxFit.contain,
                                        width: double.infinity,
                                        color: isCompleted
                                            ? Colors.white.withOpacity(0.4)
                                            : null,
                                        colorBlendMode: isCompleted
                                            ? BlendMode.modulate
                                            : null,
                                        errorBuilder: (c, e, s) => const Center(
                                            child: Icon(Icons.broken_image,
                                                color: Colors.grey)))),

                                // Đóng dấu ĐÃ GIAO DỊCH lên ảnh
                                if (isCompleted)
                                  Transform.rotate(
                                    angle: -0.2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.red, width: 4),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: const Text(
                                        "ĐÃ GIAO DỊCH",
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2),
                                      ),
                                    ),
                                  )
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Footer Địa chỉ
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color:
                            isDarkMode ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.phone,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(data['phone'] ?? "---",
                                style:
                                    TextStyle(color: textColor, fontSize: 13))
                          ]),
                          const SizedBox(height: 4),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['address'] ?? "---",
                                    style: TextStyle(
                                        color: textColor, fontSize: 13),
                                  ),
                                )
                              ]),
                        ]),
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