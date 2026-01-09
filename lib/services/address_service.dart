import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/address_model.dart';

class AddressService {
  static const String _baseUrl = "https://provinces.open-api.vn/api";

  // 1. Lấy danh sách tất cả Tỉnh/Thành
  Future<List<Province>> fetchProvinces() async {
    final response = await http.get(Uri.parse("$_baseUrl/p/"));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((json) => Province.fromJson(json)).toList();
    } else {
      throw Exception('Lỗi tải danh sách tỉnh');
    }
  }

  // 2. Lấy danh sách Quận/Huyện theo mã Tỉnh
  Future<List<District>> fetchDistricts(int provinceCode) async {
    final response = await http.get(Uri.parse("$_baseUrl/p/$provinceCode?depth=2"));
    if (response.statusCode == 200) {
      var data = json.decode(utf8.decode(response.bodyBytes));
      List<dynamic> districtsJson = data['districts'];
      return districtsJson.map((json) => District.fromJson(json)).toList();
    } else {
      throw Exception('Lỗi tải danh sách quận/huyện');
    }
  }

  // 3. Lấy danh sách Phường/Xã theo mã Quận
  Future<List<Ward>> fetchWards(int districtCode) async {
    final response = await http.get(Uri.parse("$_baseUrl/d/$districtCode?depth=2"));
    if (response.statusCode == 200) {
      var data = json.decode(utf8.decode(response.bodyBytes));
      List<dynamic> wardsJson = data['wards'];
      return wardsJson.map((json) => Ward.fromJson(json)).toList();
    } else {
      throw Exception('Lỗi tải danh sách phường/xã');
    }
  }
}