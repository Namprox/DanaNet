import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'post_detail_screen.dart';

class ForumPostCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final Map<String, dynamic> data;

  const ForumPostCard({super.key, required this.doc, required this.data});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe ngôn ngữ
    final lang = Provider.of<LanguageProvider>(context);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final completedCardColor =
        isDarkMode ? Colors.white10 : Colors.grey.shade200;
    final defaultCardColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final borderColor =
        isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

    bool isSeller = data['role'] == 'seller';
    bool isCompleted = data['status'] == 'completed';
    String? imageBase64 = data['imageBase64'];

    String userName =
        data['userName'] ?? lang.getText('anonymous_user');
    String userId = data['uid'] ?? data['userId'] ?? "";

    String firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : "A";

    // Loại rác có thể cần mapping lại nếu lưu cứng tiếng Việt trong DB
    // Giữ nguyên data['type'] vì nó là dữ liệu người dùng chọn
    // Nếu muốn dịch cả cái này thì cần 1 map chuyển đổi riêng
    String wasteType = data['type'] ?? lang.getText('other_waste');

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      color: isCompleted ? completedCardColor : defaultCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      PostDetailScreen(postId: doc.id, postData: data)));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: isCompleted
                    ? Colors.grey
                    : (isSeller ? Colors.green : Colors.blue),
                child: Text(firstLetter,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              title: userId.isEmpty
                  ? Text(userName,
                      style: const TextStyle(fontWeight: FontWeight.bold))
                  : StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        bool isVerified = false;

                        if (snapshot.hasData && snapshot.data!.exists) {
                          var userData =
                              snapshot.data!.data() as Map<String, dynamic>;
                          String status = userData['kycStatus'] ?? 'none';

                          if (status == 'verified') {
                            isVerified = true;
                          }
                        }

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                userName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted
                                      ? Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color
                                          ?.withOpacity(0.6)
                                      : null,
                                ),
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
              subtitle: Row(
                children: [
                  Text(
                    // Dùng text từ lang provider
                    isSeller
                        ? lang.getText('sell_prefix')
                        : lang.getText('buy_prefix'),
                    style: TextStyle(
                      color: isCompleted
                          ? Colors.grey
                          : (isSeller ? Colors.green : Colors.blue),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.grey.withOpacity(0.2)
                          : (isSeller
                              ? Colors.green
                                  .withOpacity(isDarkMode ? 0.25 : 0.1)
                              : Colors.blue
                                  .withOpacity(isDarkMode ? 0.25 : 0.1)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      wasteType,
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted
                            ? Colors.grey
                            : (isDarkMode ? Colors.white : Colors.black87),
                      ),
                    ),
                  )
                ],
              ),
              trailing: Text(
                _formatDate(data['timestamp'], lang),
                // Truyền lang vào hàm
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? "",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted
                          ? Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.6)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(data['content'] ?? "",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  if (imageBase64 != null && imageBase64.isNotEmpty)
                    Container(
                      height: 200,
                      width: double.infinity,
                      foregroundDecoration: isCompleted
                          ? const BoxDecoration(
                              color: Colors.black26,
                              backgroundBlendMode: BlendMode.darken)
                          : null,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(imageBase64),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                  child: Icon(Icons.broken_image,
                                      color: Colors.grey)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['address'] ?? lang.getText('no_address'),
                            style: const TextStyle(height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted)
                    Container(
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          lang.getText('transaction_completed'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                    )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // Thêm tham số lang
  String _formatDate(dynamic timestamp, LanguageProvider lang) {
    if (timestamp == null) return lang.getText('just_now');
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    }
    return lang.getText('recently');
  }
}