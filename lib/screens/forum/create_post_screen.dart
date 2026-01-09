import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import '../../../models/address_model.dart';
import '../../services/address_service.dart';
import '../../providers/language_provider.dart';

class CreatePostScreen extends StatefulWidget {
  final String? postId;
  final Map<String, dynamic>? existingData;

  const CreatePostScreen({super.key, this.postId, this.existingData});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();

  // Cấu hình bài đăng
  String _role = 'seller';
  String? _selectedType;

  // Xử lý ảnh
  File? _imageFile;
  String? _oldImageBase64;
  bool _isUploading = false;
  bool _isPolicyAccepted = false;

  // Logic Địa chỉ
  final AddressService _addressService = AddressService();
  List<Province> _provinces = [];
  List<District> _districts = [];
  List<Ward> _wards = [];

  Province? _selectedProvince;
  District? _selectedDistrict;
  Ward? _selectedWard;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchProvinces();
    if (widget.existingData != null) {
      _loadExistingPostData();
    } else {
      _autoFillUserProfile();
    }
  }

  Future<void> _fetchProvinces() async {
    try {
      var data = await _addressService.fetchProvinces();
      if (mounted) setState(() => _provinces = data);
    } catch (e) {
      print("Lỗi tải tỉnh: $e");
    }
  }

  Future<void> _fetchDistricts(int provinceCode) async {
    try {
      var data = await _addressService.fetchDistricts(provinceCode);
      if (mounted) setState(() => _districts = data);
    } catch (e) {
      print("Lỗi tải huyện: $e");
    }
  }

  Future<void> _fetchWards(int districtCode) async {
    try {
      var data = await _addressService.fetchWards(districtCode);
      if (mounted) setState(() => _wards = data);
    } catch (e) {
      print("Lỗi tải xã: $e");
    }
  }

  Future<void> _autoFillUserProfile() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          if (data['phone'] != null) _phoneController.text = data['phone'];
          if (data['streetAddress'] != null)
            _streetController.text = data['streetAddress'];
        });
        await _restoreAddressFromNames(
            data['city'], data['district'], data['ward']);
      }
    } catch (e) {
      print("Lỗi autofill: $e");
    }
  }

  void _loadExistingPostData() {
    var data = widget.existingData!;
    setState(() {
      _role = data['role'];
      _titleController.text = data['title'];
      _contentController.text = data['content'];
      _phoneController.text = data['phone'];
      _streetController.text = data['streetAddress'] ?? "";
      _oldImageBase64 = data['imageBase64'];
      _isPolicyAccepted = true;
      _selectedType = data['type'];
    });
    _restoreAddressFromNames(data['city'], data['district'], data['ward']);
  }

  Future<void> _restoreAddressFromNames(
      String? cityName, String? districtName, String? wardName) async {
    if (cityName == null || _provinces.isEmpty) return;
    try {
      var foundCity = _provinces.firstWhere((p) => p.name == cityName,
          orElse: () => _provinces.first);
      if (_provinces.contains(foundCity)) {
        setState(() => _selectedProvince = foundCity);
        await _fetchDistricts(foundCity.code);

        if (districtName != null) {
          var foundDist = _districts.firstWhere((d) => d.name == districtName,
              orElse: () => _districts.first);
          if (_districts.contains(foundDist)) {
            setState(() => _selectedDistrict = foundDist);
            await _fetchWards(foundDist.code);

            if (wardName != null) {
              var foundWard = _wards.firstWhere((w) => w.name == wardName,
                  orElse: () => _wards.first);
              if (_wards.contains(foundWard))
                setState(() => _selectedWard = foundWard);
            }
          }
        }
      }
    } catch (e) {
      print("Không restore được địa chỉ: $e");
    }
  }

  Future<void> _pickImage(LanguageProvider lang) async {
    final picker = ImagePicker();
    showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: Text(lang.getText('take_photo')),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final XFile? file = await picker.pickImage(
                          source: ImageSource.camera,
                          maxWidth: 800,
                          imageQuality: 70);
                      if (file != null)
                        setState(() => _imageFile = File(file.path));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: Text(lang.getText('choose_gallery')),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final XFile? file = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 800,
                          imageQuality: 70);
                      if (file != null)
                        setState(() => _imageFile = File(file.path));
                    },
                  ),
                ],
              ),
            ));
  }

  Future<void> _submitPost() async {
    // Lấy Provider trong hàm async
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvince == null ||
        _selectedDistrict == null ||
        _selectedWard == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.getText('full_address_err')),
          backgroundColor: Colors.red));
      return;
    }
    if (_role == 'seller' &&
        _imageFile == null &&
        (_oldImageBase64 == null || _oldImageBase64!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.getText('seller_image_err')),
          backgroundColor: Colors.red));
      return;
    }
    if (!_isPolicyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.getText('policy_err')),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isUploading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String imageBase64 = _oldImageBase64 ?? "";
      if (_imageFile != null) {
        List<int> imageBytes = await _imageFile!.readAsBytes();
        imageBase64 = base64Encode(imageBytes);
      }

      String fullAddress =
          "${_streetController.text.trim()}, ${_selectedWard!.name}, ${_selectedDistrict!.name}, ${_selectedProvince!.name}";

      Map<String, dynamic> postData = {
        'role': _role,
        'type': _selectedType, // Lưu giá trị theo ngôn ngữ hiện tại
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _selectedProvince!.name,
        'district': _selectedDistrict!.name,
        'ward': _selectedWard!.name,
        'streetAddress': _streetController.text.trim(),
        'address': fullAddress,
        'fullAddress': fullAddress,
        'imageBase64': imageBase64,
        'lastUpdated': FieldValue.serverTimestamp(),
        'userEmail': user?.email ?? "",
      };

      if (widget.postId == null) {
        String userName = "Người dùng ẩn danh"; // Có thể thêm key cho từ này
        if (user != null) {
          var userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) userName = userDoc['name'] ?? userName;
        }
        postData['uid'] = user?.uid;
        postData['userName'] = userName;
        postData['timestamp'] = FieldValue.serverTimestamp();
        postData['status'] = 'active';
        await FirebaseFirestore.instance
            .collection('scrap_posts')
            .add(postData);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(lang.getText('post_success')),
              backgroundColor: Colors.green));
      } else {
        await FirebaseFirestore.instance
            .collection('scrap_posts')
            .doc(widget.postId)
            .update(postData);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(lang.getText('post_update_success')),
              backgroundColor: Colors.green));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${lang.getText('error')}: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe Provider
    final lang = Provider.of<LanguageProvider>(context);

    // Tạo danh sách Waste Type động theo ngôn ngữ
    final List<String> wasteTypes = [
      lang.getText('type_paper'),
      lang.getText('type_plastic'),
      lang.getText('type_metal'),
      lang.getText('type_elec'),
      lang.getText('type_glass'),
      lang.getText('type_other'),
    ];

    // Đảm bảo _selectedType hợp lệ khi đổi ngôn ngữ
    if (_selectedType == null || !wasteTypes.contains(_selectedType)) {
      _selectedType = wasteTypes[0];
    }

    bool isSeller = _role == 'seller';
    bool isEditing = widget.postId != null;

    return Scaffold(
      appBar: AppBar(
          title: Text(isEditing
              ? lang.getText('edit_post_title')
              : lang.getText('create_post_title')),
          backgroundColor: Colors.green),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(lang.getText('forum_rule_info'),
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.4)))
                  ]),
                ),

                if (!isEditing)
                  Row(children: [
                    Expanded(
                        child: RadioListTile(
                            title: Text(lang.getText('i_want_sell')),
                            value: 'seller',
                            groupValue: _role,
                            activeColor: Colors.green,
                            onChanged: (v) =>
                                setState(() => _role = v.toString()))),
                    Expanded(
                        child: RadioListTile(
                            title: Text(lang.getText('i_want_buy')),
                            value: 'buyer',
                            groupValue: _role,
                            activeColor: Colors.blue,
                            onChanged: (v) =>
                                setState(() => _role = v.toString()))),
                  ]),
                if (!isEditing) const Divider(),

                GestureDetector(
                  onTap: () => _pickImage(lang), // Truyền lang vào picker
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.grey[200],
                        border: Border.all(
                            color: (isSeller &&
                                    _imageFile == null &&
                                    _oldImageBase64 == null)
                                ? Colors.red.shade300
                                : Colors.grey),
                        borderRadius: BorderRadius.circular(10)),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(_imageFile!, fit: BoxFit.contain))
                        : (_oldImageBase64 != null &&
                                _oldImageBase64!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                    base64Decode(_oldImageBase64!),
                                    fit: BoxFit.contain))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Icon(Icons.camera_alt,
                                        size: 50,
                                        color: (isSeller)
                                            ? Colors.red
                                            : Colors.grey),
                                    Text(
                                        isSeller
                                            ? lang.getText(
                                                'take_photo_required')
                                            : lang
                                                .getText('take_photo_optional'),
                                        style: TextStyle(
                                            color: isSeller
                                                ? Colors.red
                                                : Colors.black54))
                                  ]),
                  ),
                ),
                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(
                      labelText: lang.getText('waste_type_label'),
                      border: const OutlineInputBorder()),
                  // Sử dụng list wasteTypes động
                  items: wasteTypes
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedType = val!),
                ),
                const SizedBox(height: 15),
                TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                        labelText: lang.getText('post_title_label'),
                        border: const OutlineInputBorder()),
                    validator: (v) =>
                        v!.isEmpty ? lang.getText('enter_title_err') : null),
                const SizedBox(height: 15),
                TextFormField(
                    controller: _contentController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText: lang.getText('post_desc_label'),
                        border: const OutlineInputBorder())),

                const SizedBox(height: 25),
                Text(lang.getText('address_contact_header'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),

                // 1. Tỉnh/Thành
                DropdownSearch<Province>(
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            hintText: lang.getText('search_province'),
                            // Dùng lại key cũ
                            prefixIcon: const Icon(Icons.search))),
                  ),
                  items: (filter, loadProps) => _provinces,
                  itemAsString: (p) => p.name,
                  selectedItem: _selectedProvince,
                  compareFn: (i, s) => i.code == s.code,
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                        labelText: lang.getText('province_city'),
                        // Dùng lại key cũ
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.location_city)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _selectedProvince = val;
                      _districts = [];
                      _selectedDistrict = null;
                      _wards = [];
                      _selectedWard = null;
                    });
                    if (val != null) _fetchDistricts(val.code);
                  },
                  validator: (v) => v == null
                      ? lang.getText('select_province')
                      : null, // Dùng lại key cũ
                ),
                const SizedBox(height: 10),

                // 2. Quận/Huyện
                DropdownSearch<District>(
                  enabled: _selectedProvince != null,
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            hintText: lang.getText('search_district'),
                            prefixIcon: const Icon(Icons.search))),
                  ),
                  items: (filter, loadProps) => _districts,
                  itemAsString: (d) => d.name,
                  selectedItem: _selectedDistrict,
                  compareFn: (i, s) => i.code == s.code,
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                        labelText: lang.getText('district'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.map)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _selectedDistrict = val;
                      _wards = [];
                      _selectedWard = null;
                    });
                    if (val != null) _fetchWards(val.code);
                  },
                  validator: (v) =>
                      v == null ? lang.getText('select_district') : null,
                ),
                const SizedBox(height: 10),

                // 3. Phường/Xã
                DropdownSearch<Ward>(
                  enabled: _selectedDistrict != null,
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            hintText: lang.getText('search_ward'),
                            prefixIcon: const Icon(Icons.search))),
                  ),
                  items: (filter, loadProps) => _wards,
                  itemAsString: (w) => w.name,
                  selectedItem: _selectedWard,
                  compareFn: (i, s) => i.code == s.code,
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                        labelText: lang.getText('ward'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.holiday_village)),
                  ),
                  onChanged: (val) => setState(() => _selectedWard = val),
                  validator: (v) =>
                      v == null ? lang.getText('select_ward') : null,
                ),
                const SizedBox(height: 10),

                TextFormField(
                    controller: _streetController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                        labelText: lang.getText('street_name'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.home)),
                    validator: (v) =>
                        v!.isEmpty ? lang.getText('enter_street') : null),
                const SizedBox(height: 15),
                TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                        labelText: lang.getText('contact_phone'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.phone)),
                    validator: (v) =>
                        v!.isEmpty ? lang.getText('enter_phone_err') : null),

                const SizedBox(height: 20),
                CheckboxListTile(
                  title: Text(lang.getText('policy_pledge'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  value: _isPolicyAccepted,
                  activeColor: Colors.green,
                  onChanged: (val) => setState(() => _isPolicyAccepted = val!),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                      onPressed: _isUploading ? null : _submitPost,
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isSeller ? Colors.green : Colors.blue,
                          foregroundColor: Colors.white),
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isEditing
                                  ? lang.getText('update_post_btn')
                                  : lang.getText('post_now_btn'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}