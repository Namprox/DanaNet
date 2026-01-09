import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../user_profile_screen.dart';
import '../report_screen.dart';
import '../history_screen.dart';
import '../forum/forum_screen.dart';
import '../feedback_screen.dart';
import '../redeem_points_screen.dart';
import '../about_app_screen.dart';

class UserDrawer extends StatelessWidget {
  const UserDrawer({super.key});

  // Hàm hiển thị Dialog đổi mật khẩu
  void _showChangePasswordDialog(BuildContext context, LanguageProvider lang) {
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
              title: Text(lang.getText('change_password')),
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
                          labelText: lang.getText('current_password'),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureCurrent
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () {
                              setState(() => obscureCurrent = !obscureCurrent);
                            },
                          ),
                        ),
                        validator: (val) => val!.isEmpty
                            ? lang.getText('enter_old_pass')
                            : null,
                      ),

                      // Nút Quên mật khẩu hiện tại
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            User? user = FirebaseAuth.instance.currentUser;
                            if (user != null &&
                                user.email != null &&
                                user.email!.isNotEmpty) {
                              try {
                                await FirebaseAuth.instance
                                    .sendPasswordResetEmail(email: user.email!);
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          "${lang.getText('email_sent')} ${user.email}"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Lỗi gửi email!"),
                                      backgroundColor: Colors.red),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "Tài khoản này không có email để reset mật khẩu!"),
                                    backgroundColor: Colors.red),
                              );
                            }
                          },
                          child: Text(lang.getText('forgot_password_q'),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.blue)),
                        ),
                      ),

                      const SizedBox(height: 5),

                      // 2. Mật khẩu mới
                      TextFormField(
                        controller: newPassController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: lang.getText('new_password'),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () {
                              setState(() => obscureNew = !obscureNew);
                            },
                          ),
                        ),
                        validator: (val) => val!.length < 6
                            ? lang.getText('pass_min_len')
                            : null,
                      ),
                      const SizedBox(height: 15),

                      // 3. Xác nhận mật khẩu mới
                      TextFormField(
                        controller: confirmPassController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: lang.getText('confirm_new_password'),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () {
                              setState(() => obscureConfirm = !obscureConfirm);
                            },
                          ),
                        ),
                        validator: (val) => val != newPassController.text
                            ? lang.getText('pass_not_match')
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(lang.getText('cancel'))),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        showDialog(
                            context: ctx,
                            barrierDismissible: false,
                            builder: (c) => const Center(
                                child: CircularProgressIndicator()));
                        User? user = FirebaseAuth.instance.currentUser;

                        String email = user?.email ?? "";
                        if (email.isEmpty) {
                          Navigator.pop(ctx);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  "Tài khoản SĐT không hỗ trợ đổi mật khẩu tại đây"),
                              backgroundColor: Colors.orange));
                          return;
                        }

                        AuthCredential credential =
                            EmailAuthProvider.credential(
                                email: email,
                                password: currentPassController.text);

                        await user!.reauthenticateWithCredential(credential);
                        await user.updatePassword(newPassController.text);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:
                                  Text(lang.getText('pass_change_success')),
                              backgroundColor: Colors.green));
                        }
                      } on FirebaseAuthException catch (e) {
                        Navigator.pop(ctx);
                        String errorMsg = lang.getText('error');
                        if (e.code == 'wrong-password')
                          errorMsg =
                              "Mật khẩu hiện tại không đúng"; // Có thể thêm key cho lỗi này
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(errorMsg),
                            backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: Text(lang.getText('save_changes')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<LanguageProvider>(context); // Gọi LanguageProvider
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          String name = "Người dùng";
          String displayInfo = "";

          if (currentUser != null) {
            if (currentUser.email != null && currentUser.email!.isNotEmpty) {
              displayInfo = currentUser.email!;
            } else if (currentUser.phoneNumber != null &&
                currentUser.phoneNumber!.isNotEmpty) {
              displayInfo = currentUser.phoneNumber!;
            }
          }

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            name = data['name'] ?? "Người dùng";
            String fsEmail = data['email'] ?? "";
            String fsPhone = data['phone'] ?? "";

            if (fsEmail.isNotEmpty) {
              displayInfo = fsEmail;
            } else if (fsPhone.isNotEmpty) {
              displayInfo = fsPhone;
            }
          }

          String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "U";

          return Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.green),
                accountName: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                accountEmail: Text(displayInfo),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(firstLetter,
                      style: const TextStyle(
                          fontSize: 40,
                          color: Colors.green,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_circle, color: Colors.teal),
                title: Text(lang.getText('profile')), // [MỚI]
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const UserProfileScreen()));
                },
              ),
              SwitchListTile(
                title: Text(lang.getText('dark_mode')), // [MỚI]
                secondary: Icon(
                    themeProvider.isDarkMode
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: Colors.orange),
                value: themeProvider.isDarkMode,
                onChanged: (value) => themeProvider.toggleTheme(value),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.feedback, color: Colors.blue),
                title: Text(lang.getText('report_trash')), // [MỚI]
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ReportScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.purple),
                title: Text(lang.getText('report_history')), // [MỚI]
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HistoryScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.forum, color: Colors.deepPurple),
                title: Text(lang.getText('forum')), // [MỚI]
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ForumScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.loyalty, color: Colors.green),
                title: Text(lang.getText('redeem_points')), // [MỚI]
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RedeemPointsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_rate, color: Colors.amber),
                title: Text(lang.getText('feedback')), // [MỚI]
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const FeedbackScreen()));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: Text(lang.getText('about_app')), // [MỚI]
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AboutAppScreen()),
                  );
                },
              ),
              if (currentUser?.email != null && currentUser!.email!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.orange),
                  title: Text(lang.getText('change_password')),
                  onTap: () {
                    Navigator.pop(context);
                    _showChangePasswordDialog(
                        context, lang); // Truyền lang vào dialog
                  },
                ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(lang.getText('logout'),
                    style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(lang.getText('logout_confirm_title')),
                      content: Text(lang.getText('logout_confirm_msg')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(lang.getText('cancel'))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await FirebaseAuth.instance.signOut();
                          },
                          child: Text(lang.getText('confirm')),
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