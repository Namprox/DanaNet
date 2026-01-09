import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AdminAccountScreen extends StatefulWidget {
  const AdminAccountScreen({super.key});

  @override
  State<AdminAccountScreen> createState() => _AdminAccountScreenState();
}

class _AdminAccountScreenState extends State<AdminAccountScreen> {

  // Hàm format ngày tháng
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "---";
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  // 1. Hộp thoại xem chi tiết
  void _showUserDetail(BuildContext context, Map<String, dynamic> data, String docId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Lấy dữ liệu an toàn
    String name = data['name'] ?? "Không tên";
    String email = data['email'] ?? "---";
    String phone = data['phone'] ?? "---";
    String role = data['role'] ?? "user";
    String kycStatus = data['kycStatus'] ?? "none";
    int waterDrops = data['waterDrops'] ?? 0;

    // Xử lý địa chỉ chi tiết
    String fullAddress = data['address'] ?? "";
    List<String> addressParts = [];
    if (data['streetAddress'] != null && data['streetAddress'].toString().isNotEmpty) addressParts.add(data['streetAddress']);
    if (data['ward'] != null && data['ward'].toString().isNotEmpty) addressParts.add(data['ward']);
    if (data['district'] != null && data['district'].toString().isNotEmpty) addressParts.add(data['district']);
    if (data['city'] != null && data['city'].toString().isNotEmpty) addressParts.add(data['city']);

    String detailedAddress = addressParts.isNotEmpty ? addressParts.join(", ") : fullAddress;
    if (detailedAddress.isEmpty) detailedAddress = "Chưa cập nhật";

    String? frontBase64 = data['kycFront'];
    String? backBase64 = data['kycBack'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDarkMode ? BorderSide(color: Colors.grey.shade700, width: 1) : BorderSide.none,
        ),
        title: Row(
          children: [
            const Icon(Icons.account_circle, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDarkMode ? Colors.white : Colors.black))),
            IconButton(icon: Icon(Icons.close, color: isDarkMode ? Colors.grey : Colors.black54), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: Vai trò & Điểm
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildRoleBadge(role),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.water_drop, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text("$waterDrops giọt", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),

                // Thông tin liên hệ
                _buildDetailRow(Icons.email, "Email", email, isDarkMode),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.phone, "SĐT", phone, isDarkMode),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.calendar_month, "Ngày tạo", _formatDate(data['createdAt']), isDarkMode),

                const Divider(height: 24),

                // Địa chỉ
                Text("📍 Địa chỉ:", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                const SizedBox(height: 4),
                Text(detailedAddress, style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[800], fontSize: 14, height: 1.4)),

                const Divider(height: 24),

                // KYC
                Row(
                  children: [
                    Text("Trạng thái KYC: ", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                    if (kycStatus == 'verified')
                      const Chip(label: Text("Đã xác thực", style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Colors.blue, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero)
                    else if (kycStatus == 'pending')
                      const Chip(label: Text("Chờ duyệt", style: TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Colors.orange, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero)
                    else
                      Text("Chưa xác thực", style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey, fontStyle: FontStyle.italic)),
                  ],
                ),

                if (frontBase64 != null && frontBase64.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text("Ảnh giấy tờ:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkMode ? Colors.white : Colors.black)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildImagePreview(frontBase64, "Mặt trước", isDarkMode)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildImagePreview(backBase64, "Mặt sau", isDarkMode)),
                    ],
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget hiển thị dòng thông tin
  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Text("$label: ", style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.grey[300] : Colors.black87)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            softWrap: true,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(String? base64String, String label, bool isDark) {
    if (base64String == null || base64String.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade600), borderRadius: BorderRadius.circular(8)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(base64Decode(base64String), fit: BoxFit.cover, errorBuilder: (c,e,s) => const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // 2. Hộp thoại Tạo mới/Cập nhật
  void _showAccountDialog({String? docId, Map<String, dynamic>? currentData}) {
    String currentEmail = currentData?['email'] ?? '';
    String currentPhone = currentData?['phone'] ?? '';
    String currentName = currentData?['name'] ?? '';
    String currentRole = currentData?['role'] ?? 'user';

    bool isEditing = docId != null;
    bool isPhoneAccount = isEditing && currentPhone.isNotEmpty && currentEmail.isEmpty;

    final nameController = TextEditingController(text: currentName);
    final emailController = TextEditingController(text: currentEmail);
    final phoneController = TextEditingController(text: currentPhone);
    final passwordController = TextEditingController();

    String selectedRole = currentRole;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? "Cập nhật tài khoản" : "Thêm tài khoản mới"),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Họ tên", prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.isEmpty ? "Nhập tên" : null,
                ),
                const SizedBox(height: 10),

                if (isPhoneAccount)
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: "Số điện thoại", prefixIcon: Icon(Icons.phone)),
                    enabled: false,
                  )
                else
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)),
                    enabled: !isEditing,
                    validator: (v) => v!.isEmpty ? "Nhập email" : null,
                  ),

                if (!isEditing) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Mật khẩu", prefixIcon: Icon(Icons.lock)),
                    validator: (v) => v!.length < 6 ? "Mật khẩu > 6 ký tự" : null,
                  ),
                ],

                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: "Vai trò", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text("Người dùng (User)")),
                    DropdownMenuItem(value: 'admin', child: Text("Quản trị viên (Admin)")),
                  ],
                  onChanged: (val) => selectedRole = val!,
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
                  showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

                  if (isEditing) {
                    await FirebaseFirestore.instance.collection('users').doc(docId).update({
                      'name': nameController.text.trim(),
                      'role': selectedRole,
                    });
                  } else {
                    FirebaseApp tempApp = await Firebase.initializeApp(name: 'temporaryRegister', options: Firebase.app().options);
                    try {
                      UserCredential cred = await FirebaseAuth.instanceFor(app: tempApp).createUserWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim()
                      );
                      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
                        'name': nameController.text.trim(),
                        'email': emailController.text.trim(),
                        'role': selectedRole,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      await tempApp.delete();
                    } catch (e) {
                      await tempApp.delete();
                      rethrow;
                    }
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thành công!"), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                }
              }
            },
            child: Text(isEditing ? "Cập nhật" : "Tạo mới"),
          ),
        ],
      ),
    );
  }

  void _deleteUser(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa tài khoản?"),
        content: const Text("Bạn có chắc chắn muốn xóa người dùng này?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(docId).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Xóa"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : Colors.grey.shade100;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Quản Lý Tài Khoản", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDarkMode ? Colors.green.shade900 : Colors.green,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("Chưa có tài khoản nào", style: TextStyle(color: secondaryTextColor)));
          }

          final users = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: users.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var userDoc = users[index];
              var data = userDoc.data() as Map<String, dynamic>;
              String role = data['role'] ?? 'user';
              String name = data['name'] ?? 'Không tên';
              String kycStatus = data['kycStatus'] ?? 'none';
              String email = data['email'] ?? "";
              String phone = data['phone'] ?? "";
              String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "?";
              bool isAdmin = role == 'admin';

              String contactInfo = "Chưa cập nhật";
              IconData contactIcon = Icons.help_outline;

              if (email.isNotEmpty) {
                contactInfo = email;
                contactIcon = Icons.email_outlined;
              } else if (phone.isNotEmpty) {
                contactInfo = phone;
                contactIcon = Icons.phone_android;
              }

              return Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    // Bấm vào để xem chi tiết
                    onTap: () => _showUserDetail(context, data, userDoc.id),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: isAdmin ? Colors.orange.shade100 : Colors.blue.shade100,
                                child: Text(firstLetter, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isAdmin ? Colors.deepOrange : Colors.blue.shade800)),
                              ),
                              if (kycStatus == 'verified')
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: cardColor, width: 2)),
                                    child: const Icon(Icons.check_circle, color: Colors.blue, size: 16),
                                  ),
                                )
                              else if (kycStatus == 'pending')
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: cardColor, width: 2)),
                                    child: const Icon(Icons.access_time_filled, color: Colors.orange, size: 16),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(child: Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor), overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 8),
                                    _buildRoleBadge(role),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(contactIcon, size: 14, color: secondaryTextColor),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(contactInfo, style: TextStyle(fontSize: 13, color: secondaryTextColor), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: secondaryTextColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) {
                              if (value == 'view') _showUserDetail(context, data, userDoc.id);
                              else if (value == 'edit') _showAccountDialog(docId: userDoc.id, currentData: data);
                              else if (value == 'delete') _deleteUser(userDoc.id);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 10), Text("Chỉnh sửa")])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 10), Text("Xóa")])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    bool isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAdmin ? Colors.orange.shade300 : Colors.green.shade300, width: 0.5),
      ),
      child: Text(isAdmin ? "ADMIN" : "USER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isAdmin ? Colors.deepOrange : Colors.green.shade700, letterSpacing: 0.5)),
    );
  }
}