import 'dart:async';
import 'package:flutter/material.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مساعد ذكي محلي',
      locale: const Locale('ar'),
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: const ChatPage(),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final LlamaController _controller = LlamaController();
  final TextEditingController _input = TextEditingController();
  final List<_Msg> _messages = [];

  StreamSubscription? _sub; // للاشتراك في تدفّق الرموز، ولإلغائه

  bool _modelLoaded = false;
  bool _busy = false;
  String _status = 'لم يُحمّل النموذج بعد';

  // عدّل المسار حسب مكان النموذج على هاتفك
  static const String _modelPath =
      '/storage/emulated/0/Download/Qwen3-0.6B-Q4_K_M.gguf';

  Future<void> _loadModel() async {
    setState(() {
      _busy = true;
      _status = 'جارٍ تحميل النموذج…';
    });
    try {
      // فحص الجهاز (لفكرة التبديل التلقائي مستقبلاً)
      final gpu = await _controller.detectGpu();
      debugPrint(
        'الجهاز: ${gpu.gpuName} | '
        'RAM حرة: ${gpu.freeRamBytes ~/ 1024 ~/ 1024} MB | '
        'طبقات موصى بها: ${gpu.recommendedGpuLayers}',
      );

      await _controller.loadModel(
        modelPath: _modelPath,
        threads: 4,
        contextSize: 2048,
        gpuLayers: gpu.recommendedGpuLayers, // 0=CPU, 16=جزئي, 99=كامل
      );

      setState(() {
        _modelLoaded = true;
        _status = 'النموذج جاهز ✓ (${gpu.gpuName})';
      });
    } catch (e) {
      setState(() => _status = 'فشل التحميل: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || !_modelLoaded || _busy) return;

    setState(() {
      _messages.add(_Msg(text, true));
      _messages.add(_Msg('', false)); // رد فارغ يُملأ رمزاً برمز
      _busy = true;
      _input.clear();
    });

    final botIndex = _messages.length - 1;

    // generateChat تطبّق قالب المحادثة الصحيح تلقائياً (chatml لـ Qwen)
    _sub = _controller
        .generateChat(
          messages: [
            ChatMessage(
              role: 'system',
              content: 'أنت مساعد ذكي تجيب بالعربية بإيجاز ووضوح.',
            ),
            ChatMessage(role: 'user', content: text),
          ],
          template: 'chatml', // قالب Qwen
          temperature: 0.7,
          maxTokens: 200,
        )
        .listen(
          (token) {
            // كل رمز يصل يُضاف فوراً (بث حي)
            setState(() => _messages[botIndex].text += token);
          },
          onDone: () {
            setState(() => _busy = false);
          },
          onError: (e) {
            setState(() {
              _messages[botIndex].text = 'خطأ: $e';
              _busy = false;
            });
          },
        );
  }

  Future<void> _stop() async {
    await _controller.stop();
    await _sub?.cancel();
    setState(() => _busy = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مساعد ذكي محلي')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.indigo.shade50,
            padding: const EdgeInsets.all(8),
            child: Text(_status, textAlign: TextAlign.center),
          ),
          if (!_modelLoaded)
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton(
                onPressed: _busy ? null : _loadModel,
                child: Text(_busy ? 'جارٍ التحميل…' : 'تحميل النموذج'),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Align(
                  alignment: m.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m.isUser ? Colors.indigo : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.text.isEmpty ? '…' : m.text,
                      style: TextStyle(
                        color: m.isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: _modelLoaded && !_busy,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالتك…',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                // زر إرسال أو إيقاف حسب الحالة
                IconButton(
                  icon: Icon(_busy ? Icons.stop : Icons.send),
                  onPressed: !_modelLoaded ? null : (_busy ? _stop : _send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  String text;
  final bool isUser;
  _Msg(this.text, this.isUser);
}
