import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import 'admin_account_screen.dart';
import 'tabs/statistics_tab.dart';
import 'tabs/feedback_tab.dart';
import 'tabs/forum_tab.dart';
import '../user_profile_screen.dart';
import 'tabs/kyc_approval_tab.dart';
import 'rewards/admin_rewards_screen.dart';

class AdminDrawer extends StatelessWidget {
  final VoidCallback onPasswordChange;

  const AdminDrawer({super.key, required this.onPasswordChange});

  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          String name = "Đang tải...";
          String email = currentUser?.email ?? "";
          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            name = data['name'] ?? "Admin";
          }
          String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "A";

          return Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.deepOrange),
                accountName: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                accountEmail: Text(email),
                currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(firstLetter,
                        style: const TextStyle(
                            fontSize: 40,
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold))),
              ),
              ListTile(
                leading: const Icon(Icons.account_circle, color: Colors.teal),
                title: const Text("Thông tin cá nhân"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UserProfileScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.verified_user, color: Colors.green),
                title: const Text("Duyệt hồ sơ KYC"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Scaffold(
                                appBar: AppBar(
                                    title: const Text("Duyệt Hồ Sơ KYC"),
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white),
                                body: const KycApprovalTab(),
                              )));
                },
              ),
              SwitchListTile(
                title: const Text("Chế độ tối (Dark Mode)"),
                secondary: Icon(
                    themeProvider.isDarkMode
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: Colors.orange),
                value: themeProvider.isDarkMode,
                onChanged: (value) =>
                    Provider.of<ThemeProvider>(context, listen: false)
                        .toggleTheme(value),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.manage_accounts, color: Colors.blue),
                title: const Text("Quản lý tài khoản"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminAccountScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard, color: Colors.pink),
                title: const Text("Quản lý Tích điểm & Quà"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Scaffold(
                                appBar: AppBar(
                                    title: const Text("Quản Lý Tích Điểm"),
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white),
                                body: const AdminRewardsScreen(),
                              )));
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart, color: Colors.purple),
                title: const Text("Thống kê báo cáo"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Scaffold(
                                appBar: AppBar(
                                    title: const Text("Thống Kê"),
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white),
                                body: const StatisticsTab(),
                              )));
                },
              ),
              ListTile(
                leading: const Icon(Icons.forum, color: Colors.teal),
                title: const Text("Quản lý diễn đàn"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Scaffold(
                                appBar: AppBar(
                                    title: const Text("Quản Lý Diễn Đàn"),
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white),
                                body: const ForumManagementTab(),
                              )));
                },
              ),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text("Xem đánh giá"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Scaffold(
                                appBar: AppBar(
                                    title: const Text("Đánh Giá Người Dùng"),
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.white),
                                body: const FeedbackListTab(),
                              )));
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset, color: Colors.orange),
                title: const Text("Đổi mật khẩu"),
                onTap: () {
                  Navigator.pop(context);
                  onPasswordChange();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Đăng xuất",
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Đăng xuất"),
                      content: const Text(
                          "Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Hủy"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await FirebaseAuth.instance.signOut();
                          },
                          child: const Text("Đồng ý"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
