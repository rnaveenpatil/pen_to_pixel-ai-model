import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'display.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  double _currentZoomLevel = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  FlashMode _currentFlashMode = FlashMode.off;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        // Use only the back camera (first camera in the list)
        await _initializeCameraController(_cameras!.first);
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _initializeCameraController(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
    );

    try {
      await _controller!.initialize();

      // Get zoom capabilities
      _minAvailableZoom = await _controller!.getMinZoomLevel();
      _maxAvailableZoom = await _controller!.getMaxZoomLevel();

      // Set initial flash mode
      _currentFlashMode = _controller!.value.flashMode;

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Controller error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (!_isCameraInitialized) return;

    FlashMode newFlashMode;
    switch (_currentFlashMode) {
      case FlashMode.off:
        newFlashMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        newFlashMode = FlashMode.always;
        break;
      case FlashMode.always:
        newFlashMode = FlashMode.off;
        break;
      case FlashMode.torch:
        newFlashMode = FlashMode.off;
        break;
    }

    try {
      await _controller!.setFlashMode(newFlashMode);
      setState(() {
        _currentFlashMode = newFlashMode;
      });
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  void _updateZoom(double zoomLevel) {
    if (!_isCameraInitialized) return;

    setState(() {
      _currentZoomLevel = zoomLevel.clamp(_minAvailableZoom, _maxAvailableZoom);
    });

    _controller!.setZoomLevel(_currentZoomLevel);
  }

  Future<void> _takePicture() async {
    if (!_isCameraInitialized || _isRecording) return;

    setState(() {
      _isRecording = true;
    });

    try {
      final XFile picture = await _controller!.takePicture();
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DisplayPage(imagePath: picture.path),
        ),
      );
    } catch (e) {
      debugPrint('Picture error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DisplayPage(imagePath: image.path),
          ),
        );
      }
    } catch (e) {
      debugPrint('Gallery error: $e');
    }
  }

  IconData _getFlashIcon() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.highlight;
    }
  }

  Color _getFlashColor() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return Colors.white;
      case FlashMode.auto:
        return Colors.amber;
      case FlashMode.always:
        return Colors.yellow;
      case FlashMode.torch:
        return Colors.orange;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Full screen camera preview
            if (_isCameraInitialized)
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CameraPreview(_controller!),
              )
            else
              Container(
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 20),
                      Text('Initializing Camera...',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              ),

            // Top controls
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Flash button
                  CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(_getFlashIcon(), color: _getFlashColor()),
                    ),
                  ),

                  // Camera mode indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'PHOTO',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Empty container to maintain spacing (replaces camera switch button)
                  const CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.flip_camera_ios, color: Colors.transparent),
                  ),
                ],
              ),
            ),

            // Zoom slider
            if (_isCameraInitialized && _maxAvailableZoom > 1.0)
              Positioned(
                right: 20,
                top: MediaQuery.of(context).size.height / 2 - 100,
                child: Container(
                  height: 200,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: _currentZoomLevel,
                      min: _minAvailableZoom,
                      max: _maxAvailableZoom,
                      onChanged: _updateZoom,
                      activeColor: Colors.white,
                      inactiveColor: Colors.white30,
                    ),
                  ),
                ),
              ),

            // Zoom level indicator
            if (_isCameraInitialized && _maxAvailableZoom > 1.0)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _currentZoomLevel > 1.0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentZoomLevel.toStringAsFixed(1)}x',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),

            // Floating square in center
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Zoom text indicator
                  if (_isCameraInitialized && _maxAvailableZoom > 1.0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        'Pinch to zoom • ${_currentZoomLevel.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery button
                      _buildControlButton(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        onPressed: _pickImageFromGallery,
                      ),

                      // Shutter button
                      GestureDetector(
                        onTap: _isRecording ? null : _takePicture,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isRecording ? 60 : 80,
                          height: _isRecording ? 60 : 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecording ? Colors.red : Colors.white,
                              width: _isRecording ? 3 : 4,
                            ),
                            gradient: _isRecording
                                ? const LinearGradient(
                              colors: [Colors.red, Colors.orange],
                            )
                                : const LinearGradient(
                              colors: [Colors.white, Colors.grey],
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording ? Colors.red : Colors.white,
                            ),
                            child: _isRecording
                                ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            )
                                : null,
                          ),
                        ),
                      ),

                      // Empty placeholder to maintain layout balance
                      _buildControlButton(
                        icon: Icons.camera,
                        label: 'Camera',
                        onPressed: () {}, // Empty function
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: Colors.black54,
          radius: 28,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}