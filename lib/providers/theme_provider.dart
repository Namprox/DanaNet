import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Khởi tạo và tải chế độ cũ đã lưu
  ThemeProvider() {
    _loadTheme();
  }

  void toggleTheme(bool isOn) async {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // Báo cho toàn bộ app biết để đổi màu

    // Lưu vào bộ nhớ
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isOn);
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

// Cấu hình màu sắc cho 2 chế độ
class MyThemes {
  static final lightTheme = ThemeData(
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: Colors.green,
      inversePrimary: Colors.greenAccent, // Màu AppBar cũ
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.green,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
  );

  static final darkTheme = ThemeData(
    scaffoldBackgroundColor: Colors.grey.shade900, // Nền đen xám
    colorScheme: const ColorScheme.dark(
      primary: Colors.green,
      inversePrimary: Colors.black, // Màu AppBar khi tối
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey.shade800,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    // Chỉnh màu chữ mặc định sang trắng khi nền tối
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
      bodyLarge: TextStyle(color: Colors.white),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Colors.grey.shade800,
    ),
  );
}