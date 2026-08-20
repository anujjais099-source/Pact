import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/pact_button.dart';
import '../../core/widgets/pact_loader.dart';
import '../../state/checkin_controller.dart';
import '../../state/providers.dart';
import 'checkin_success_screen.dart';

/// Proof, not promises: the device camera opens directly and there is no path
/// to the gallery anywhere in this screen. That constraint is the product.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  String? _error;
  bool _busy = false;
  File? _captured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// Android tears the camera away when the app backgrounds; rebuild on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'No camera found on this device.');
        return;
      }
      // Back camera first: most goals are things in the world, not selfies.
      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _bind(_cameras[_cameraIndex]);
    } on CameraException catch (e) {
      setState(() => _error = _readable(e));
    }
  }

  Future<void> _bind(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (e) {
      setState(() => _error = _readable(e));
    }
  }

  String _readable(CameraException e) => switch (e.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' =>
          'Pact needs the camera. Enable it in Settings to check in.',
        'CameraAccessRestricted' => 'Camera access is restricted on this device.',
        _ => e.description ?? 'The camera would not open.',
      };

  Future<void> _flip() async {
    if (_cameras.length < 2 || _busy) return;
    setState(() => _busy = true);
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _controller?.dispose();
    await _bind(_cameras[_cameraIndex]);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;

    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final shot = await controller.takePicture();
      if (!mounted) return;
      setState(() => _captured = File(shot.path));
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = _readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final photo = _captured;
    if (photo == null) return;

    final ok = await ref.read(checkInControllerProvider.notifier).submit(photo);
    if (!mounted) return;

    if (ok) {
      final state = ref.read(checkInControllerProvider);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CheckInSuccessScreen(
            streak: state.streak,
            bothGreen: state.bothGreen,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pact = ref.watch(currentPactProvider).value;
    final left = ref.watch(deadlineProvider).value ?? Duration.zero;
    final checkIn = ref.watch(checkInControllerProvider);
    final partnerName = pact == null
        ? 'your partner'
        : pact.partnerOf(ref.watch(currentUidProvider) ?? '').username;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_captured != null)
            Image.file(_captured!, fit: BoxFit.cover)
          else if (_controller?.value.isInitialized ?? false)
            _Preview(controller: _controller!)
          else
            const ColoredBox(color: Colors.black),

          // Top: who this is for and how long is left.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopOverlay(
              partnerName: partnerName,
              left: left,
              onClose: () => context.pop(),
            ),
          ),

          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PactError(message: _error!, onRetry: _start),
              ),
            ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(
              captured: _captured != null,
              busy: _busy,
              uploading: checkIn.busy,
              error: checkIn.error,
              canFlip: _cameras.length > 1,
              onCapture: _capture,
              onFlip: _flip,
              onRetake: () => setState(() => _captured = null),
              onSubmit: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fills the screen without distorting the sensor's aspect ratio.
class _Preview extends StatelessWidget {
  const _Preview({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.width * controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _TopOverlay extends StatelessWidget {
  const _TopOverlay({
    required this.partnerName,
    required this.left,
    required this.onClose,
  });

  final String partnerName;
  final Duration left;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Proof of today',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$partnerName will see this · ${Fmt.countdown(left)} left',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.captured,
    required this.busy,
    required this.uploading,
    required this.error,
    required this.canFlip,
    required this.onCapture,
    required this.onFlip,
    required this.onRetake,
    required this.onSubmit,
  });

  final bool captured;
  final bool busy;
  final bool uploading;
  final String? error;
  final bool canFlip;
  final VoidCallback onCapture;
  final VoidCallback onFlip;
  final VoidCallback onRetake;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xE6000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null) ...[
              PactError(message: error!),
              const SizedBox(height: 14),
            ],
            if (captured)
              Row(
                children: [
                  Expanded(
                    child: PactButton(
                      label: 'Retake',
                      style: PactButtonStyle.secondary,
                      onPressed: uploading ? null : onRetake,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: PactButton(
                      label: 'Submit proof',
                      loading: uploading,
                      onPressed: onSubmit,
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 52),
                  _Shutter(busy: busy, onTap: onCapture),
                  SizedBox(
                    width: 52,
                    child: canFlip
                        ? IconButton(
                            onPressed: onFlip,
                            icon: const Icon(
                              Icons.cameraswitch_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            const SizedBox(height: 10),
            const Text(
              'Live camera only. No uploads from your gallery.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 78,
        width: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: busy ? Colors.white24 : Colors.transparent,
        ),
        child: Center(
          child: Container(
            height: busy ? 30 : 58,
            width: busy ? 30 : 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
