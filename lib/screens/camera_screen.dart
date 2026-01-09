import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class CameraOverlayScreen extends StatefulWidget {
  const CameraOverlayScreen({super.key});

  @override
  State<CameraOverlayScreen> createState() => _CameraOverlayScreenState();
}

class _CameraOverlayScreenState extends State<CameraOverlayScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  List<CameraDescription> cameras = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  // Khởi tạo camera
  Future<void> _initCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          // Lấy Provider (listen: false) để lấy text lỗi
          final lang = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(lang.getText('camera_not_found'))));
          Navigator.pop(context);
        }
        return;
      }

      // Chọn camera sau
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print("Lỗi khởi tạo camera: $e");
      if (mounted) {
        final lang =
            Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${lang.getText('camera_error')}: $e")));
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe ngôn ngữ
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      // Nút back
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Text(lang.getText('capture_id_card'),
            style: const TextStyle(color: Colors.white)),
      ),
      extendBodyBehindAppBar: true,
      body: _controller == null || _initializeControllerFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Lớp 1: Preview Camera
                      SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: CameraPreview(_controller!)),

                      // Lớp 2: Khung Overlay mờ
                      _buildOverlayMask(),

                      // Lớp 3: Khung viền xanh lá
                      Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: MediaQuery.of(context).size.width * 0.85 * 0.63,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green, width: 3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      // Lớp 4: Hướng dẫn text
                      Positioned(
                          top: MediaQuery.of(context).padding.top +
                              kToolbarHeight +
                              20,
                          child: Text(lang.getText('place_id_card'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  shadows: [
                                    Shadow(
                                        blurRadius: 10,
                                        color: Colors.black,
                                        offset: Offset(1, 1))
                                  ]))),

                      // Lớp 5: Nút chụp ảnh
                      Positioned(
                        bottom: 40,
                        child: FloatingActionButton(
                          backgroundColor: Colors.white,
                          onPressed: () async {
                            try {
                              await _initializeControllerFuture;
                              final image = await _controller!.takePicture();
                              if (!mounted) return;
                              Navigator.pop(context, image.path);
                            } catch (e) {
                              print("Lỗi khi chụp: $e");
                            }
                          },
                          child: const Icon(Icons.camera_alt,
                              color: Colors.black, size: 30),
                        ),
                      ),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          "${lang.getText('camera_error')}: ${snapshot.error}",
                          style:
                              const TextStyle(color: Colors.white)));
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
    );
  }

  // Tạo lớp phủ mờ xung quanh khung
  Widget _buildOverlayMask() {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.width * 0.85 * 0.63,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}