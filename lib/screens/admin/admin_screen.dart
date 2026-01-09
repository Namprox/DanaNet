import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import 'admin_drawer.dart';
import 'tabs/report_tab.dart';
import 'tabs/forum_reports_tab.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {

  // Hàm hiển thị Dialog đổi mật khẩu
  void _showChangePasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        // Biến trạng thái ẩn/hiện mật khẩu
        bool obscureCurrent = true;
        bool obscureNew = true;
        bool obscureConfirm = true;

        // Dùng StatefulBuilder để cập nhật giao diện bên trong Dialog
        return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text("Đổi Mật Khẩu Admin"),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
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
                            Navigator.pop(ctx);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đổi mật khẩu thành công!"), backgroundColor: Colors.green));
                          }
                        } on FirebaseAuthException catch (e) {
                          Navigator.pop(ctx);
                          String errorMsg = "Lỗi: ${e.message}";
                          if (e.code == 'wrong-password') errorMsg = "Mật khẩu hiện tại không đúng";
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
    final appBarColor = isDarkMode ? Colors.deepOrange.shade900 : Colors.orange.shade100;
    final titleColor = isDarkMode ? Colors.white : Colors.black;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        // Truyền hàm _showChangePasswordDialog vào Drawer
        drawer: AdminDrawer(onPasswordChange: _showChangePasswordDialog),

        appBar: AppBar(
          title: Text("Admin Dashboard", style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
          backgroundColor: appBarColor,
          iconTheme: IconThemeData(color: titleColor),
          bottom: TabBar(
            isScrollable: true,
            labelColor: isDarkMode ? Colors.white : Colors.deepOrange,
            unselectedLabelColor: isDarkMode ? Colors.white60 : Colors.grey,
            indicatorColor: isDarkMode ? Colors.orangeAccent : Colors.deepOrange,
            tabs: const [
              Tab(icon: Icon(Icons.hourglass_empty), text: "Chờ xử lý"),
              Tab(icon: Icon(Icons.check_circle), text: "Đã thu gom"),
              Tab(icon: Icon(Icons.flag), text: "Báo cáo xấu"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ReportListTab(statusFilter: 'pending'),
            ReportListTab(statusFilter: 'done'),
            ForumReportsTab(),
          ],
        ),
      ),
    );
  }
}