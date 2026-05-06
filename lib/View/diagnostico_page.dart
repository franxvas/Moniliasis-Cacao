import 'dart:typed_data';

import 'package:amgeca/providers/auth_provider.dart';
import 'package:amgeca/services/diagnosis_service.dart';
import 'package:amgeca/services/image_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class DiagnosticoPage extends StatefulWidget {
  const DiagnosticoPage({super.key});

  @override
  State<DiagnosticoPage> createState() => _DiagnosticoPageState();
}

class _DiagnosticoPageState extends State<DiagnosticoPage> {
  final ImageService _imageService = ImageService();
  final DiagnosisService _diagnosisService = DiagnosisService();

  XFile? _selectedImage;
  DiagnosisResult? _result;
  bool _isModelLoading = true;
  bool _isAnalyzing = false;
  bool _useOnlineModel = false;
  double _confidenceThreshold = DiagnosisService.defaultConfidenceThreshold;
  double _iouThreshold = DiagnosisService.defaultIouThreshold;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    _diagnosisService.dispose();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      await _diagnosisService.load();
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          _isModelLoading = false;
        });
      }
    }
  }

  Future<void> _selectImage(Future<XFile?> Function() picker) async {
    final image = await picker();

    if (!mounted || image == null) {
      return;
    }

    setState(() {
      _selectedImage = image;
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _analyzeImage() async {
    final image = _selectedImage;
    if (image == null) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      final result = await _diagnosisService.analyze(
        bytes,
        mode: _useOnlineModel ? DiagnosisMode.online : DiagnosisMode.offline,
        confidenceThreshold: _confidenceThreshold,
        iouThreshold: _iouThreshold,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _showDetectionSettingsHelp() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ayuda de sensibilidad'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _useOnlineModel
                      ? 'Modo online: YOLO11n de Hugging Face'
                      : 'Modo offline: TFLite SSD local',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Confidence es el umbral mínimo para aceptar una detección.',
                ),
                const SizedBox(height: 8),
                const Text('0.20 - 0.30 = sensible, detecta más.'),
                const Text('0.40 - 0.60 = más estricto, detecta menos.'),
                const SizedBox(height: 12),
                if (_useOnlineModel) ...[
                  const Text(
                    'IoU controla cuánto se pueden parecer o superponer dos cajas antes de eliminar duplicados.',
                  ),
                  const SizedBox(height: 8),
                  const Text('IoU bajo = elimina más cajas duplicadas.'),
                  const Text('IoU alto = permite más cajas parecidas.'),
                  const SizedBox(height: 12),
                  const Text('Recomendado online: Confidence 0.25 e IoU 0.45.'),
                ] else ...[
                  const Text(
                    'En offline puedes ajustar Confidence. El IoU no se puede mover desde la app porque el TFLite ya trae el postprocesamiento/NMS dentro del modelo.',
                  ),
                  const SizedBox(height: 12),
                  const Text('Recomendado offline: Confidence 0.25.'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetectionSettingsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sensibilidad del modelo',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Ver ayuda',
                  onPressed: _showDetectionSettingsHelp,
                  icon: const Icon(Icons.info_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _useOnlineModel
                  ? 'Online: ajusta Confidence e IoU.'
                  : 'Offline: ajusta Confidence. IoU está fijo en el TFLite.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            _buildThresholdSlider(
              label: 'Confidence',
              value: _confidenceThreshold,
              min: 0.05,
              max: 0.80,
              divisions: 75,
              onChanged: _isAnalyzing
                  ? null
                  : (value) {
                      setState(() {
                        _confidenceThreshold = value;
                        _result = null;
                        _errorMessage = null;
                      });
                    },
            ),
            _buildThresholdSlider(
              label: 'IoU',
              value: _iouThreshold,
              min: 0.10,
              max: 0.90,
              divisions: 80,
              onChanged: !_useOnlineModel || _isAnalyzing
                  ? null
                  : (value) {
                      setState(() {
                        _iouThreshold = value;
                        _result = null;
                        _errorMessage = null;
                      });
                    },
              helperText: _useOnlineModel
                  ? null
                  : 'No ajustable en offline: el TFLite ya trae IoU/NMS fijo.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double>? onChanged,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(value.toStringAsFixed(2)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              helperText,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName =
        context.watch<AuthProvider>().user?['nombre'] as String? ?? 'Usuario';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detección de moniliasis en cacao'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, $userName',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _useOnlineModel
                                ? 'Carga una imagen del fruto de cacao y ejecuta el análisis online con el modelo YOLO11n de Hugging Face.'
                                : 'Carga una imagen del fruto de cacao y ejecuta el análisis offline con el modelo TFLite local.',
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                _isModelLoading
                                    ? Icons.hourglass_bottom
                                    : Icons.check_circle,
                                color: _isModelLoading
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isModelLoading
                                    ? 'Preparando modelo offline...'
                                    : _useOnlineModel
                                    ? 'Modo online: requiere internet'
                                    : 'Modo offline listo',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _useOnlineModel,
                            onChanged: _isAnalyzing
                                ? null
                                : (value) {
                                    setState(() {
                                      _useOnlineModel = value;
                                      _result = null;
                                      _errorMessage = null;
                                    });
                                  },
                            title: Text(
                              _useOnlineModel
                                  ? 'Usar modelo online'
                                  : 'Usar modelo offline',
                            ),
                            subtitle: Text(
                              _useOnlineModel
                                  ? 'Hugging Face YOLO11n, necesita internet.'
                                  : 'TFLite local, abre por defecto sin internet.',
                            ),
                            secondary: Icon(
                              _useOnlineModel
                                  ? Icons.cloud_outlined
                                  : Icons.offline_bolt_outlined,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetectionSettingsCard(context),
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      height: 320,
                      color: const Color(0xFFF0F4EB),
                      child: _selectedImage == null
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.photo_camera_back_outlined,
                                    size: 72,
                                    color: Colors.black38,
                                  ),
                                  SizedBox(height: 12),
                                  Text('Aún no has seleccionado una imagen'),
                                ],
                              ),
                            )
                          : FutureBuilder<Uint8List>(
                              future: _selectedImage!.readAsBytes(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isModelLoading || _isAnalyzing
                              ? null
                              : () => _selectImage(_imageService.takePhoto),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Tomar foto'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isModelLoading || _isAnalyzing
                              ? null
                              : () =>
                                    _selectImage(_imageService.pickFromGallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Elegir de galería'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        _selectedImage == null ||
                            _isModelLoading ||
                            _isAnalyzing
                        ? null
                        : _analyzeImage,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.analytics_outlined),
                    label: Text(_isAnalyzing ? 'Analizando...' : 'Analizar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    ),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: _result!.moniliasisDetected == null
                          ? const Color(0xFFFFF8E1)
                          : _result!.moniliasisDetected!
                          ? const Color(0xFFFFF0EE)
                          : const Color(0xFFEDF7ED),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _result!.moniliasisDetected == null
                                  ? 'Resultado del modelo'
                                  : _result!.moniliasisDetected!
                                  ? 'Moniliasis detectada'
                                  : 'No se detecta moniliasis',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _result!.moniliasisDetected == null
                                        ? const Color(0xFF4E342E)
                                        : _result!.moniliasisDetected!
                                        ? const Color(0xFFB3261E)
                                        : const Color(0xFF2E7D32),
                                  ),
                            ),
                            if (_result!.confidence != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Confianza: ${(_result!.confidence! * 100).toStringAsFixed(1)}%',
                              ),
                            ],
                            if (_result!.annotatedImageBytes != null) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _result!.annotatedImageBytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(_result!.rawLabel),
                            if (_result!.detections.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Detecciones offline',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              ..._result!.detections.map(
                                (detection) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${detection.label}: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              _result!.mode == DiagnosisMode.online
                                  ? 'Nota: este Space devuelve una imagen con cajas y etiquetas, Si aparece "moniliophthora roreri/perniciosa" en una caja, corresponde a moniliasis.'
                                  : 'Nota: el modo offline usa el TFLite local con clases healthy, monilia y phytophthora.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
