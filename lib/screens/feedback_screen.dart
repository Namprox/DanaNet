import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _contentController = TextEditingController();
  int _rating = 5;
  bool _isSubmitting = false;

  Future<void> _submitFeedback() async {
    // Lấy Provider (listen: false vì đang ở trong hàm async)
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('enter_feedback_err'))));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String name = lang.getText('anonymous');

      // Lấy tên user nếu có
      if (user != null) {
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          name = userDoc['name'] ??
              user.email ??
              lang.getText('anonymous');
        }
      }

      // Lưu vào Firestore
      await FirebaseFirestore.instance.collection('feedbacks').add({
        'uid': user?.uid,
        'name': name,
        'email': user?.email,
        'content': _contentController.text.trim(),
        'rating': _rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.getText('feedback_success')),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${lang.getText('error')}: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe ngôn ngữ
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
          title: Text(lang.getText('feedback_title')),
          backgroundColor: Colors.green),
      body: GestureDetector(
        // 1. Bắt sự kiện chạm kể cả ở vùng trống trong suốt
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        // 2. Dùng SizedBox full màn hình để đảm bảo chạm đâu cũng trúng
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          // 3. Dùng SingleChildScrollView để cuộn được khi bàn phím hiện lên
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.getText('how_feel'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () {
                          setState(() => _rating = index + 1);
                        },
                      );
                    }),
                  ),
                  Center(
                      child: Text(lang.getText('rate_hint'),
                          style: const TextStyle(color: Colors.grey))),
                  const SizedBox(height: 30),
                  Text(lang.getText('feedback_content'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _contentController,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: lang.getText('feedback_hint_text'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(lang.getText('send_feedback_btn'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}