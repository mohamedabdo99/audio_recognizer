import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SoundClassifier extends StatefulWidget {
  const SoundClassifier({super.key});

  @override
  _SoundClassifierState createState() => _SoundClassifierState();
}

class _SoundClassifierState extends State<SoundClassifier> {
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String _predictedLabel = "اضغط للتسجيل";
  String? _filePath;
  Interpreter? _interpreter;
  List<String> labels = [];

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _loadModel();
    _loadLabels();
  }

  /// 🔵 تحميل نموذج الذكاء الصناعي
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        "assets/tft/soundclassifier_with_metadata.tflite",
      );
      print("✅ تم تحميل النموذج بنجاح");
    } catch (e) {
      print("⚠️ خطأ أثناء تحميل النموذج: $e");
    }
  }

  /// 🔵 تحميل أسماء التصنيفات
  Future<void> _loadLabels() async {
    try {
      String labelData = await DefaultAssetBundle.of(context).loadString(
        "assets/tft/labels.txt",
      );
      labels = labelData.split('\n').map((e) => e.trim()).toList();
      print("✅ تم تحميل التصنيفات: $labels");
    } catch (e) {
      print("⚠️ خطأ أثناء تحميل التصنيفات: $e");
    }
  }

  /// 🔵 تهيئة المسجل والتحقق من الأذونات
  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print("⚠️ إذن الميكروفون غير ممنوح!");
    }
  }

  /// 🔵 بدء تسجيل الصوت
  Future<void> _startRecording() async {
    if (!_isRecording) {
      Directory tempDir = await getTemporaryDirectory();
      _filePath = "${tempDir.path}/temp_audio.wav";

      await _recorder!.startRecorder(
        toFile: _filePath!,
        codec: Codec.pcm16WAV,
      );

      setState(() {
        _isRecording = true;
        _predictedLabel = "جارٍ التسجيل...";
      });
    }
  }

  /// 🔵 إيقاف التسجيل وتحليل الصوت
  Future<void> _stopRecording() async {
    if (_isRecording) {
      await _recorder!.stopRecorder();

      setState(() {
        _isRecording = false;
        _predictedLabel = "جاري تحليل الصوت...";
      });

      if (_filePath != null) {
        _predictSound(File(_filePath!));
      }
    }
  }

  /// 🔵 تحليل الصوت باستخدام النموذج
  Future<void> _predictSound(File audioFile) async {
    try {
      Uint8List audioBytes = await audioFile.readAsBytes();
      List<int> inputBuffer = audioBytes.map((byte) => byte.toInt()).toList();

      // تحويل البيانات إلى Float32List (للتطبيع من -1 إلى 1)
      Float32List floatBuffer = Float32List.fromList(
        inputBuffer.map((byte) => byte / 32768.0).toList(),
      );

      // تجهيز البيانات للنموذج
      var input = [floatBuffer.buffer.asFloat32List()];
      var output = List.filled(labels.length, 0.0).reshape([1, labels.length]);

      _interpreter!.run(input, output);

      // العثور على أعلى تصنيف
      int maxIndex = output[0].indexWhere(
        (element) => element == output[0].reduce((a, b) => a > b ? a : b),
      );

      setState(() {
        _predictedLabel = "تم التعرف على: ${labels[maxIndex]}";
      });

      print("✅ التصنيف: ${labels[maxIndex]}");
    } catch (e) {
      print("⚠️ خطأ أثناء تحليل الصوت: $e");
      setState(() {
        _predictedLabel = "خطأ في تحليل الصوت!";
      });
    }
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("التعرف على الصوت")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_predictedLabel, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? "إيقاف التسجيل" : "ابدأ التسجيل"),
            ),
          ],
        ),
      ),
    );
  }
}
