import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class RewardsManagementTab extends StatefulWidget {
  const RewardsManagementTab({super.key});

  @override
  State<RewardsManagementTab> createState() => _RewardsManagementTabState();
}

class _RewardsManagementTabState extends State<RewardsManagementTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
        onPressed: () => _showRewardDialog(context, null),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rewards').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty)
            return const Center(child: Text("Kho quà trống"));

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: _buildRewardImage(data['imageUrl']),
                  title: Text(data['title'] ?? "Quà tặng",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${data['pointsRequired']} điểm"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: "Sửa",
                        onPressed: () => _showRewardDialog(context, doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: "Xóa",
                        onPressed: () async {
                          if (await _confirmDialog("Xóa quà này?")) {
                            FirebaseFirestore.instance
                                .collection('rewards')
                                .doc(doc.id)
                                .delete();
                          }
                        },
                      ),
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

  Widget _buildRewardImage(dynamic imageSource) {
    if (imageSource == null || imageSource.toString().isEmpty) {
      return const Icon(Icons.card_giftcard, color: Colors.purple);
    }
    String src = imageSource.toString();
    if (src.startsWith('http')) {
      return Image.network(src,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const Icon(Icons.card_giftcard));
    } else {
      try {
        return Image.memory(base64Decode(src),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => const Icon(Icons.card_giftcard));
      } catch (e) {
        return const Icon(Icons.card_giftcard);
      }
    }
  }

  Future<bool> _confirmDialog(String msg) async {
    return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Xác nhận"),
            content: Text(msg),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Không")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Có")),
            ],
          ),
        ) ??
        false;
  }

  void _showRewardDialog(BuildContext context, DocumentSnapshot? doc) {
    Map<String, dynamic>? data;
    if (doc != null) {
      data = doc.data() as Map<String, dynamic>;
    }

    final titleController = TextEditingController(text: data?['title']);
    final pointsController =
        TextEditingController(text: data?['pointsRequired']?.toString());
    final descController = TextEditingController(text: data?['description']);
    final imageLinkController = TextEditingController(text: data?['imageUrl']);

    String? selectedImageBase64;
    File? selectedImageFile;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> _pickImage() async {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 800,
              maxHeight: 800,
              imageQuality: 50,
            );

            if (pickedFile != null) {
              final bytes = await pickedFile.readAsBytes();
              setState(() {
                selectedImageBase64 = base64Encode(bytes);
                selectedImageFile = File(pickedFile.path);
                imageLinkController.clear();
              });
            }
          }

          return AlertDialog(
            title: Text(doc == null ? "Thêm Quà Mới" : "Cập Nhật Quà"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: "Tên quà")),
                  TextField(
                      controller: pointsController,
                      decoration:
                          const InputDecoration(labelText: "Điểm cần đổi"),
                      keyboardType: TextInputType.number),
                  TextField(
                      controller: descController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: "Mô tả")),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imageLinkController,
                          decoration: const InputDecoration(
                              labelText: "Link ảnh (URL)"),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              setState(() {
                                selectedImageBase64 = null;
                                selectedImageFile = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text("Hoặc",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image, color: Colors.blue),
                        tooltip: "Chọn ảnh từ thư viện",
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (selectedImageFile != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Image.file(selectedImageFile!,
                            height: 100, width: 100, fit: BoxFit.cover),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              selectedImageFile = null;
                              selectedImageBase64 = null;
                              if (doc != null) {
                                imageLinkController.text =
                                    data?['imageUrl'] ?? "";
                              }
                            });
                          },
                        )
                      ],
                    )
                  else if (imageLinkController.text.isNotEmpty)
                    (imageLinkController.text.startsWith('http')
                        ? Image.network(
                            imageLinkController.text,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) =>
                                const Text("Lỗi ảnh URL"),
                          )
                        : Image.memory(
                            base64Decode(imageLinkController.text),
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const SizedBox(),
                          )),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Hủy")),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty &&
                      pointsController.text.isNotEmpty) {
                    String? finalImage =
                        selectedImageBase64 ?? imageLinkController.text;
                    if (finalImage.isEmpty) finalImage = null;

                    Map<String, dynamic> saveData = {
                      'title': titleController.text,
                      'pointsRequired': int.parse(pointsController.text),
                      'description': descController.text,
                      'imageUrl': finalImage,
                      'lastUpdated': FieldValue.serverTimestamp(),
                    };

                    if (doc == null) {
                      saveData['createdAt'] = FieldValue.serverTimestamp();
                      FirebaseFirestore.instance
                          .collection('rewards')
                          .add(saveData);
                    } else {
                      FirebaseFirestore.instance
                          .collection('rewards')
                          .doc(doc.id)
                          .update(saveData);
                    }
                    Navigator.pop(ctx);
                  }
                },
                child: Text(doc == null ? "Lưu" : "Cập nhật"),
              )
            ],
          );
        },
      ),
    );
  }
}