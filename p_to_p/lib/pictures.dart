import 'package:flutter/material.dart';
import 'package:path/path.dart' as p; // ✅ alias path to avoid Context conflict
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'main.dart'; // to access global cameras list

class PenToPixel extends StatefulWidget {
  const PenToPixel({super.key});

  @override
  State<PenToPixel> createState() => _PenToPixelState();
}

class _PenToPixelState extends State<PenToPixel> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode =
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pen to Pixel',
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown[800]!,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _themeMode,
      home: CameraScreen(
        toggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const CameraScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isLoading = false;
  bool _flashOn = false;
  CameraDescription? _selectedCamera;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _selectedCamera = cameras.first;
      _controller = CameraController(
        _selectedCamera!,
        ResolutionPreset.medium,
      );

      _initializeControllerFuture = _controller.initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> _switchCamera() async {
    if (cameras.length < 2) return;

    setState(() {
      _isLoading = true;
    });

    await _controller.dispose();

    final newCamera =
    _selectedCamera == cameras[0] ? cameras[1] : cameras[0];

    _selectedCamera = newCamera;
    _controller = CameraController(
      _selectedCamera!,
      ResolutionPreset.medium,
    );

    await _controller.initialize();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _toggleFlash() async {
    if (!_controller.value.isInitialized) return;

    setState(() {
      _flashOn = !_flashOn;
    });

    await _controller.setFlashMode(
        _flashOn ? FlashMode.torch : FlashMode.off);
  }

  Future<void> _uploadImage(String imagePath) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ Hugging Face API endpoint
      const apiUrl =
          'https://rnaveenpatil-p-to-p.hf.space/run/predict';

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath(
        'image', // adjust if your HF Space expects "data"
        imagePath,
        filename: 'document_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      var response = await request.send();
      var responseBody = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        final result = jsonDecode(responseBody.body);

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  ResultScreen(resultData: result.toString()),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Upload failed: ${response.statusCode}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;

    if (cameras.isEmpty) {
      return Scaffold(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_rounded,
                  size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('No camera found', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Scanner',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
                widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return CameraPreview(_controller);
              } else {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isDarkMode ? Colors.white : Colors.brown),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Initializing camera...',
                        style: TextStyle(
                            color:
                            isDarkMode ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isDarkMode ? Colors.white : Colors.brown),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Processing...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              heroTag: 'flash_btn',
              onPressed: _toggleFlash,
              backgroundColor:
              isDarkMode ? Colors.grey[800] : Colors.white,
              child: Icon(
                _flashOn ? Icons.flash_on : Icons.flash_off,
                color: isDarkMode ? Colors.white : Colors.brown,
              ),
            ),
            FloatingActionButton(
              heroTag: 'capture_btn',
              onPressed: () async {
                try {
                  await _initializeControllerFuture;

                  final path = p.join(
                    (await getTemporaryDirectory()).path,
                    '${DateTime.now().millisecondsSinceEpoch}.png',
                  );

                  final image = await _controller.takePicture();
                  await image.saveTo(path);

                  if (mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DisplayPictureScreen(
                          imagePath: path,
                          onUpload: _uploadImage,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Error taking picture: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              backgroundColor:
              isDarkMode ? Colors.brown[700] : Colors.brown,
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
            FloatingActionButton(
              heroTag: 'switch_btn',
              onPressed: _switchCamera,
              backgroundColor:
              isDarkMode ? Colors.grey[800] : Colors.white,
              child: Icon(
                Icons.cameraswitch,
                color: isDarkMode ? Colors.white : Colors.brown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;
  final Function(String)? onUpload;
  final bool isDarkMode;

  const DisplayPictureScreen({
    super.key,
    required this.imagePath,
    this.onUpload,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Captured Document'),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          if (onUpload != null)
            IconButton(
              icon: const Icon(Icons.cloud_upload),
              onPressed: () => onUpload!(imagePath),
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                  isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Retake'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                    isDarkMode ? Colors.brown[700] : Colors.brown,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Image saved to gallery')));
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                    isDarkMode ? Colors.grey[700] : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final String resultData;
  const ResultScreen({super.key, required this.resultData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Result")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            resultData,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
