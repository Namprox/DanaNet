import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import 'tabs/forum_reports_tab.dart';
import 'rewards/admin_rewards_screen.dart';

// Widget giữ chỗ cho các chức năng chưa có logic
class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Chức năng đang phát triển...", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class AdminWebScreen extends StatefulWidget {
  const AdminWebScreen({super.key});

  @override
  State<AdminWebScreen> createState() => _AdminWebScreenState();
}

class _AdminWebScreenState extends State<AdminWebScreen> {
  int _selectedIndex = 0;

  // Danh sách các màn hình
  final List<Widget> _pages = [
    const _PlaceholderPage(title: "Thông tin cá nhân", icon: Icons.person),
    const _PlaceholderPage(title: "Duyệt hồ sơ KYC", icon: Icons.verified_user),
    const _PlaceholderPage(title: "Quản lý tài khoản", icon: Icons.manage_accounts),
    const AdminRewardsScreen(),
    const _PlaceholderPage(title: "Thống kê báo cáo", icon: Icons.bar_chart),
    const ForumReportsTab(),
    const _PlaceholderPage(title: "Xem đánh giá", icon: Icons.star),
  ];

  final List<String> _titles = [
    "Thông tin cá nhân",
    "Duyệt hồ sơ KYC",
    "Quản lý tài khoản",
    "Quản lý Tích điểm & Quà"
    "Thống kê báo cáo",
    "Quản lý diễn đàn",
    "Xem đánh giá",
  ];

  // Hàm đổi mật khẩu
  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        bool obscureCurrent = true;
        bool obscureNew = true;
        bool obscureConfirm = true;

        return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text("Đổi Mật Khẩu Admin"),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: 400,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Mật khẩu hiện tại
                          TextFormField(
                            controller: currentPassController,
                            obscureText: obscureCurrent,
                            decoration: InputDecoration(
                              labelText: "Mật khẩu hiện tại",
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                                onPressed: () {
                                  setState(() => obscureCurrent = !obscureCurrent);
                                },
                              ),
                            ),
                            validator: (val) => val!.isEmpty ? "Nhập mật khẩu hiện tại" : null,
                          ),

                          // Nút Quên mật khẩu
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () async {
                                User? user = FirebaseAuth.instance.currentUser;
                                if (user != null && user.email != null) {
                                  try {
                                    await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Đã gửi email reset pass tới: ${user.email}"), backgroundColor: Colors.green),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi gửi email!"), backgroundColor: Colors.red));
                                  }
                                }
                              },
                              child: const Text("Quên mật khẩu hiện tại?", style: TextStyle(fontSize: 12, color: Colors.deepOrange)),
                            ),
                          ),

                          const SizedBox(height: 5),

                          // 2. Mật khẩu mới
                          TextFormField(
                            controller: newPassController,
                            obscureText: obscureNew,
                            decoration: InputDecoration(
                              labelText: "Mật khẩu mới",
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                                onPressed: () {
                                  setState(() => obscureNew = !obscureNew);
                                },
                              ),
                            ),
                            validator: (val) => val!.length < 6 ? "Mật khẩu mới > 6 ký tự" : null,
                          ),
                          const SizedBox(height: 10),

                          // 3. Xác nhận mật khẩu mới
                          TextFormField(
                            controller: confirmPassController,
                            obscureText: obscureConfirm,
                            decoration: InputDecoration(
                              labelText: "Xác nhận mật khẩu mới",
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                onPressed: () {
                                  setState(() => obscureConfirm = !obscureConfirm);
                                },
                              ),
                            ),
                            validator: (val) => val != newPassController.text ? "Mật khẩu không khớp" : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        try {
                          showDialog(context: ctx, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
                          User? user = FirebaseAuth.instance.currentUser;
                          AuthCredential credential = EmailAuthProvider.credential(email: user?.email ?? "", password: currentPassController.text);

                          // Xác thực lại
                          await user!.reauthenticateWithCredential(credential);
                          // Đổi mật khẩu
                          await user.updatePassword(newPassController.text);

                          if (mounted) {
                            Navigator.pop(ctx); // Tắt loading
                            Navigator.pop(ctx); // Tắt dialog form
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đổi mật khẩu thành công!"), backgroundColor: Colors.green));
                          }
                        } on FirebaseAuthException catch (e) {
                          Navigator.pop(ctx); // Tắt loading
                          String errorMsg = "Lỗi: ${e.message}";
                          if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                            errorMsg = "Mật khẩu hiện tại không đúng";
                          }
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
                        }
                      }
                    },
                    child: const Text("Lưu thay đổi"),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            color: isDarkMode ? Colors.grey[900] : Colors.blueGrey[900],
            child: Column(
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1)),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.orange,
                            child: Text("A", style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))
                        ),
                        const SizedBox(height: 10),
                        const Text("Admin Web", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(FirebaseAuth.instance.currentUser?.email ?? "admin@dananet.vn",
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildNavItem(0, "Thông tin cá nhân", Icons.person),
                      _buildNavItem(1, "Duyệt hồ sơ KYC", Icons.verified_user),

                      const Divider(color: Colors.white24),

                      SwitchListTile(
                        title: const Text("Chế độ tối", style: TextStyle(color: Colors.white70)),
                        secondary: Icon(isDarkMode ? Icons.nightlight_round : Icons.wb_sunny, color: Colors.orangeAccent),
                        value: isDarkMode,
                        activeColor: Colors.greenAccent,
                        onChanged: (val) => themeProvider.toggleTheme(val),
                      ),

                      const Divider(color: Colors.white24),

                      _buildNavItem(2, "Quản lý tài khoản", Icons.manage_accounts),
                      _buildNavItem(3, "Quản lý Tích điểm & Quà", Icons.card_giftcard),
                      _buildNavItem(4, "Thống kê báo cáo", Icons.bar_chart),
                      _buildNavItem(5, "Quản lý diễn đàn", Icons.forum),
                      _buildNavItem(6, "Xem đánh giá", Icons.star),

                      const Divider(color: Colors.white24),

                      ListTile(
                        leading: const Icon(Icons.lock_reset, color: Colors.orangeAccent),
                        title: const Text("Đổi mật khẩu", style: TextStyle(color: Colors.white70)),
                        onTap: _showChangePasswordDialog, // Gọi hàm ở đây
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.redAccent),
                        title: const Text("Đăng xuất", style: TextStyle(color: Colors.redAccent)),
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Nội dung chính
          Expanded(
            child: Container(
              color: isDarkMode ? Colors.black : Colors.grey[100],
              child: Column(
                children: [
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.centerLeft,
                    color: isDarkMode ? Colors.grey[850] : Colors.white,
                    child: Text(
                      _titles[_selectedIndex],
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: _pages[_selectedIndex],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    bool isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.greenAccent : Colors.white70),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.greenAccent : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      tileColor: isSelected ? Colors.white.withOpacity(0.1) : null,
      onTap: () => setState(() => _selectedIndex = index),
    );
  }
}