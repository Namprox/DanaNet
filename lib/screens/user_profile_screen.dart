import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'camera_screen.dart';
import '../models/address_model.dart';
import '../services/address_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _streetController = TextEditingController();
  final _phoneController = TextEditingController();

  User? _currentUser;
  bool _isLoading = false;
  bool _isEmailUser = false;

  String _kycStatus = 'none';
  File? _cccdFront;
  File? _cccdBack;
  bool _isUploadingKyc = false;

  final AddressService _addressService = AddressService();

  List<Province> _provinceList = [];
  List<District> _districtList = [];
  List<Ward> _wardList = [];

  Province? _selectedProvince;
  District? _selectedDistrict;
  Ward? _selectedWard;

  String? _savedCityName;
  String? _savedDistrictName;
  String? _savedWardName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initAddressData();
  }

  Future<void> _initAddressData() async {
    try {
      var provinces = await _addressService.fetchProvinces();
      if (mounted) {
        setState(() {
          _provinceList = provinces;
        });
        _tryRestoreSavedAddress();
      }
    } catch (e) {
      print("Lỗi load tỉnh: $e");
    }
  }

  Future<void> _tryRestoreSavedAddress() async {
    if (_savedCityName == null || _provinceList.isEmpty) return;

    try {
      var foundProvince = _provinceList.firstWhere(
          (p) => p.name == _savedCityName,
          orElse: () => _provinceList.first);

      if (_provinceList.contains(foundProvince)) {
        setState(() => _selectedProvince = foundProvince);

        var districts =
            await _addressService.fetchDistricts(foundProvince.code);
        if (mounted) setState(() => _districtList = districts);

        if (_savedDistrictName != null) {
          var foundDistrict = districts.firstWhere(
              (d) => d.name == _savedDistrictName,
              orElse: () => districts.first);

          if (districts.contains(foundDistrict)) {
            setState(() => _selectedDistrict = foundDistrict);

            var wards = await _addressService.fetchWards(foundDistrict.code);
            if (mounted) setState(() => _wardList = wards);

            if (_savedWardName != null) {
              var foundWard = wards.firstWhere((w) => w.name == _savedWardName,
                  orElse: () => wards.first);
              if (wards.contains(foundWard)) {
                setState(() => _selectedWard = foundWard);
              }
            }
          }
        }
      }
    } catch (e) {
      print("Không restore được địa chỉ: $e");
    }
  }

  Future<void> _loadUserData() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _emailController.text = _currentUser!.email ?? "";
      _phoneController.text = _currentUser!.phoneNumber ?? "";
      _nameController.text = _currentUser!.displayName ?? "";

      for (var provider in _currentUser!.providerData) {
        if (provider.providerId == 'password') {
          if (mounted) setState(() => _isEmailUser = true);
        }
      }

      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get();

        if (userDoc.exists && mounted) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            if (data['name'] != null) _nameController.text = data['name'];

            if (data['email'] != null && data['email'] != "")
              _emailController.text = data['email'];
            if (data['phone'] != null && data['phone'] != "")
              _phoneController.text = data['phone'];

            _kycStatus = data['kycStatus'] ?? 'none';
            if (data['streetAddress'] != null)
              _streetController.text = data['streetAddress'];

            _savedCityName = data['city'];
            _savedDistrictName = data['district'];
            _savedWardName = data['ward'];
          });
          _tryRestoreSavedAddress();
        }
      } catch (e) {
        print("Lỗi tải dữ liệu user: $e");
      }
    }
  }

  Future<void> _takePhotoWithCustomCamera(
      BuildContext context, bool isFront, StateSetter setModalState) async {
    final String? imagePath = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const CameraOverlayScreen()));
    if (imagePath != null && mounted) {
      setState(() {
        if (isFront)
          _cccdFront = File(imagePath);
        else
          _cccdBack = File(imagePath);
      });
      setModalState(() {});
    }
  }

  Future<void> _pickFromGallery(bool isFront, StateSetter setModalState) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 70);
    if (pickedFile != null && mounted) {
      setState(() {
        if (isFront)
          _cccdFront = File(pickedFile.path);
        else
          _cccdBack = File(pickedFile.path);
      });
      setModalState(() {});
    }
  }

  // Truyền lang vào hàm này
  void _showImageSourceSelection(BuildContext parentContext, bool isFront,
      StateSetter setModalState, LanguageProvider lang) {
    showModalBottomSheet(
        context: parentContext,
        builder: (ctx) => SafeArea(
                child: Wrap(children: [
              ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: Text(lang.getText('take_photo')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _takePhotoWithCustomCamera(
                        parentContext, isFront, setModalState);
                  }),
              ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: Text(lang.getText('choose_gallery')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _pickFromGallery(isFront, setModalState);
                  }),
            ])));
  }

  Future<void> _submitKYC() async {
    if (_cccdFront == null || _cccdBack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng chụp đủ 2 mặt CCCD!")));
      return;
    }
    setState(() => _isUploadingKyc = true);
    try {
      List<int> frontBytes = await _cccdFront!.readAsBytes();
      String frontBase64 = base64Encode(frontBytes);
      List<int> backBytes = await _cccdBack!.readAsBytes();
      String backBase64 = base64Encode(backBytes);

      int totalSize = frontBase64.length + backBase64.length;
      if (totalSize > 1500000)
        throw Exception("Ảnh quá lớn. Vui lòng chụp lại");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
        'kycStatus': 'pending',
        'kycFront': frontBase64,
        'kycBack': backBase64,
        'kycTimestamp': FieldValue.serverTimestamp(),
      });
      setState(() => _kycStatus = 'pending');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Đã gửi hồ sơ! Vui lòng chờ Admin xét duyệt"),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploadingKyc = false);
    }
  }

  // Truyền lang vào hàm này
  void _showKYCModal(LanguageProvider lang) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) =>
            StatefulBuilder(builder: (context, setModalState) {
              return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(lang.getText('kyc_title'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(lang.getText('kyc_desc'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                          child: GestureDetector(
                              onTap: () => _showImageSourceSelection(
                                  context, true, setModalState, lang),
                              child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: _cccdFront != null
                                      ? Image.file(_cccdFront!,
                                          fit: BoxFit.cover)
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                              const Icon(Icons.add_a_photo),
                                              Text(lang.getText('front_card'))
                                            ])))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: GestureDetector(
                              onTap: () => _showImageSourceSelection(
                                  context, false, setModalState, lang),
                              child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: _cccdBack != null
                                      ? Image.file(_cccdBack!,
                                          fit: BoxFit.cover)
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                              const Icon(Icons.add_a_photo),
                                              Text(lang.getText('back_card'))
                                            ])))),
                    ]),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: _isUploadingKyc ? null : _submitKYC,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white),
                            child: _isUploadingKyc
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Text(lang.getText('send_request')))),
                    const SizedBox(height: 20),
                  ])));
            }));
  }

  Future<String?> _showReauthDialog() async {
    String? password;
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text("Xác thực bảo mật"),
                content: TextField(
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Mật khẩu"),
                    onChanged: (v) => password = v),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Hủy")),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, password),
                      child: const Text("Xác nhận"))
                ]));
    return password;
  }

  // Truyền lang vào đây để lấy thông báo
  Future<void> _updateProfile(LanguageProvider lang) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String newName = _nameController.text.trim();
      String newEmail = _emailController.text.trim();
      String street = _streetController.text.trim();

      String city = _selectedProvince?.name ?? "";
      String district = _selectedDistrict?.name ?? "";
      String ward = _selectedWard?.name ?? "";

      if (city.isEmpty || district.isEmpty || ward.isEmpty || street.isEmpty) {
        throw Exception("Vui lòng chọn đầy đủ địa chỉ Tỉnh/Huyện/Xã và Số nhà");
      }
      String fullAddress = "$street, $ward, $district, $city";

      if (newName != _currentUser!.displayName)
        await _currentUser!.updateDisplayName(newName);

      if (_isEmailUser && newEmail != _currentUser!.email) {
        String? password = await _showReauthDialog();
        if (password != null) {
          AuthCredential credential = EmailAuthProvider.credential(
              email: _currentUser!.email!, password: password);
          await _currentUser!.reauthenticateWithCredential(credential);
          await _currentUser!.verifyBeforeUpdateEmail(newEmail);
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Đã gửi email xác thực!")));
        } else {
          setState(() => _isLoading = false);
          return;
        }
      }

      Map<String, dynamic> updateData = {
        'name': newName,
        'city': city,
        'district': district,
        'ward': ward,
        'streetAddress': street,
        'address': fullAddress,
        'provinceCode': _selectedProvince?.code,
      };

      if (_isEmailUser) updateData['email'] = newEmail;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.getText('update_success')),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      String err = e.toString().replaceAll("Exception:", "").trim();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${lang.getText('error')}: $err"),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gọi Provider ngôn ngữ
    final lang = Provider.of<LanguageProvider>(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text(lang.getText('profile_title')),
            backgroundColor: Colors.green),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.green,
                          child: Icon(Icons.person,
                              size: 60, color: Colors.white)),
                      const SizedBox(height: 10),
                      if (_kycStatus == 'verified')
                        Chip(
                            avatar: const Icon(Icons.check_circle,
                                color: Colors.white, size: 20),
                            label: Text(lang.getText('verified'),
                                style: const TextStyle(color: Colors.white)),
                            backgroundColor: Colors.blue)
                      else if (_kycStatus == 'pending')
                        Chip(
                            avatar: const Icon(Icons.hourglass_top,
                                color: Colors.white, size: 20),
                            label: Text(lang.getText('pending_approval'),
                                style: const TextStyle(color: Colors.white)),
                            backgroundColor: Colors.orange)
                      else
                        TextButton.icon(
                            onPressed: () => _showKYCModal(lang),
                            // Truyền lang
                            icon: const Icon(Icons.verified_user_outlined,
                                color: Colors.red),
                            label: Text(lang.getText('verify_now'),
                                style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(lang.getText('basic_info'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green)),
                const SizedBox(height: 10),
                TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                        labelText: lang.getText('full_name'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.badge)),
                    validator: (v) => v!.isEmpty
                        ? lang.getText('enter_name')
                        : null),
                const SizedBox(height: 15),

                if (_isEmailUser)
                  TextFormField(
                      controller: _emailController,
                      enabled: true,
                      decoration: InputDecoration(
                        labelText: lang.getText('email'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.email),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? "Không được để trống Email" : null)
                else
                  TextFormField(
                    controller: _phoneController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: lang.getText('phone_number'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                  ),

                const SizedBox(height: 25),
                Text(lang.getText('activity_address'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green)),
                Text(lang.getText('search_help'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),

                DropdownSearch<Province>(
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            hintText: "Nhập tên Tỉnh/Thành",
                            prefixIcon: Icon(Icons.search))),
                  ),
                  items: (filter, loadProps) => _provinceList,
                  itemAsString: (Province p) => p.name,
                  selectedItem: _selectedProvince,
                  compareFn: (item, selected) => item.code == selected.code,
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: lang.getText('province_city'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_city),
                    ),
                  ),
                  onChanged: (val) async {
                    setState(() {
                      _selectedProvince = val;
                      _districtList = [];
                      _selectedDistrict = null;
                      _wardList = [];
                      _selectedWard = null;
                    });
                    if (val != null) {
                      var districts =
                          await _addressService.fetchDistricts(val.code);
                      if (mounted) setState(() => _districtList = districts);
                    }
                  },
                  validator: (v) => v == null
                      ? lang.getText('select_province')
                      : null,
                ),
                const SizedBox(height: 15),

                DropdownSearch<District>(
                  enabled: _selectedProvince != null,
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            hintText: "Nhập tên Quận/Huyện",
                            prefixIcon: Icon(Icons.search))),
                  ),
                  items: (filter, loadProps) => _districtList,
                  itemAsString: (District d) => d.name,
                  selectedItem: _selectedDistrict,
                  compareFn: (item, selected) => item.code == selected.code,
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: lang.getText('district'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.map),
                    ),
                  ),
                  onChanged: _selectedProvince == null
                      ? null
                      : (val) async {
                          setState(() {
                            _selectedDistrict = val;
                            _wardList = [];
                            _selectedWard = null;
                          });
                          if (val != null) {
                            var wards =
                                await _addressService.fetchWards(val.code);
                            if (mounted) setState(() => _wardList = wards);
                          }
                        },
                  validator: (v) => v == null
                      ? lang.getText('select_district')
                      : null,
                ),
                const SizedBox(height: 15),

                DropdownSearch<Ward>(
                  enabled: _selectedDistrict != null,
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            hintText: "Nhập tên Phường/Xã",
                            prefixIcon: Icon(Icons.search))),
                  ),
                  items: (filter, loadProps) => _wardList,
                  itemAsString: (Ward w) => w.name,
                  selectedItem: _selectedWard,
                  compareFn: (item, selected) => item.code == selected.code,
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: lang.getText('ward'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.holiday_village),
                    ),
                  ),
                  onChanged: _selectedDistrict == null
                      ? null
                      : (val) {
                          setState(() => _selectedWard = val);
                        },
                  validator: (v) =>
                      v == null ? lang.getText('select_ward') : null,
                ),
                const SizedBox(height: 15),

                TextFormField(
                  controller: _streetController,
                  decoration: InputDecoration(
                      labelText: lang.getText('street_name'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.home)),
                  validator: (v) =>
                      v!.isEmpty ? lang.getText('enter_street') : null,
                ),

                const SizedBox(height: 40),
                SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _updateProfile(lang), // Truyền lang
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text(lang.getText('save_changes'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)))),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}