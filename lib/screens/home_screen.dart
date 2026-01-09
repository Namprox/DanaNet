import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import 'components/user_drawer.dart';
import 'components/garden_section.dart';
import 'components/ai_scan_section.dart';
import 'ai_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  int _waterDrops = 0;
  int _treeLevel = 1;
  static const int _maxLevel = 5;

  File? _selectedImage;
  String? _serverResult;
  bool _isAnalyzing = false;

  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Danh sách API Key cho Gemini (Dự phòng)
  final List<String> _apiKeys = [
  ];
  int _currentKeyIndex = 0;
  final String _geminiModelName = 'gemini-2.5-flash';

  @override
  void initState() {
    super.initState();
    _loadGameData();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Logic game
  Future<void> _loadGameData() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();
        if (userDoc.exists &&
            userDoc.data().toString().contains('waterDrops')) {
          setState(() {
            _waterDrops = userDoc['waterDrops'] ?? 0;
            _treeLevel = userDoc['treeLevel'] ?? 1;
          });
          return;
        }
      } catch (e) {
        print("Lỗi tải data: $e");
      }
    }
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterDrops = prefs.getInt('waterDrops') ?? 0;
      _treeLevel = prefs.getInt('treeLevel') ?? 1;
    });
  }

  Future<void> _saveGameData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('waterDrops', _waterDrops);
    await prefs.setInt('treeLevel', _treeLevel);
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'waterDrops': _waterDrops,
        'treeLevel': _treeLevel,
      });
    }
  }

  void _waterTree(LanguageProvider lang) {
    if (_treeLevel >= _maxLevel) return;
    if (_waterDrops >= 20) {
      setState(() {
        _waterDrops -= 20;
        _animController.forward().then((_) => _animController.reverse());
        if (_treeLevel < _maxLevel) {
          _treeLevel++;
          if (_treeLevel == _maxLevel) {
            _showMaxLevelDialog(lang);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(lang.getText('tree_grew')),
                backgroundColor: Colors.green));
          }
        }
        _saveGameData();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.getText('need_water')),
          backgroundColor: Colors.red));
    }
  }

  void _resetTree(LanguageProvider lang) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(lang.getText('reset_title')),
              content: Text(lang.getText('reset_content')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(lang.getText('cancel'))),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _treeLevel = 1;
                      _saveGameData();
                    });
                    Navigator.pop(ctx);
                  },
                  child: Text(lang.getText('confirm')),
                )
              ],
            ));
  }

  void _showMaxLevelDialog(LanguageProvider lang) {
    showDialog(
        context: context,
        builder: (ctx) =>
            AlertDialog(title: Text(lang.getText('max_level_title')), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(lang.getText('great')))
            ]));
  }

  // Logic AI
  Future<void> _pickImage(ImageSource source, LanguageProvider lang) async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: source, maxWidth: 800);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _serverResult = lang.getText('uploading');
        _isAnalyzing = true;
      });
      _uploadAndPredict(File(pickedFile.path), lang);
    }
  }

  // Hàm gọi Gemini API khi Server Python ko chắc chắn
  Future<void> _analyzeWithGemini(File imageFile, LanguageProvider lang) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final prompt = TextPart(lang.getText('gemini_classify_prompt'));
      final imagePart = DataPart('image/jpeg', imageBytes);

      String? textResult;
      bool success = false;

      // Vòng lặp thử các Key nếu lỗi
      for (int i = 0; i < _apiKeys.length; i++) {
        try {
          final currentKey = _apiKeys[_currentKeyIndex];
          final visionModel =
              GenerativeModel(model: _geminiModelName, apiKey: currentKey);

          final response = await visionModel.generateContent([
            Content.multi([prompt, imagePart])
          ]);

          textResult = response.text;
          if (textResult != null) {
            success = true;
            break; // Thành công thì thoát vòng lặp
          }
        } catch (e) {
          // Chuyển sang key tiếp theo
          _currentKeyIndex++;
          if (_currentKeyIndex >= _apiKeys.length) _currentKeyIndex = 0;
        }
      }

      if (success) {
        String displayResult =
            "${lang.getText('result_prefix')} $textResult (Gemini AI)";
        setState(() {
          _isAnalyzing = false;
          _serverResult = displayResult;
          _waterDrops += 10;
          _saveGameData();
        });
        _showAiResultPopup(
            "${lang.getText('result_prefix')} **$textResult**\n\n*(Được phân tích bởi Gemini AI vì Server MobileNetV2 không chắc chắn)*",
            lang);
      } else {
        setState(() {
          _isAnalyzing = false;
          _serverResult = lang.getText('ai_error_overload');
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _serverResult = "${lang.getText('error')}: $e";
      });
    }
  }

  Future<void> _uploadAndPredict(File imageFile, LanguageProvider lang) async {
    const String serverUrl = 'http://172.16.8.120:8000/predict';
    try {
      var uri = Uri.parse(serverUrl);
      var request = http.MultipartRequest('POST', uri);
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      // Gửi request với timeout 5s (để nếu server tắt thì chuyển nhanh qua Gemini)
      var response = await http.Response.fromStream(await request.send())
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        var resultJson = jsonDecode(response.body);
        String label = resultJson['label'] ?? lang.getText('unknown');

        // Ép kiểu an toàn cho confidence
        double confidence = 0.0;
        if (resultJson['confidence'] is double) {
          confidence = resultJson['confidence'];
        } else if (resultJson['confidence'] is int) {
          confidence = (resultJson['confidence'] as int).toDouble();
        }

        // Kiểm tra độ chính xác
        if (confidence < 0.7) {
          // Nếu dưới 70%
          setState(() {
            _serverResult = lang.getText(
                'low_confidence_switch'); // "Độ tin cậy thấp, đang hỏi lại AI..."
          });
          // Chuyển sang dùng Gemini
          await _analyzeWithGemini(imageFile, lang);
        } else {
          // Nếu trên 70% -> Dùng kết quả Server Python
          String displayResult = "${lang.getText('result_prefix')} $label";
          setState(() {
            _isAnalyzing = false;
            _serverResult = displayResult;
            _waterDrops += 10;
            _saveGameData();
          });
          _showAiResultPopup(
              "${lang.getText('result_prefix')} **$label**\n\n${lang.getText('confidence')} **${(confidence * 100).toStringAsFixed(1)}%**",
              lang);
        }
      } else {
        // Lỗi Server Python (500, 404...) -> Chuyển qua Gemini
        await _analyzeWithGemini(imageFile, lang);
      }
    } catch (e) {
      // Lỗi kết nối (Server tắt hoặc sai IP) -> Chuyển qua Gemini
      print("Lỗi Server Python: $e. Đang chuyển sang Gemini...");
      await _analyzeWithGemini(imageFile, lang);
    }
  }

  void _showAiResultPopup(String aiContent, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(25))),
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lang.getText('analysis_result'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green)),
              const Divider(),
              Expanded(
                  child: SingleChildScrollView(
                      child: MarkdownBody(data: aiContent))),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white),
                      child: Text("${lang.getText('understood')} (+10 💧)")))
            ],
          ),
        );
      },
    );
  }

  // UI chính
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);

    String displayResult = _serverResult ?? lang.getText('default_result');

    return Scaffold(
      drawer: const UserDrawer(),
      appBar: AppBar(
        backgroundColor:
            themeProvider.isDarkMode ? Colors.green.shade900 : Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(lang.getText('app_name'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () => lang.toggleLanguage(),
            icon: Text(lang.isVietnamese ? "🇻🇳" : "🇺🇸",
                style: const TextStyle(fontSize: 24)),
            tooltip: "Change Language",
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.water_drop, color: Colors.blue, size: 20),
              const SizedBox(width: 4),
              Text("$_waterDrops",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue))
            ]),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (context) => const AiChatScreen())),
        backgroundColor: Colors.lightBlue,
        child: const Icon(Icons.smart_toy, color: Colors.white),
        tooltip: lang.getText('ask_ai'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: <Widget>[
              const SizedBox(height: 20),
              GardenSection(
                waterDrops: _waterDrops,
                treeLevel: _treeLevel,
                maxLevel: _maxLevel,
                scaleAnimation: _scaleAnimation,
                onWater: () => _waterTree(lang),
                onReset: () => _resetTree(lang),
              ),
              const SizedBox(height: 30),
              AiScanSection(
                selectedImage: _selectedImage,
                isAnalyzing: _isAnalyzing,
                result: displayResult,
                onPickImage: (source) => _pickImage(source, lang),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}