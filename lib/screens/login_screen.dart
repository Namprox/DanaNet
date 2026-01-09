import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'home_screen.dart';
import 'admin/admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _inputController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _inputFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _isRegistering = false;
  bool _showForgotPassword = false;
  bool _isPhoneMode = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      final text = _inputController.text.trim();
      final isPhone =
          RegExp(r'^[0-9]+$').hasMatch(text) || text.startsWith('+');

      if (_isPhoneMode != isPhone) {
        setState(() {
          _isPhoneMode = isPhone;
        });
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _nameFocus.dispose();
    _inputFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // 1. Đăng ký
  Future<void> _handleRegister() async {
    // Lấy lang provider (listen: false) để dùng trong logic
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (_nameController.text.trim().isEmpty) {
      _showError(lang.getText('enter_name_err'));
      return;
    }
    if (_inputController.text.trim().isEmpty) {
      _showError(lang.getText('enter_email_phone_err'));
      return;
    }

    setState(() => _isLoading = true);

    if (_isPhoneMode) {
      await _loginWithPhone();
    } else {
      if (_passwordController.text.trim().isEmpty) {
        _showError(lang.getText('enter_pass_err'));
        setState(() => _isLoading = false);
        return;
      }

      try {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _inputController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await _saveUserToFirestore(userCredential.user!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(lang.getText('register_success'))));
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } on FirebaseAuthException catch (e) {
        _showError("${lang.getText('register_err')} ${e.message}");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // 2. Đăng nhập
  void _handleLogin() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (_inputController.text.isEmpty) {
      _showError(lang.getText('enter_email_phone_err'));
      return;
    }

    setState(() => _isLoading = true);

    if (_isPhoneMode) {
      await _loginWithPhone();
    } else {
      if (_passwordController.text.isEmpty) {
        _showError(lang.getText('enter_pass_err'));
        setState(() => _isLoading = false);
        return;
      }
      await _loginWithEmail();
    }
  }

  // Logic Đăng nhập Email
  Future<void> _loginWithEmail() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _inputController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _checkRoleAndNavigate();
    } on FirebaseAuthException catch (e) {
      String msg = lang.getText('login_fail');
      if (e.code == 'user-not-found') {
        msg = lang.getText('user_not_found');
        _showForgotPassword = false;
      } else if (e.code == 'wrong-password') {
        msg = lang.getText('wrong_password');
        _showForgotPassword = true;
      }
      _showError(msg);
      setState(() => _isLoading = false);
    }
  }

  // Logic Đăng nhập/Đăng ký SĐT
  Future<void> _loginWithPhone() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    String phoneNumber = _inputController.text.trim();
    if (phoneNumber.startsWith('0')) {
      phoneNumber = '+84${phoneNumber.substring(1)}';
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _checkRoleAndNavigate();
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        String msg = e.message ?? lang.getText('auth_error');
        if (e.code == 'invalid-phone-number')
          msg = lang.getText('invalid_phone');
        _showError(msg);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _isLoading = false);
        _showOtpDialog(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  void _showOtpDialog(String verificationId) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(lang.getText('otp_dialog_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang.getText('otp_sent_msg')),
            const SizedBox(height: 10),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 5),
              maxLength: 6,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), counterText: ""),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.getText('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final smsCode = otpController.text.trim();
              if (smsCode.length < 6) return;

              try {
                PhoneAuthCredential credential = PhoneAuthProvider.credential(
                  verificationId: verificationId,
                  smsCode: smsCode,
                );

                UserCredential userCredential = await FirebaseAuth.instance
                    .signInWithCredential(credential);

                if (_isRegistering) {
                  await _saveUserToFirestore(userCredential.user!);
                }

                if (mounted) {
                  Navigator.pop(context);
                  await _checkRoleAndNavigate();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(lang.getText('otp_incorrect')),
                    backgroundColor: Colors.red));
              }
            },
            child: Text(lang.getText('confirm')),
          ),
        ],
      ),
    );
  }

  // Lưu User vào Firestore
  Future<void> _saveUserToFirestore(User user) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists || _isRegistering) {
      await userDoc.set({
        'email': user.email ?? "",
        'phone': user.phoneNumber ?? "",
        'name': _nameController.text.isNotEmpty
            ? _nameController.text.trim()
            : (snapshot.exists ? snapshot['name'] : lang.getText('new_user')),
        'role': snapshot.exists ? snapshot['role'] : 'user',
        'isActive': true,
        'createdAt': snapshot.exists
            ? snapshot['createdAt']
            : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // 3. Kiểm tra quyền và chuyển trang
  Future<void> _checkRoleAndNavigate() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (!_isRegistering) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!doc.exists) {
          await _saveUserToFirestore(user);
        }
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        if (userDoc.data().toString().contains('isActive') &&
            userDoc['isActive'] == false) {
          FirebaseAuth.instance.signOut();
          _showError(lang.getText('account_locked'));
          return;
        }

        String role = userDoc.data().toString().contains('role')
            ? userDoc['role']
            : 'user';
        if (mounted) {
          if (role == 'admin') {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const AdminScreen()));
          } else {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const HomeScreen()));
          }
        }
      }
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  Future<void> _handleForgotPassword() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (_inputController.text.isEmpty) {
      _showError(lang.getText('enter_email_reset'));
      return;
    }
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _inputController.text.trim());
      _showError(lang.getText('reset_email_sent'));
      setState(() => _showForgotPassword = false);
    } catch (e) {
      _showError(lang.getText('email_not_found'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe ngôn ngữ cho UI
    final lang = Provider.of<LanguageProvider>(context);

    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                color: backgroundColor,
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80, bottom: 20),
                        child: Column(
                          children: [
                            Text(lang.getText('app_welcome'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    letterSpacing: 1.5)),
                            const SizedBox(height: 5),
                            Text(lang.getText('app_slogan'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),

                    // Nút đổi ngôn ngữ
                    Positioned(
                      top: 10,
                      right: 10,
                      child: TextButton.icon(
                        onPressed: () => lang.toggleLanguage(),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            backgroundColor: isDarkMode
                                ? Colors.black12
                                : Colors.grey.shade100,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20))),
                        icon: const Icon(Icons.language, size: 20),
                        label: Text(
                          lang.isVietnamese ? "VN" : "EN",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Form đăng nhập/đăng ký
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            _isRegistering
                                ? Icons.person_add
                                : Icons.lock_person,
                            size: 80,
                            color: Colors.green),
                        const SizedBox(height: 20),
                        Text(
                            _isRegistering
                                ? lang.getText('register_title')
                                : lang.getText('login_title'),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54)),
                        const SizedBox(height: 30),
                        if (_isRegistering) ...[
                          TextField(
                            controller: _nameController,
                            focusNode: _nameFocus,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) {
                              FocusScope.of(context).requestFocus(_inputFocus);
                            },
                            decoration: InputDecoration(
                                labelText: lang.getText('full_name'),
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.badge)),
                          ),
                          const SizedBox(height: 15),
                        ],
                        TextField(
                          controller: _inputController,
                          focusNode: _inputFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: _isPhoneMode
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onSubmitted: (_) {
                            if (_isPhoneMode) {
                              _isRegistering
                                  ? _handleRegister()
                                  : _handleLogin();
                            } else {
                              FocusScope.of(context)
                                  .requestFocus(_passwordFocus);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: lang.getText('email_or_phone'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (!_isPhoneMode) ...[
                          TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              _isRegistering
                                  ? _handleRegister()
                                  : _handleLogin();
                            },
                            decoration: InputDecoration(
                              labelText: lang.getText('password'),
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.key),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.info,
                                    color: Colors.blue, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(lang.getText('otp_hint'),
                                        style: const TextStyle(
                                            color: Colors.blue))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                        ],
                        if (!_isRegistering &&
                            !_isPhoneMode &&
                            _showForgotPassword)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _handleForgotPassword,
                              icon: const Icon(Icons.mark_email_read,
                                  size: 16, color: Colors.deepOrange),
                              label: Text(lang.getText('forgot_password'),
                                  style: const TextStyle(
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        const SizedBox(height: 20),
                        _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.green)
                            : Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _isRegistering
                                          ? _handleRegister
                                          : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          elevation: 5,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10))),
                                      child: Text(
                                          _isRegistering
                                              ? lang.getText('register_now')
                                              : (_isPhoneMode
                                                  ? lang.getText('send_otp')
                                                  : lang.getText('login_now')),
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isRegistering = !_isRegistering;
                                        _inputController.clear();
                                        _passwordController.clear();
                                        _nameController.clear();
                                        _showForgotPassword = false;
                                        _isPhoneMode = false;
                                      });
                                    },
                                    child: Text(
                                        _isRegistering
                                            ? lang.getText('have_account')
                                            : lang.getText('no_account'),
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}