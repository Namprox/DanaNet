import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForumReportsTab extends StatelessWidget {
  const ForumReportsTab({super.key});

  // Hàm xử lý: Xóa bài viết bị báo cáo
  Future<void> _deletePostAndResolve(
      BuildContext context, String reportId, String postId) async {
    try {
      await FirebaseFirestore.instance
          .collection('scrap_posts')
          .doc(postId)
          .delete();
      await FirebaseFirestore.instance
          .collection('forum_reports')
          .doc(reportId)
          .update({
        'status': 'resolved',
        'resolution': 'deleted_post',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Đã xóa bài viết vi phạm!"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    }
  }

  // Hàm xử lý: Bỏ qua báo cáo
  Future<void> _ignoreReport(BuildContext context, String reportId) async {
    try {
      await FirebaseFirestore.instance
          .collection('forum_reports')
          .doc(reportId)
          .update({'status': 'ignored'});
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đã bỏ qua báo cáo này")));
    } catch (e) {}
  }

  // Hàm format thời gian
  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return "Vừa xong";
    DateTime d = timestamp.toDate();
    return "${d.day}/${d.month}/${d.year} - ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('forum_reports')
            .where('status', isEqualTo: 'pending')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.check_circle_outline,
                      size: 60,
                      color: isDarkMode ? Colors.greenAccent : Colors.green),
                  const SizedBox(height: 10),
                  const Text("Không có báo cáo vi phạm nào!")
                ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var report = snapshot.data!.docs[index];
              var reportData = report.data() as Map<String, dynamic>;

              String postId = reportData['postId'] ?? "";
              String reporterId = reportData['reporterId'] ??
                  reportData['userId'] ??
                  reportData['uid'] ??
                  "";

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                color:
                    isDarkMode ? const Color(0xFF1E1E1E) : Colors.red.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red.shade300, width: 1)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header báo cáo
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  "BÁO CÁO: ${reportData['reason']?.toUpperCase() ?? 'KHÔNG RÕ'}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      fontSize: 15))),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 32, bottom: 8),
                        child: Text(
                            "Chi tiết: ${reportData['detail'] ?? 'Không có mô tả'}",
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54)),
                      ),

                      if (reporterId.isNotEmpty)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(reporterId)
                              .get(),
                          builder: (context, userSnapshot) {
                            String reporterName = "Đang tải...";
                            String reporterEmail = "";
                            if (userSnapshot.hasData &&
                                userSnapshot.data!.exists) {
                              var userData = userSnapshot.data!.data()
                                  as Map<String, dynamic>;
                              reporterName = userData['name'] ?? "Người dùng";
                              reporterEmail = userData['email'] ?? "";
                            }
                            return Container(
                              margin:
                                  const EdgeInsets.only(left: 32, bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.black26
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.grey.withOpacity(0.2))),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_search,
                                      size: 20, color: Colors.blueAccent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text("Người báo cáo:",
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: isDarkMode
                                                    ? Colors.white54
                                                    : Colors.grey[700])),
                                        Text(reporterName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Colors.blueAccent)),
                                        if (reporterEmail.isNotEmpty)
                                          Text(reporterEmail,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDarkMode
                                                      ? Colors.white70
                                                      : Colors.black87,
                                                  fontStyle: FontStyle.italic)),
                                      ])),
                                ],
                              ),
                            );
                          },
                        ),

                      const Divider(color: Colors.redAccent),
                      const Text("NỘI DUNG BÀI VIẾT:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey)),
                      const SizedBox(height: 8),

                      // Nội dung bài viết
                      if (postId.isNotEmpty)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('scrap_posts')
                              .doc(postId)
                              .get(),
                          builder: (context, postSnapshot) {
                            if (postSnapshot.connectionState ==
                                ConnectionState.waiting)
                              return const Center(
                                  child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)));
                            if (!postSnapshot.hasData ||
                                !postSnapshot.data!.exists) {
                              return Container(
                                  padding: const EdgeInsets.all(12),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Text(
                                      "Bài viết này đã bị xóa khỏi hệ thống",
                                      style: TextStyle(
                                          fontStyle: FontStyle.italic)));
                            }
                            var postData = postSnapshot.data!.data()
                                as Map<String, dynamic>;

                            // Lấy thông tin
                            String phone = postData['phone'] ?? "";
                            String address = postData['address'] ?? "";
                            String role = postData['role'] == 'seller'
                                ? "Cần Bán"
                                : "Cần Mua";
                            Color roleColor = postData['role'] == 'seller'
                                ? Colors.green
                                : Colors.blue;

                            // Kiểm tra trạng thái đã hoàn thành
                            bool isCompleted =
                                postData['status'] == 'completed';

                            String timeString =
                                _formatDateTime(postData['timestamp']);

                            return Container(
                              decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.black38
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.grey.withOpacity(0.3))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header: Avatar + Tên + Email + Role + Date
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    leading: CircleAvatar(
                                        backgroundColor: roleColor,
                                        radius: 16,
                                        child: Text(
                                            (postData['userName'] ?? "?")[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14))),
                                    title: Text(
                                        postData['userName'] ?? "Ẩn danh",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (postData['userEmail'] != null)
                                            Text(postData['userEmail'],
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDarkMode
                                                        ? Colors.white60
                                                        : Colors.black54)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: roleColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4)),
                                                child: Text(role,
                                                    style: TextStyle(
                                                        color: roleColor,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(timeString,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDarkMode
                                                          ? Colors.white54
                                                          : Colors.grey)),
                                            ],
                                          )
                                        ]),
                                  ),

                                  // Content
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(postData['title'] ?? "",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    // Gạch ngang nếu đã giao dịch
                                                    decoration: isCompleted
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                                    decorationColor:
                                                        Colors.red)),
                                            const SizedBox(height: 4),
                                            Text(postData['content'] ?? "",
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    color: isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black87)),
                                          ])),

                                  // Image
                                  if (postData['imageBase64'] != null)
                                    GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => Dialog(
                                            backgroundColor: Colors.transparent,
                                            insetPadding: EdgeInsets.zero,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                InteractiveViewer(
                                                  child: Image.memory(
                                                    base64Decode(postData[
                                                        'imageBase64']),
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 20,
                                                  right: 20,
                                                  child: IconButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    icon: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 30),
                                                    style: IconButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.black45),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.all(12),
                                        height: 200,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.black12,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color:
                                                  Colors.grey.withOpacity(0.3)),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(
                                                base64Decode(
                                                    postData['imageBase64']),
                                                fit: BoxFit.contain,
                                                width: double.infinity,
                                                // [MỚI] Làm mờ ảnh nếu đã giao dịch
                                                color: isCompleted
                                                    ? Colors.white
                                                        .withOpacity(0.4)
                                                    : null,
                                                colorBlendMode: isCompleted
                                                    ? BlendMode.modulate
                                                    : null,
                                                errorBuilder: (c, e, s) =>
                                                    const Center(
                                                        child: Icon(
                                                            Icons.broken_image,
                                                            color: Colors.grey,
                                                            size: 40)),
                                              ),
                                            ),

                                            // Con dấu ĐÃ GIAO DỊCH trên ảnh
                                            if (isCompleted)
                                              Transform.rotate(
                                                angle: -0.2,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: Colors.red,
                                                          width: 3),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      color: Colors.white
                                                          .withOpacity(0.2)),
                                                  child: const Text(
                                                    "ĐÃ GIAO DỊCH",
                                                    style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 2),
                                                  ),
                                                ),
                                              )
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Contact Info
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.black26
                                          : Colors.grey.shade100,
                                      borderRadius: const BorderRadius.vertical(
                                          bottom: Radius.circular(8)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (phone.isNotEmpty)
                                          Row(children: [
                                            const Icon(Icons.phone,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Text(phone,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black87)),
                                          ]),
                                        if (address.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.location_on,
                                                  size: 14, color: Colors.grey),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: Text(address,
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: isDarkMode
                                                              ? Colors.white70
                                                              : Colors
                                                                  .black87))),
                                            ],
                                          ),
                                        ]
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 16),
                      // Buttons
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                            onPressed: () => _ignoreReport(context, report.id),
                            child: Text("Bỏ qua",
                                style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.grey.shade400
                                        : Colors.grey))),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8))),
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text("Xóa bài vi phạm"),
                            onPressed: () => _deletePostAndResolve(
                                context, report.id, postId)),
                      ])
                    ],
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