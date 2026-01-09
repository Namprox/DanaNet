import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  // Thêm tham số lang để dịch text
  void _deleteReport(
      BuildContext context, String docId, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('confirm_delete')),
        content: Text(lang.getText('delete_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(lang.getText('cancel')), // Dùng lại key 'cancel'
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('reports')
                    .doc(docId)
                    .delete();
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(lang.getText('deleted'))));
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text("${lang.getText('delete_err')}: $e")));
                }
              }
            },
            child: Text(lang.getText('delete')),
          ),
        ],
      ),
    );
  }

  // Thêm tham số lang để dịch text
  void _editReport(BuildContext context, String docId, String currentContent,
      String currentAddress, LanguageProvider lang) {
    final contentController = TextEditingController(text: currentContent);
    final addressController = TextEditingController(text: currentAddress);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('update_info')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ô nhập địa chỉ
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: lang.getText('street_name'),
                  // Dùng lại key 'street_name' bên profile
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 15),
              // Ô nhập nội dung
              TextField(
                controller: contentController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: lang.getText('content_desc'),
                  border: const OutlineInputBorder(),
                  hintText: lang.getText('enter_new_content'),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(lang.getText('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate cơ bản
              if (contentController.text.trim().isEmpty ||
                  addressController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(lang.getText('please_fill'))));
                return;
              }

              try {
                // Update cả address và content
                await FirebaseFirestore.instance
                    .collection('reports')
                    .doc(docId)
                    .update({
                  'address': addressController.text.trim(),
                  'content': contentController.text.trim(),
                });

                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(lang.getText(
                          'update_success')))); // Dùng lại key 'update_success'
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text("${lang.getText('update_err')}: $e")));
                }
              }
            },
            child: Text(
                lang.getText('save_changes')), // Dùng lại key 'save_changes'
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Gọi Provider ngôn ngữ
    final lang = Provider.of<LanguageProvider>(context);

    final user = FirebaseAuth.instance.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('history_title')),
        backgroundColor:
            isDarkMode ? Colors.green.shade900 : Colors.green.shade100,
        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
      ),
      body: user == null
          ? Center(child: Text(lang.getText('login_required')))
          : StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('uid', isEqualTo: user.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                          "${lang.getText('load_err')}: ${snapshot.error}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history, size: 60, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text(lang.getText('no_reports'),
                            style:
                                const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final reports = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    var doc = reports[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String docId = doc.id;

                    // Xử lý thời gian
                    DateTime? date;
                    if (data['timestamp'] != null) {
                      date = (data['timestamp'] as Timestamp).toDate();
                    }
                    String timeStr = date != null
                        ? "${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.day}/${date.month}/${date.year}"
                        : "";

                    bool isDone = data['status'] == 'done';
                    String? imageBase64 = data['imageBase64'];
                    String? imagePath = data['imagePath'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDone ? Colors.green : Colors.orange,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                        isDone
                                            ? Icons.check_circle
                                            : Icons.hourglass_bottom,
                                        size: 16,
                                        color: Colors.white),
                                    const SizedBox(width: 5),
                                    // Text trạng thái
                                    Text(
                                        isDone
                                            ? lang.getText('processed')
                                            : lang.getText('pending'),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                  ],
                                ),
                                Text(timeStr,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                          ),

                          // 2. Nội dung chính
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Ảnh
                                if (imageBase64 != null &&
                                    imageBase64.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                        base64Decode(imageBase64),
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                                Icons.broken_image))),
                                  )
                                else if (imagePath != null &&
                                    imagePath.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(File(imagePath),
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                                Icons.image_not_supported))),
                                  )
                                else
                                  Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: const Icon(Icons.no_photography,
                                          color: Colors.grey)),

                                const SizedBox(width: 12),

                                // Thông tin chữ
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "📍 ${data['address'] ?? ''}, ${data['ward'] ?? ''}, ${data['district'] ?? ''}, ${data['city'] ?? ''}",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: textColor),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(data['content'] ?? "",
                                          style: TextStyle(
                                              fontSize: 13, color: textColor)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 3. Thanh hành động (Sửa/Xóa)
                          if (!isDone) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    // Truyền lang vào hàm _editReport
                                    onPressed: () => _editReport(
                                        context,
                                        docId,
                                        data['content'] ?? "",
                                        data['address'] ?? "",
                                        lang),
                                    icon: const Icon(Icons.edit,
                                        size: 18, color: Colors.blue),
                                    label: Text(lang.getText('edit'),
                                        style: const TextStyle(
                                            color: Colors.blue)),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    // Truyền lang vào hàm _deleteReport
                                    onPressed: () =>
                                        _deleteReport(context, docId, lang),
                                    icon: const Icon(Icons.delete,
                                        size: 18, color: Colors.red),
                                    label: Text(lang.getText('delete'),
                                        style: const TextStyle(
                                            color: Colors.red)),
                                  ),
                                ],
                              ),
                            )
                          ]
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}