import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin/admin_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cập nhật đoạn khởi tạo Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Giúp Web nhận diện cấu hình
  );

  runApp(const WasteClassificationApp());
}

class WasteClassificationApp extends StatelessWidget {
  const WasteClassificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      builder: (context, child) {
        final themeProvider = Provider.of<ThemeProvider>(context);

        return MaterialApp(
          title: 'DanaNet',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: MyThemes.lightTheme,
          darkTheme: MyThemes.darkTheme,

          // Logic phân quyền
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (authSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (authSnapshot.hasError) {
                return const Scaffold(body: Center(child: Text("Lỗi xác thực!")));
              }

              if (authSnapshot.hasData && authSnapshot.data != null) {
                User user = authSnapshot.data!;

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                  builder: (context, docSnapshot) {
                    if (docSnapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }
                    if (docSnapshot.hasData && docSnapshot.data!.exists) {
                      Map<String, dynamic> userData = docSnapshot.data!.data() as Map<String, dynamic>;
                      String role = userData['role'] ?? 'user';

                      if (role == 'admin') {
                        return const AdminScreen();
                      } else {
                        return const HomeScreen();
                      }
                    }
                    return const HomeScreen();
                  },
                );
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}