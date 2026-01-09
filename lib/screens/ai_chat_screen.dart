import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  // Danh sách API KEY đa dự án
  final List<String> _apiKeys = [
  ];

  int _currentKeyIndex = 0;
  final String _modelName = 'gemini-2.5-flash';

  late ChatSession _chat;
  List<Content> _history = [];

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  final List<Map<String, dynamic>> _messages = [];

  // Biến để đảm bảo chỉ khởi tạo 1 lần
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Khởi tạo Chat trong này để lấy được ngôn ngữ từ Provider
    if (_isInit) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      _initChatSession(lang);
      _isInit = false;
    }
  }

  // Truyền LanguageProvider vào để lấy Persona và Lời chào
  void _initChatSession(LanguageProvider lang) {
    try {
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKeys[_currentKeyIndex],
        generationConfig: GenerationConfig(temperature: 0.7),
      );

      // Lấy Persona từ file ngôn ngữ
      final persona = Content.text(lang.getText('ai_persona'));

      if (_history.isEmpty) {
        _history = [persona];
        setState(() {
          _messages.add({
            'role': 'model',
            // Lấy lời chào từ file ngôn ngữ
            'text': lang.getText('ai_greeting')
          });
        });
      }

      _chat = model.startChat(history: _history);
      print("Đã khởi tạo Bot với Key số ${_currentKeyIndex + 1}");
    } catch (e) {
      print("Lỗi khởi tạo với Key số ${_currentKeyIndex + 1}: $e");
    }
  }

  // Truyền LanguageProvider để lấy thông báo lỗi
  Future<void> _processMessage(LanguageProvider lang) async {
    final message = _textController.text;
    if (message.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': message});
      _loading = true;
      _textController.clear();
    });
    _scrollToBottom();

    String? resultText;
    bool success = false;

    for (int i = 0; i < _apiKeys.length; i++) {
      try {
        print("Đang thử gửi bằng Key số ${_currentKeyIndex + 1}...");

        final currentKey = _apiKeys[_currentKeyIndex];
        final tempModel =
            GenerativeModel(model: _modelName, apiKey: currentKey);

        final tempChat = tempModel.startChat(history: _history);

        final response = await tempChat.sendMessage(Content.text(message));
        resultText = response.text;

        if (resultText != null) {
          print("Thành công với Key số ${_currentKeyIndex + 1}");
          _history.add(Content.text(message));
          _history.add(Content.model([TextPart(resultText)]));
          success = true;
          break;
        }
      } catch (e) {
        print("Key số ${_currentKeyIndex + 1} bị lỗi: $e");
        _currentKeyIndex++;
        if (_currentKeyIndex >= _apiKeys.length) {
          _currentKeyIndex = 0;
        }
      }
    }

    if (!success) {
      // Lấy thông báo lỗi từ ngôn ngữ
      resultText = lang.getText('ai_system_busy');
    }

    setState(() {
      if (resultText != null) {
        _messages.add({'role': 'model', 'text': resultText!});
      }
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe ngôn ngữ
    final lang = Provider.of<LanguageProvider>(context);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarColor =
        isDarkMode ? Colors.lightBlue.shade900 : Colors.lightBlue.shade100;
    final botBubbleColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
    final botTextColor = isDarkMode ? Colors.white : Colors.black87;
    final inputContainerColor =
        isDarkMode ? Colors.grey.shade900 : Colors.white;
    final inputFillColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100;

    return Scaffold(
      appBar: AppBar(
        // Tên Bot theo ngôn ngữ
        title: Text(lang.getText('ai_bot_name')),
        backgroundColor: appBarColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _history.clear();
                _initChatSession(
                    lang); // Reset lại phiên chat với ngôn ngữ hiện tại
              });
            },
          )
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(15),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.lightBlue : botBubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(15),
                          topRight: const Radius.circular(15),
                          bottomLeft: isUser
                              ? const Radius.circular(15)
                              : const Radius.circular(0),
                          bottomRight: isUser
                              ? const Radius.circular(0)
                              : const Radius.circular(15),
                        ),
                      ),
                      child: MarkdownBody(
                        data: msg['text'],
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                              color: isUser ? Colors.white : botTextColor),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(color: Colors.lightBlue)),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: inputContainerColor, boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: const Offset(0, -2))
              ]),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black),
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        // Hint text theo ngôn ngữ
                        hintText: lang.getText('ai_input_hint'),
                        hintStyle: TextStyle(
                            color: isDarkMode
                                ? Colors.grey
                                : Colors.grey.shade600),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: inputFillColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.lightBlue,
                      child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          // Truyền lang vào hàm xử lý
                          onPressed: () => _processMessage(lang)),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}