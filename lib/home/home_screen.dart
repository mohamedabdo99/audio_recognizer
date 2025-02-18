import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class SoundClassifier extends StatefulWidget {
  const SoundClassifier({super.key});

  @override
  _SoundClassifierState createState() => _SoundClassifierState();
}

class _SoundClassifierState extends State<SoundClassifier> {
  Interpreter? _interpreter;
  List<String> labels = [];
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String _predictedLabel = "اضغط للتسجيل";

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadLabels();
    _initRecorder();
  }

  Future<void> _loadModel() async {
    try {
      final interpreterOptions = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset(
        'assets/soundclassifier_with_metadata.tflite',
        options: interpreterOptions,
      );
      print("تم تحميل النموذج بنجاح");
    } catch (e) {
      print("خطأ في تحميل النموذج: $e");
    }
  }

  Future<void> _loadLabels() async {
    try {
      String labelData =
          await DefaultAssetBundle.of(context).loadString('assets/labels.txt');
      labels = labelData.split('\n').map((e) => e.trim()).toList();
      print("تم تحميل التصنيفات: $labels");
    } catch (e) {
      print("خطأ في تحميل التصنيفات: $e");
    }
  }

  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    await Permission.microphone.request();
  }

  Future<void> _startRecording() async {
    if (!_isRecording) {
      await _recorder!.startRecorder(
        toFile: 'temp_audio.wav',
        codec: Codec.pcm16WAV,
      );
      setState(() {
        _isRecording = true;
        _predictedLabel = "جارٍ التسجيل...";
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_isRecording) {
      String? path = await _recorder!.stopRecorder();
      setState(() {
        _isRecording = false;
        _predictedLabel = "جاري تحليل الصوت...";
      });

      if (path != null) {
        _predictSound(File(path));
      }
    }
  }

  Future<void> _predictSound(File audioFile) async {
    try {
      // تحميل بيانات الصوت وتحويلها إلى مصفوفة
      Uint8List audioBytes = await audioFile.readAsBytes();
      List<int> inputBuffer = audioBytes.map((byte) => byte.toInt()).toList();
      var input = [inputBuffer];

      // تجهيز مصفوفة الإخراج
      var output = List.filled(labels.length, 0.0).reshape([1, labels.length]);

      // تشغيل النموذج
      _interpreter!.run(input, output);

      // الحصول على أعلى قيمة في التصنيفات
      int maxIndex = output[0].indexWhere(
          (element) => element == output[0].reduce((a, b) => a > b ? a : b));
      setState(() {
        _predictedLabel = "تم التعرف على: ${labels[maxIndex]}";
      });

      print("التصنيف: ${labels[maxIndex]}");
    } catch (e) {
      print("خطأ أثناء تحليل الصوت: $e");
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    _recorder?.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("التعرف علي الصوت")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_predictedLabel, style: TextStyle(fontSize: 20)),
            SizedBox(height: 20),
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
