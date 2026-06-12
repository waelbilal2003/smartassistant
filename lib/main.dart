import 'dart:io';
import 'package:flutter/material.dart';
import 'package:llamadart/llamadart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المساعد الذكي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // فرض اتجاه RTL لكامل التطبيق
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // المسار الثابت لمجلد التطبيق الخاص (لا يحتاج إذن، ولا حزمة path_provider)
  static const String _modelPath =
      '/data/data/com.example.smart_assistant/files/Qwen3-4B-Q4_K_M.gguf';

  // محرّك llamadart
  final LlamaEngine _engine = LlamaEngine(LlamaBackend());

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_Message> _messages = [];
  bool _modelLoaded = false;
  bool _busy = false;
  String _status = 'النموذج غير محمّل';
  String _streamingText = '';

  @override
  void dispose() {
    // تحرير موارد المحرّك الأصلية — مهم جداً لتفادي تسرّب الذاكرة
    _engine.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // فحص الملف بصرياً: يتأكد من وجوده وحجمه قبل محاولة التحميل
  Future<void> _checkFile() async {
    setState(() {
      _busy = true;
      _status = 'جارٍ فحص الملف…';
    });
    try {
      final file = File(_modelPath);
      final exists = await file.exists();
      if (!exists) {
        debugPrint('المسار الذي يبحث فيه التطبيق: $_modelPath');
        setState(() => _status = 'الملف غير موجود في المسار!');
        return;
      }
      final size = await file.length();
      setState(
        () => _status = 'الملف موجود ✓ الحجم: ${size ~/ 1024 ~/ 1024} MB',
      );
    } catch (e) {
      setState(() => _status = 'خطأ: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _loadModel() async {
    setState(() {
      _busy = true;
      _status = 'جارٍ التحقق من الملف…';
    });
    try {
      // 1) التأكد من وجود الملف وسلامة حجمه قبل أي محاولة تحميل
      final file = File(_modelPath);
      if (!await file.exists()) {
        setState(() => _status = 'الملف غير موجود في المسار!');
        return;
      }
      final size = await file.length();
      if (size < 100 * 1024 * 1024) {
        setState(
          () => _status = 'الملف ناقص! الحجم: ${size ~/ 1024 ~/ 1024} MB',
        );
        return;
      }

      // 2) تحميل النموذج مع إجبار CPU صراحةً.
      //    Mali-G52 + Vulkan = بطء وحرارة بلا فائدة، فنعطّل GPU تماماً.
      //    التوثيق: وضع CPU يتحقق عندما يكون gpuLayers == 0.
      setState(() => _status = 'جارٍ تحميل النموذج…');
      await _engine.loadModel(
        _modelPath,
        modelParams: const ModelParams(contextSize: 1024, gpuLayers: 0),
      );

      setState(() {
        _modelLoaded = true;
        _status = 'النموذج جاهز ✓';
      });
    } catch (e) {
      setState(() => _status = 'فشل التحميل: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || !_modelLoaded || _busy) return;

    setState(() {
      _messages.add(_Message(role: 'user', content: text));
      _inputController.clear();
      _busy = true;
      _streamingText = '';
    });
    _scrollToBottom();

    try {
      // نبني الـ prompt بقالب ChatML الذي يفهمه Qwen3، مع /no_think لإيقاف التفكير.
      // llamadart يطبّق قالب النموذج المدمج، لكن تمرير بنية ChatML صريحة أضمن.
      final buffer = StringBuffer();
      buffer.writeln('<|im_start|>system');
      buffer.writeln(
        'أنت مساعد ذكي يجيب باللغة العربية بإيجاز ووضوح ودقة. /no_think',
      );
      buffer.writeln('<|im_end|>');
      for (final m in _messages) {
        buffer.writeln('<|im_start|>${m.role}');
        buffer.writeln(m.content);
        buffer.writeln('<|im_end|>');
      }
      buffer.writeln('<|im_start|>assistant');

      // GenerationParams في llamadart: نستخدم الحقول المؤكدة فقط (maxTokens).
      // إعدادات العيّنة الدقيقة يديرها المحرّك/القالب المدمج لـ Qwen3.
      final stream = _engine.generate(
        buffer.toString(),
        params: const GenerationParams(maxTokens: 512),
      );

      await for (final token in stream) {
        setState(() => _streamingText += token);
        _scrollToBottom();
      }

      // انتهى البثّ — ثبّت الرد في قائمة الرسائل
      setState(() {
        _messages.add(_Message(role: 'assistant', content: _streamingText));
        _streamingText = '';
        _busy = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _status = 'خطأ في التوليد: $e';
        if (_streamingText.isNotEmpty) {
          _messages.add(_Message(role: 'assistant', content: _streamingText));
          _streamingText = '';
        }
        _busy = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المساعد الذكي'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: SizedBox(
                width: 150,
                child: Text(
                  _status,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_modelLoaded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _checkFile,
                      icon: const Icon(Icons.fact_check),
                      label: const Text('فحص الملف'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _loadModel,
                      icon: const Icon(Icons.download),
                      label: Text(_busy ? 'جارٍ التحميل…' : 'تحميل النموذج'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_streamingText.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _streamingText.isNotEmpty) {
                  return _bubble('assistant', _streamingText);
                }
                final m = _messages[index];
                return _bubble(m.role, m.content);
              },
            ),
          ),
          if (_modelLoaded)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك…',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_busy ? Icons.hourglass_top : Icons.send),
                    onPressed: _busy ? null : _send,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bubble(String role, String content) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.teal.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(content),
      ),
    );
  }
}

class _Message {
  final String role;
  final String content;
  _Message({required this.role, required this.content});
}
