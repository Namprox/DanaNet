import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe ngôn ngữ
    final lang = Provider.of<LanguageProvider>(context);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final bodyTextColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.grey.shade600;
    final cardColor = isDarkMode ? Colors.grey.shade900 : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        // Dùng key 'about_app' đã khai báo ở user_drawer
        title: Text(lang.getText('about_app')),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: const Icon(Icons.eco, size: 60, color: Colors.green),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "DanaNet",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "${lang.getText('app_version')} 1.0.0",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Giới thiệu
                  _buildSectionTitle(lang.getText('intro_header')),
                  const SizedBox(height: 10),
                  Text(
                    lang.getText('intro_content'),
                    style: TextStyle(
                        fontSize: 15, height: 1.5, color: bodyTextColor),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 25),

                  // 2. Hướng dẫn sử dụng
                  _buildSectionTitle(lang.getText('usage_header')),
                  const SizedBox(height: 10),
                  // Các bước hướng dẫn
                  _buildStepItem("1", lang.getText('step1_title'),
                      lang.getText('step1_desc'), bodyTextColor, subTextColor),
                  _buildStepItem("2", lang.getText('step2_title'),
                      lang.getText('step2_desc'), bodyTextColor, subTextColor),
                  _buildStepItem("3", lang.getText('step3_title'),
                      lang.getText('step3_desc'), bodyTextColor, subTextColor),
                  _buildStepItem("4", lang.getText('step4_title'),
                      lang.getText('step4_desc'), bodyTextColor, subTextColor),

                  const SizedBox(height: 25),

                  // 3. Thông tin lập trình viên
                  _buildSectionTitle(lang.getText('dev_team')),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 3,
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blueAccent,
                            child: Text("N",
                                style: TextStyle(
                                    fontSize: 24,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Nguyễn Kỳ Nam",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: bodyTextColor)),
                                const SizedBox(height: 4),
                                Text(lang.getText('dev_role'),
                                    style: TextStyle(
                                        color: subTextColor, fontSize: 13)),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () =>
                                      _launchURL("mailto:namky1602@gmail.com"),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.email,
                                          size: 14, color: Colors.blue),
                                      const SizedBox(width: 5),
                                      Text("namky1602@gmail.com",
                                          style: TextStyle(
                                              color: Colors.blue.shade400,
                                              fontSize: 12)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Footer
                  Center(
                    child: Text(
                      lang.getText('copyright'),
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.green,
      ),
    );
  }

  Widget _buildStepItem(String step, String title, String desc,
      Color titleColor, Color descColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              step,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: titleColor)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: descColor, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }
}