import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

enum DiagnosisMode { offline, online }

class DetectionBox {
  const DetectionBox({
    required this.label,
    required this.confidence,
    required this.yMin,
    required this.xMin,
    required this.yMax,
    required this.xMax,
  });

  final String label;
  final double confidence;
  final double yMin;
  final double xMin;
  final double yMax;
  final double xMax;
}

class DiagnosisResult {
  const DiagnosisResult({
    required this.rawLabel,
    required this.mode,
    this.confidence,
    this.moniliasisDetected,
    this.annotatedImageUrl,
    this.annotatedImageBytes,
    this.detections = const [],
  });

  final String rawLabel;
  final DiagnosisMode mode;
  final double? confidence;
  final bool? moniliasisDetected;
  final String? annotatedImageUrl;
  final Uint8List? annotatedImageBytes;
  final List<DetectionBox> detections;
}

class DiagnosisService {
  static const defaultConfidenceThreshold = 0.25;
  static const defaultIouThreshold = 0.45;

  static const _offlineModelPath = 'assets/modelo_cacao_monilia_ssd.tflite';
  static const _offlineLabelsPath = 'assets/labels_cacao_monilia_ssd.txt';
  static final Uri _spaceBaseUri = Uri.https(
    'bdarquea-cocoa-diseases-localization.hf.space',
  );
  static const _timeout = Duration(seconds: 90);
  static const _offlineInputSize = 320;

  final http.Client _client;
  Interpreter? _offlineInterpreter;
  List<String> _offlineLabels = const [];

  DiagnosisService({http.Client? client}) : _client = client ?? http.Client();

  Future<void> load() async {
    if (_offlineInterpreter != null && _offlineLabels.isNotEmpty) {
      return;
    }

    _offlineInterpreter = await Interpreter.fromAsset(_offlineModelPath);

    final labelsData = await rootBundle.loadString(_offlineLabelsPath);
    _offlineLabels = labelsData
        .split('\n')
        .map((label) => label.replaceFirst(RegExp(r'^\d+\s*'), '').trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);

    if (_offlineLabels.isEmpty) {
      throw Exception('No se encontraron etiquetas para el modelo offline.');
    }
  }

  Future<DiagnosisResult> analyze(
    Uint8List imageBytes, {
    DiagnosisMode mode = DiagnosisMode.offline,
    double confidenceThreshold = defaultConfidenceThreshold,
    double iouThreshold = defaultIouThreshold,
  }) async {
    if (imageBytes.isEmpty) {
      throw Exception('No se pudo leer la imagen seleccionada');
    }

    if (mode == DiagnosisMode.offline) {
      return _analyzeOffline(
        imageBytes,
        confidenceThreshold: confidenceThreshold,
      );
    }

    return _analyzeOnline(
      imageBytes,
      confidenceThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
    );
  }

  Future<DiagnosisResult> _analyzeOffline(
    Uint8List imageBytes, {
    required double confidenceThreshold,
  }) async {
    await load();

    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('No se pudo leer la imagen seleccionada');
    }

    final resized = img.copyResize(
      image,
      width: _offlineInputSize,
      height: _offlineInputSize,
    );
    final input = [
      List.generate(
        _offlineInputSize,
        (y) => List.generate(_offlineInputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    ];

    final scores = [List<double>.filled(10, 0)];
    final boxes = [List.generate(10, (_) => List<double>.filled(4, 0))];
    final numDetections = List<double>.filled(1, 0);
    final classes = [List<double>.filled(10, 0)];

    _offlineInterpreter!.runForMultipleInputs(
      [input],
      {0: scores, 1: boxes, 2: numDetections, 3: classes},
    );

    final detections = <DetectionBox>[];
    final count = numDetections.first.clamp(0, 10).toInt();

    for (var i = 0; i < count; i++) {
      final score = scores.first[i];
      if (score < confidenceThreshold) {
        continue;
      }

      final classIndex = classes.first[i].round();
      final label = classIndex >= 0 && classIndex < _offlineLabels.length
          ? _offlineLabels[classIndex]
          : 'clase $classIndex';
      final box = boxes.first[i];

      detections.add(
        DetectionBox(
          label: label,
          confidence: score,
          yMin: box[0],
          xMin: box[1],
          yMax: box[2],
          xMax: box[3],
        ),
      );
    }

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    final bestDetection = detections.isEmpty ? null : detections.first;
    final moniliaDetections = detections
        .where((detection) => detection.label.toLowerCase().contains('monilia'))
        .toList(growable: false);
    final hasMonilia = moniliaDetections.isNotEmpty;

    return DiagnosisResult(
      mode: DiagnosisMode.offline,
      rawLabel: detections.isEmpty
          ? 'Modelo offline SSD: no hubo detecciones sobre el umbral.'
          : 'Modelo offline SSD: ${detections.map((d) => '${d.label} ${(d.confidence * 100).toStringAsFixed(1)}%').join(', ')}.',
      confidence: hasMonilia
          ? moniliaDetections.first.confidence
          : bestDetection?.confidence,
      moniliasisDetected: hasMonilia,
      detections: detections,
    );
  }

  Future<DiagnosisResult> _analyzeOnline(
    Uint8List imageBytes, {
    required double confidenceThreshold,
    required double iouThreshold,
  }) async {
    final uploadedPath = await _uploadImage(imageBytes);
    final eventId = await _startPrediction(
      uploadedPath,
      confidenceThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
    );
    final annotatedImageUrl = await _waitForPrediction(eventId);
    final annotatedImageBytes = await _downloadAnnotatedImage(
      annotatedImageUrl,
    );

    return DiagnosisResult(
      mode: DiagnosisMode.online,
      rawLabel:
          'Resultado YOLO11n: revisa las cajas y etiquetas sobre la imagen.',
      annotatedImageUrl: annotatedImageUrl,
      annotatedImageBytes: annotatedImageBytes,
    );
  }

  Future<String> _uploadImage(Uint8List imageBytes) async {
    final request =
        http.MultipartRequest('POST', _spaceBaseUri.resolve('/upload'))
          ..files.add(
            http.MultipartFile.fromBytes(
              'files',
              imageBytes,
              filename: 'cacao.jpg',
            ),
          );

    final streamedResponse = await _client.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo subir la imagen a Hugging Face (${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! List || data.isEmpty || data.first is! String) {
      throw Exception(
        'Hugging Face devolvio una respuesta inesperada al subir la imagen.',
      );
    }

    return data.first as String;
  }

  Future<String> _startPrediction(
    String uploadedPath, {
    required double confidenceThreshold,
    required double iouThreshold,
  }) async {
    final response = await _client
        .post(
          _spaceBaseUri.resolve('/call/predict'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'data': [
              {
                'path': uploadedPath,
                'orig_name': 'cacao.jpg',
                'meta': {'_type': 'gradio.FileData'},
              },
              confidenceThreshold,
              iouThreshold,
            ],
          }),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo iniciar el analisis en Hugging Face (${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map || data['event_id'] is! String) {
      throw Exception(
        'Hugging Face no devolvio un identificador de analisis valido.',
      );
    }

    return data['event_id'] as String;
  }

  Future<String> _waitForPrediction(String eventId) async {
    final response = await _client
        .get(_spaceBaseUri.resolve('/call/predict/$eventId'))
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo obtener el resultado de Hugging Face (${response.statusCode}).',
      );
    }

    for (final line in const LineSplitter().convert(response.body)) {
      if (!line.startsWith('data: ')) {
        continue;
      }

      final payload = line.substring('data: '.length).trim();
      final data = jsonDecode(payload);

      if (data is List && data.isNotEmpty && data.first is Map) {
        final output = data.first as Map;
        final path = output['path'];
        if (path is String && path.isNotEmpty) {
          return _spaceBaseUri.resolve('/file=$path').toString();
        }

        final url = output['url'];
        if (url is String && url.isNotEmpty) {
          return url.replaceFirst('/c/file=', '/file=');
        }
      }
    }

    throw Exception('El modelo termino, pero no devolvio una imagen anotada.');
  }

  Future<Uint8List> _downloadAnnotatedImage(String imageUrl) async {
    final response = await _client.get(Uri.parse(imageUrl)).timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'El modelo respondio, pero no se pudo descargar la imagen anotada (${response.statusCode}).',
      );
    }

    if (response.bodyBytes.isEmpty) {
      throw Exception('La imagen anotada llego vacia desde Hugging Face.');
    }

    return response.bodyBytes;
  }

  void dispose() {
    _offlineInterpreter?.close();
    _offlineInterpreter = null;
    _client.close();
  }
}
