import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserStat {
  final String uid;
  String name;
  String email;
  int pendingCount;
  int doneCount;

  UserStat({
    required this.uid,
    required this.name,
    required this.email,
    this.pendingCount = 0,
    this.doneCount = 0
  });

  int get total => pendingCount + doneCount;
}

class StatisticsTab extends StatelessWidget {
  const StatisticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Chưa có dữ liệu thống kê"));

        // Tổng hợp dữ liệu
        Map<String, UserStat> statsMap = {};
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String uid = data['uid'] ?? 'unknown';
          String name = data['name'] ?? data['username'] ?? 'Người dùng ẩn danh';
          String email = data['email'] ?? 'Không có email';
          String status = data['status'] ?? 'pending';

          if (!statsMap.containsKey(uid)) {
            // Lưu cả uid vào object
            statsMap[uid] = UserStat(uid: uid, name: name, email: email);
          }

          if (status == 'done') {
            statsMap[uid]!.doneCount++;
          } else {
            statsMap[uid]!.pendingCount++;
          }
        }

        List<UserStat> statsList = statsMap.values.toList();
        // Sắp xếp theo tổng số lượng giảm dần
        statsList.sort((a, b) => b.total.compareTo(a.total));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: statsList.length,
          itemBuilder: (context, index) {
            final stat = statsList[index];
            String firstLetter = stat.name.isNotEmpty ? stat.name[0].toUpperCase() : "";

            return Card(
              color: cardColor,
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isDarkMode ? BorderSide(color: Colors.grey.shade700) : BorderSide.none),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: Colors.blueAccent, child: Text(firstLetter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hiển thị Tên + Tích xanh Verified
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      stat.name,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Logic kiểm tra KYC
                                  if (stat.uid != 'unknown')
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance.collection('users').doc(stat.uid).snapshots(),
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

                              Text(stat.email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)), child: Text("Tổng: ${stat.total}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))
                      ],
                    ),
                    const Divider(height: 20),
                    Row(children: [
                      Expanded(child: _buildStatItem("Chưa xử lý", stat.pendingCount, Colors.orange, isDarkMode)),
                      Container(width: 1, height: 40, color: Colors.grey.shade300),
                      Expanded(child: _buildStatItem("Đã thu gom", stat.doneCount, Colors.green, isDarkMode)),
                    ])
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String label, int count, Color color, bool isDark) {
    return Column(children: [
      Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700)),
    ]);
  }
}