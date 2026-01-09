import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:provider/provider.dart';
import '../../../models/address_model.dart';
import '../../services/address_service.dart';
import '../../providers/language_provider.dart';
import 'create_post_screen.dart';
import 'forum_post_card.dart';

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  // Biến lọc vai trò
  String _filter = 'all'; // all, seller, buyer

  // Biến lọc khu vực
  Province? _filterCity;
  District? _filterDistrict;
  Ward? _filterWard;

  // API Địa chỉ
  final AddressService _addressService = AddressService();
  List<Province> _provinces = [];
  List<District> _districts = [];
  List<Ward> _wards = [];

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  // Logic tải địa chỉ
  Future<void> _loadProvinces() async {
    try {
      var data = await _addressService.fetchProvinces();
      if (mounted) setState(() => _provinces = data);
    } catch (e) {
      print("Lỗi tải tỉnh: $e");
    }
  }

  // UI: Modal lọc khu vực
  // Thêm tham số lang để dịch nội dung trong Modal
  void _showFilterModal(LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.getText('filter_area'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // 1. Tỉnh/Thành phố
                DropdownSearch<Province>(
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            hintText: lang.getText('search_province'),
                            prefixIcon: const Icon(Icons.search))),
                  ),
                  items: (f, l) => _provinces,
                  itemAsString: (p) => p.name,
                  selectedItem: _filterCity,
                  compareFn: (i, s) => i.code == s.code,
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                        labelText: lang.getText('province_city'),
                        border: const OutlineInputBorder()),
                  ),
                  onChanged: (val) async {
                    _filterCity = val;
                    setModalState(() {
                      _filterDistrict = null;
                      _filterWard = null;
                    });
                    if (val != null) {
                      var d = await _addressService.fetchDistricts(val.code);
                      setModalState(() => _districts = d);
                    }
                  },
                ),
                const SizedBox(height: 10),

                // 2. Quận/Huyện
                DropdownSearch<District>(
                  enabled: _filterCity != null,
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            hintText: lang.getText('search_district'),
                            prefixIcon: const Icon(Icons.search))),
                  ),
                  items: (f, l) => _districts,
                  itemAsString: (d) => d.name,
                  selectedItem: _filterDistrict,
                  compareFn: (i, s) => i.code == s.code,
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                        labelText: lang.getText('district'),
                        border: const OutlineInputBorder()),
                  ),
                  onChanged: (val) async {
                    _filterDistrict = val;
                    setModalState(() => _filterWard = null);
                    if (val != null) {
                      var w = await _addressService.fetchWards(val.code);
                      setModalState(() => _wards = w);
                    }
                  },
                ),
                const SizedBox(height: 10),

                // 3. Phường/Xã
                DropdownSearch<Ward>(
                  enabled: _filterDistrict != null,
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                            hintText: lang.getText('search_ward'),
                            prefixIcon: const Icon(Icons.search))),
                  ),
                  items: (f, l) => _wards,
                  itemAsString: (w) => w.name,
                  selectedItem: _filterWard,
                  compareFn: (i, s) => i.code == s.code,
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                        labelText: lang.getText('ward'),
                        border: const OutlineInputBorder()),
                  ),
                  onChanged: (val) {
                    setModalState(() => _filterWard = val);
                    _filterWard = val;
                  },
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _filterCity = null;
                            _filterDistrict = null;
                            _filterWard = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(lang.getText('clear_filter'),
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white),
                        onPressed: () {
                          setState(() {}); // Reload màn hình chính
                          Navigator.pop(ctx);
                        },
                        child: Text(lang.getText('apply')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe ngôn ngữ
    final lang = Provider.of<LanguageProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Xây dựng Query (Kết hợp lọc khu vực)
    Query query = FirebaseFirestore.instance.collection('scrap_posts');

    if (_filterCity != null)
      query = query.where('city', isEqualTo: _filterCity!.name);
    if (_filterDistrict != null)
      query = query.where('district', isEqualTo: _filterDistrict!.name);
    if (_filterWard != null)
      query = query.where('ward', isEqualTo: _filterWard!.name);

    // Chỉ sắp xếp khi ko lọc khu vực
    if (_filterCity == null) {
      query = query.orderBy('timestamp', descending: true);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.getText('forum_title')),
        backgroundColor: isDarkMode ? Colors.green.shade900 : Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // Nút lọc
          IconButton(
            icon: Icon(
                _filterCity != null
                    ? Icons.filter_list_alt
                    : Icons.filter_alt_outlined,
                color: _filterCity != null ? Colors.yellow : Colors.white),
            // Truyền lang vào modal
            onPressed: () => _showFilterModal(lang),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CreatePostScreen()));
        },
        label: Text(lang.getText('post_btn'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_a_photo),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Thanh hiển thị đang lọc khu vực
          if (_filterCity != null)
            Container(
              width: double.infinity,
              color: Colors.green.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.green),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      "${lang.getText('area_label')} ${_filterWard?.name ?? ''} ${_filterDistrict?.name ?? ''} ${_filterCity!.name}",
                      style: TextStyle(
                          color:
                              isDarkMode ? Colors.white : Colors.green.shade800,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() {
                      _filterCity = null;
                      _filterDistrict = null;
                      _filterWard = null;
                    }),
                    child:
                        const Icon(Icons.close, size: 20, color: Colors.grey),
                  )
                ],
              ),
            ),

          // Bộ lọc Vai trò
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterChip(lang.getText('filter_all'), 'all'),
                const SizedBox(width: 10),
                _buildFilterChip(lang.getText('filter_seller'), 'seller'),
                const SizedBox(width: 10),
                _buildFilterChip(lang.getText('filter_buyer'), 'buyer'),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          "${lang.getText('error')}: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text(lang.getText('no_posts')));
                }

                // Lọc Client-side cho Vai trò
                var posts = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (_filter == 'all') return true;
                  return data['role'] == _filter;
                }).toList();

                if (posts.isEmpty) {
                  return Center(
                      child: Text(lang.getText('no_posts_match')));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                      top: 0, left: 10, right: 10, bottom: 80),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    var doc = posts[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return ForumPostCard(doc: doc, data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _filter == value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.orange.shade200,
      labelStyle: TextStyle(
          color: isSelected
              ? Colors.deepOrange.shade900
              : (isDarkMode ? Colors.white : Colors.black),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      onSelected: (bool selected) {
        if (selected) setState(() => _filter = value);
      },
    );
  }
}