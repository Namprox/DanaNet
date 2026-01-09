import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackListTab extends StatelessWidget {
  const FeedbackListTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Xác định chế độ Sáng/Tối
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Cấu hình màu sắc
    final cardColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey[700];
    final borderColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('feedbacks').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Chưa có đánh giá nào"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;

            // Lấy dữ liệu cơ bản
            int rating = data['rating'] ?? 5;
            String name = data['name'] ?? "Ẩn danh";
            // Lấy ID người dùng để kiểm tra xác thực
            String userId = data['userId'] ?? data['uid'] ?? "";

            String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "A";
            DateTime? date = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null;
            String timeStr = date != null ? "${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute}" : "";

            return Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor, width: 1.5),
              ),

              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: Text(firstLetter, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Row chứa Tên + Icon xác thực
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),

                                      // Logic hiển thị tích xanh
                                      if (userId.isNotEmpty)
                                        StreamBuilder<DocumentSnapshot>(
                                          stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
                                          builder: (context, userSnapshot) {
                                            if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                              var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                              // Kiểm tra trạng thái Verified
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

                                  if (data['email'] != null)
                                    Text(data['email'], style: TextStyle(fontSize: 12, color: subTextColor)),
                                ]
                            )
                        ),
                        Row(children: List.generate(5, (i) => Icon(i < rating ? Icons.star : Icons.star_border, size: 18, color: Colors.amber)))
                      ],
                    ),

                    Divider(color: borderColor, height: 20),

                    Text(data['content'] ?? "", style: TextStyle(fontSize: 15, color: textColor)),
                    const SizedBox(height: 8),
                    Align(
                        alignment: Alignment.bottomRight,
                        child: Text(timeStr, style: TextStyle(fontSize: 11, color: subTextColor, fontStyle: FontStyle.italic))
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}