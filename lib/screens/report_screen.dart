import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../models/address_model.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // 1. Danh sách API KEY đa dự án
  final List<String> _apiKeys = [
  ];

  int _currentKeyIndex = 0;
  final String _modelName = 'gemini-2.5-flash';

  bool _isAnalyzing = false;
  String? _aiResult;
  bool _isBinFull = false;

  final _contentController = TextEditingController();
  final _addressController = TextEditingController();
  File? _reportImage;

  List<Province> _provinces = [];
  List<District> _districts = [];
  List<Ward> _wards = [];

  Province? _selectedProvince;
  District? _selectedDistrict;
  Ward? _selectedWard;

  bool _isLoadingProvinces = false;
  static const String apiBaseUrl = 'https://provinces.open-api.vn/api';

  @override
  void initState() {
    super.initState();
    _fetchProvinces();
  }

  Future<void> _fetchProvinces() async {
    setState(() => _isLoadingProvinces = true);
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/?depth=1'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _provinces = data.map((json) => Province.fromJson(json)).toList();
          _isLoadingProvinces = false;
        });
      }
    } catch (e) {
      print("Lỗi tải tỉnh: $e");
      setState(() => _isLoadingProvinces = false);
    }
  }

  Future<void> _fetchDistricts(int provinceCode) async {
    try {
      final response =
          await http.get(Uri.parse('$apiBaseUrl/p/$provinceCode?depth=2'));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> districtsData = data['districts'];
        setState(() {
          _districts =
              districtsData.map((json) => District.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print("Lỗi tải huyện: $e");
    }
  }

  Future<void> _fetchWards(int districtCode) async {
    try {
      final response =
          await http.get(Uri.parse('$apiBaseUrl/d/$districtCode?depth=2'));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> wardsData = data['wards'];
        setState(() {
          _wards = wardsData.map((json) => Ward.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print("Lỗi tải xã: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: source, maxWidth: 600, imageQuality: 50);

    if (pickedFile != null) {
      setState(() {
        _reportImage = File(pickedFile.path);
        _aiResult = null;
        _isBinFull = false;
      });
      _analyzeBinImage(pickedFile);
    }
  }

  Future<String> _imageToBase64(File image) async {
    List<int> imageBytes = await image.readAsBytes();
    return base64Encode(imageBytes);
  }

  // 3. Phân tích AI
  Future<void> _analyzeBinImage(XFile imageFile) async {
    setState(() => _isAnalyzing = true);

    // Lấy Provider để lấy Prompt và Text lỗi theo ngôn ngữ hiện tại
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    String? textResult;
    bool checkFull = false;
    bool success = false;

    try {
      final imageBytes = await imageFile.readAsBytes();

      // Lấy prompt từ file ngôn ngữ để AI trả lời đúng tiếng Anh/Việt
      final prompt = TextPart(lang.getText('ai_prompt'));

      final imagePart = DataPart('image/jpeg', imageBytes);

      for (int i = 0; i < _apiKeys.length; i++) {
        try {
          print(
              "ReportScreen: Đang thử phân tích ảnh với Key số ${_currentKeyIndex + 1}...");
          final currentKey = _apiKeys[_currentKeyIndex];
          final visionModel =
              GenerativeModel(model: _modelName, apiKey: currentKey);
          final response = await visionModel.generateContent([
            Content.multi([prompt, imagePart])
          ]);

          textResult = response.text ?? lang.getText('unknown'); // "Ko rõ"

          //  Logic kiểm tra từ khóa (thêm tiếng Anh)
          String upperResult = textResult!.toUpperCase();
          checkFull = upperResult.contains("KHẨN CẤP") ||
              upperResult.contains("EMERGENCY") ||
              upperResult.contains("TRÀN") ||
              upperResult.contains("OVERFLOW") ||
              textResult.contains("100%");

          success = true;
          print("ReportScreen: Thành công với Key số ${_currentKeyIndex + 1}");
          break;
        } catch (e) {
          print("ReportScreen: Key số ${_currentKeyIndex + 1} bị lỗi: $e");
          _currentKeyIndex++;
          if (_currentKeyIndex >= _apiKeys.length) {
            _currentKeyIndex = 0;
          }
        }
      }

      if (!success) {
        // Lấy text lỗi từ lang
        textResult = lang.getText('ai_error_overload');
      }
    } catch (e) {
      textResult = "${lang.getText('ai_error')}: $e";
    }

    setState(() {
      _isAnalyzing = false;
      _aiResult = textResult;
      _isBinFull = checkFull;
    });
  }

  // Gửi báo cáo
  Future<void> _submitReport() async {
    // Lấy Provider để hiện thông báo lỗi
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (_contentController.text.isEmpty ||
        _selectedProvince == null ||
        _selectedDistrict == null ||
        _selectedWard == null ||
        _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('fill_info_alert'))));
      return;
    }

    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()));

      User? currentUser = FirebaseAuth.instance.currentUser;
      String uid = currentUser?.uid ?? "";
      String email = currentUser?.email ?? "";
      String finalName =
          "Người dùng ẩn danh"; // Có thể thêm key cho từ này nếu muốn

      if (uid.isNotEmpty) {
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (userDoc.exists) {
            Map<String, dynamic>? data =
                userDoc.data() as Map<String, dynamic>?;
            if (data != null && data.containsKey('name')) {
              finalName = data['name'];
            } else {
              finalName = email;
            }
          }
        } catch (e) {
          finalName = email;
        }
      }

      String imageBase64 = "";
      if (_reportImage != null) {
        imageBase64 = await _imageToBase64(_reportImage!);
      }

      await FirebaseFirestore.instance.collection('reports').add({
        'uid': uid,
        'name': finalName,
        'email': email,
        'content': _contentController.text,
        'city': _selectedProvince?.name,
        'district': _selectedDistrict?.name,
        'ward': _selectedWard?.name,
        'address': _addressController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'imageBase64': imageBase64,
        'ai_analysis': _aiResult ?? "Chưa phân tích",
        'is_full_alert': _isBinFull,
      });

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.getText('report_success')),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${lang.getText('error')}: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe ngôn ngữ
    final lang = Provider.of<LanguageProvider>(context);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final normalAppBarColor =
        isDarkMode ? Colors.orange.shade900 : Colors.orange.shade100;
    final alertAppBarColor =
        isDarkMode ? Colors.red.shade900 : Colors.red.shade100;
    final appBarTextColor = isDarkMode ? Colors.white : Colors.black87;
    final aiResultBgColor = isDarkMode
        ? Colors.grey.shade800
        : (_isBinFull ? Colors.red.shade50 : Colors.green.shade50);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('report_title'),
            style: TextStyle(color: appBarTextColor)),
        backgroundColor: _isBinFull ? alertAppBarColor : normalAppBarColor,
        iconTheme: IconThemeData(color: appBarTextColor),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Ảnh hiện trường
              Text(lang.getText('scene_image'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Center(
                child: GestureDetector(
                  onTap: () => _pickImage(ImageSource.camera),
                  child: _reportImage != null
                      ? Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 500),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: _isBinFull ? Colors.red : Colors.green,
                                width: 3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child:
                                Image.file(_reportImage!, fit: BoxFit.contain),
                          ),
                        )
                      : Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey[200],
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(10)),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.camera_alt,
                                    size: 50, color: Colors.grey),
                                Text(lang.getText('tap_to_capture'))
                              ]),
                        ),
                ),
              ),

              const SizedBox(height: 15),
              if (_isAnalyzing)
                Row(children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 10),
                  Text(lang.getText('ai_checking'))
                ])
              else if (_aiResult != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: aiResultBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _isBinFull ? Colors.red : Colors.green),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(_isBinFull ? Icons.warning : Icons.check_circle,
                            color: _isBinFull ? Colors.red : Colors.green),
                        const SizedBox(width: 8),
                        Text(lang.getText('ai_assessment'),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isBinFull ? Colors.red : Colors.green)),
                      ]),
                      const Divider(),
                      MarkdownBody(data: _aiResult!),
                    ],
                  ),
                ),

              // 2. Địa điểm
              const SizedBox(height: 20),
              Text(lang.getText('location_section'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              _isLoadingProvinces
                  ? const LinearProgressIndicator()
                  : DropdownSearch<Province>(
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                                hintText: lang.getText('search_province'),
                                prefixIcon: const Icon(Icons.search))),
                      ),
                      compareFn: (i1, i2) => i1?.code == i2?.code,
                      items: (filter, loadProps) => _provinces,
                      itemAsString: (Province p) => p.name,
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                            labelText: lang.getText('province_city'),
                            border: const OutlineInputBorder()),
                      ),
                      selectedItem: _selectedProvince,
                      onChanged: (Province? value) {
                        setState(() {
                          _selectedProvince = value;
                          _selectedDistrict = null;
                          _selectedWard = null;
                          _districts = [];
                          _wards = [];
                        });
                        if (value != null) _fetchDistricts(value.code);
                      },
                    ),
              const SizedBox(height: 10),

              DropdownSearch<District>(
                enabled: _selectedProvince != null,
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                          hintText: lang.getText('search_district'),
                          prefixIcon: const Icon(Icons.search))),
                ),
                compareFn: (i1, i2) => i1?.code == i2?.code,
                items: (filter, loadProps) => _districts,
                itemAsString: (District d) => d.name,
                decoratorProps: DropDownDecoratorProps(
                  decoration: InputDecoration(
                      labelText: lang.getText('district'),
                      border: const OutlineInputBorder()),
                ),
                selectedItem: _selectedDistrict,
                onChanged: (District? value) {
                  setState(() {
                    _selectedDistrict = value;
                    _selectedWard = null;
                    _wards = [];
                  });
                  if (value != null) _fetchWards(value.code);
                },
              ),
              const SizedBox(height: 10),

              DropdownSearch<Ward>(
                enabled: _selectedDistrict != null,
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                          hintText: lang.getText('search_ward'),
                          prefixIcon: const Icon(Icons.search))),
                ),
                compareFn: (i1, i2) => i1?.code == i2?.code,
                items: (filter, loadProps) => _wards,
                itemAsString: (Ward w) => w.name,
                decoratorProps: DropDownDecoratorProps(
                  decoration: InputDecoration(
                      labelText: lang.getText('ward'),
                      border: const OutlineInputBorder()),
                ),
                selectedItem: _selectedWard,
                onChanged: (Ward? value) {
                  setState(() => _selectedWard = value);
                },
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                    labelText: lang.getText('street_hint'),
                    border: const OutlineInputBorder()),
              ),

              // 3. Nội dung
              const SizedBox(height: 20),
              Text(lang.getText('content_section'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              TextField(
                controller: _contentController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                    hintText: lang.getText('desc_hint'),
                    border: const OutlineInputBorder()),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _submitReport,
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(_isBinFull
                      ? lang.getText('emergency_report')
                      : lang.getText('send_report')),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _isBinFull ? Colors.red : Colors.green,
                      foregroundColor: Colors.white),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}