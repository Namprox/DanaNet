import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class AiScanSection extends StatelessWidget {
  final File? selectedImage;
  final bool isAnalyzing;
  final String result;
  final Function(ImageSource) onPickImage;

  const AiScanSection({
    super.key,
    required this.selectedImage,
    required this.isAnalyzing,
    required this.result,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    final lang = Provider.of<LanguageProvider>(context); // Gọi Provider

    return Column(
      children: [
        // Tiêu đề dùng lang
        Text(lang.getText('ai_scan_title'),
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 10),

        if (isAnalyzing)
          Container(
              height: 220,
              width: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15)),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    // Text loading
                    Text(lang.getText('sending_server'))
                  ]))
        else if (selectedImage != null)
          ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(selectedImage!,
                  height: 220, width: 220, fit: BoxFit.cover))
        else
          Container(
              height: 220,
              width: 220,
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300)),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.image_search,
                        size: 50, color: Colors.grey),
                    // [SỬA] Text hướng dẫn
                    Text(lang.getText('take_trash_photo'))
                  ])),
        const SizedBox(height: 15),

        // Biến result được truyền từ HomeScreen (nơi đã xử lý đa ngôn ngữ)
        Text(result,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: textColor)),

        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Nút Camera
            _buildCircleButton(Icons.camera_alt, lang.getText('camera'),
                () => onPickImage(ImageSource.camera), textColor),
            const SizedBox(width: 40),
            // Nút Thư viện
            _buildCircleButton(Icons.photo_library, lang.getText('gallery'),
                () => onPickImage(ImageSource.gallery), textColor)
          ],
        ),
      ],
    );
  }

  Widget _buildCircleButton(
      IconData icon, String label, VoidCallback onTap, Color textColor) {
    return Column(children: [
      InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: Icon(icon, color: Colors.white, size: 30))),
      const SizedBox(height: 8),
      Text(label,
          style: TextStyle(fontWeight: FontWeight.w500, color: textColor))
    ]);
  }
}