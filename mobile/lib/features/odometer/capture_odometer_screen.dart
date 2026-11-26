import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import '../common/widgets.dart';
import 'odometer_capture.dart';
import 'odometer_reader.dart';

/// Takes an odometer photo with the camera (no gallery), reads it with ML Kit,
/// and lets the driver confirm or correct the number.
class CaptureOdometerScreen extends ConsumerStatefulWidget {
  const CaptureOdometerScreen({super.key, required this.title, this.minKm, this.lastKnownKm});

  final String title;

  /// For an end reading: the start km. The value cannot be lower.
  final int? minKm;

  /// The vehicle's last odometer, shown as a hint for start readings.
  final int? lastKnownKm;

  static Future<OdometerCapture?> open(BuildContext context, {required String title, int? minKm, int? lastKnownKm}) =>
      Navigator.of(context).push<OdometerCapture>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CaptureOdometerScreen(title: title, minKm: minKm, lastKnownKm: lastKnownKm),
      ));

  @override
  ConsumerState<CaptureOdometerScreen> createState() => _CaptureOdometerScreenState();
}

class _CaptureOdometerScreenState extends ConsumerState<CaptureOdometerScreen> {
  final _form = GlobalKey<FormState>();
  final _km = TextEditingController();
  final _notes = TextEditingController();
  XFile? _photo;
  DateTime? _capturedAt;
  OdometerOcrResult? _ocr;
  bool _reading = false;
  Future<Position?>? _position;

  @override
  void initState() {
    super.initState();
    _position = _locate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePhoto());
  }

  @override
  void dispose() {
    _km.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<Position?> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
    } catch (_) {
      return null; // location is a nice to have, never block the shift
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (photo == null) return;
      setState(() {
        _photo = photo;
        _capturedAt = DateTime.now();
        _ocr = null;
        _reading = true;
      });
      final result = await ref.read(odometerReaderProvider).read(photo.path);
      if (!mounted) return;
      setState(() {
        _ocr = result;
        _reading = false;
        _km.text = result.km?.toString() ?? '';
      });
    } on PlatformException {
      if (mounted) showMessage(context, context.l10n.cameraNeeded, error: true);
    } catch (_) {
      // OCR failed: the driver types the number in.
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _confirm() async {
    if (!_form.currentState!.validate()) return;
    final l = context.l10n;
    final value = int.parse(_km.text.trim());
    if (widget.minKm != null && value - widget.minKm! > AppConfig.maxKmPerShift) {
      final ok = await confirmDialog(context,
          title: l.bigJumpTitle, message: l.bigJumpMessage(Fmt.of(context).number(value - widget.minKm!)));
      if (!ok || !mounted) return;
    }
    final pos = await _position;
    if (!mounted) return;
    Navigator.of(context).pop(OdometerCapture(
      photoPath: _photo!.path,
      confirmedKm: value,
      ocrKm: _ocr?.km,
      ocrConfidence: _ocr?.confidence,
      capturedAt: _capturedAt!,
      latitude: pos?.latitude,
      longitude: pos?.longitude,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final scheme = Theme.of(context).colorScheme;
    final typed = int.tryParse(_km.text.trim());
    final edited = _ocr?.km != null && typed != null && typed != _ocr!.km;
    final lowConfidence = (_ocr?.confidence ?? 1) < AppConfig.minOcrConfidence;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (_photo == null) ...[
              const SizedBox(height: 24),
              Icon(Icons.speed, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text(l.photoHint, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.photo_camera), label: Text(l.takePhoto)),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_photo!.path), height: 260, fit: BoxFit.cover),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.refresh), label: Text(l.retakePhoto)),
              ),
              if (_reading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text(l.readingPhoto),
                  ]),
                )
              else ...[
                if (_ocr?.km == null)
                  _Notice(icon: Icons.warning_amber, text: l.noReadingFound, color: scheme.errorContainer)
                else if (lowConfidence)
                  _Notice(icon: Icons.warning_amber, text: l.lowConfidence, color: scheme.tertiaryContainer)
                else
                  _Notice(icon: Icons.info_outline, text: l.checkReading, color: scheme.secondaryContainer),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _km,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 2),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: l.kmReading,
                    border: const OutlineInputBorder(),
                    helperText: widget.minKm != null
                        ? l.kmTooLow(f.number(widget.minKm!))
                        : widget.lastKnownKm != null
                            ? l.lastOdometer(f.km(widget.lastKnownKm))
                            : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (v == null || v.trim().isEmpty) return l.required;
                    if (n == null) return l.kmInvalid;
                    if (widget.minKm != null && n < widget.minKm!) return l.kmTooLow(f.number(widget.minKm!));
                    return null;
                  },
                ),
                if (edited) ...[
                  const SizedBox(height: 8),
                  Text(l.editedWarning, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: l.notesOptional, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check),
                  label: Text(l.confirm),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Text(text))]),
      );
}
