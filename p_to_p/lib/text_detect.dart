import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

class TextDetectPage extends StatefulWidget {
  final String imagePath;

  const TextDetectPage({super.key, required this.imagePath});

  @override
  State<TextDetectPage> createState() => _TextDetectPageState();
}

class _TextDetectPageState extends State<TextDetectPage> {
  bool _isProcessing = false;
  String _detectedText = '';
  String _structuredOutput = '';
  Uint8List? _originalImageBytes;
  Uint8List? _processedImageBytes; // Added for processed image
  String _errorMessage = '';
  List<Map<String, dynamic>> _detectedLines = [];

  // OCR.space API configuration
  final String _apiKey = "helloworld";
  final String _apiUrl = "https://api.ocr.space/parse/image";

  @override
  void initState() {
    super.initState();
    _loadOriginalImage();
  }

  void _loadOriginalImage() {
    try {
      _originalImageBytes = File(widget.imagePath).readAsBytesSync();
    } catch (e) {
      print('Error loading original image: $e');
    }
  }

  Future<void> _callTextDetectionAPI() async {
    setState(() {
      _isProcessing = true;
      _detectedText = '';
      _structuredOutput = '';
      _detectedLines = [];
      _errorMessage = '';
      _processedImageBytes = null; // Reset processed image
    });

    try {
      // Prepare multipart request
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));

      // Add API parameters
      request.fields['apikey'] = _apiKey;
      request.fields['OCREngine'] = '2';
      request.fields['isOverlayRequired'] = 'true';
      request.fields['scale'] = 'true';

      // Add image file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        widget.imagePath,
      ));

      // Send request
      var response = await request.send().timeout(const Duration(seconds: 60));
      var responseData = await response.stream.bytesToString();
      var result = jsonDecode(responseData);

      if (response.statusCode == 200) {
        await _processAPIResponse(result); // Made async
      } else {
        setState(() {
          _errorMessage = 'API Error: ${response.statusCode} - ${result['ErrorMessage'] ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processAPIResponse(Map<String, dynamic> result) async {
    try {
      var parsedResults = result['ParsedResults'] as List?;

      if (parsedResults == null || parsedResults.isEmpty) {
        setState(() {
          _errorMessage = 'No text detected in the image';
        });
        return;
      }

      var parsed = parsedResults.first;
      var fullText = parsed['ParsedText']?.toString().trim() ?? 'No text detected';

      // Extract structured output from text overlay
      var structuredOutput = <Map<String, dynamic>>[];
      var textOverlay = parsed['TextOverlay'] ?? {};
      var lines = textOverlay['Lines'] as List? ?? [];

      for (var line in lines) {
        var words = line['Words'] as List? ?? [];
        var lineText = words.map<String>((word) => word['WordText']?.toString() ?? '').join(' ');

        if (lineText.trim().isNotEmpty) {
          var lineData = {
            'text': lineText,
            'words': words.map<String>((word) => word['WordText']?.toString() ?? '').toList(),
            'bounding_box': {
              'left': line['MinLeft'] ?? 0,
              'top': line['MinTop'] ?? 0,
              'width': line['MaxWidth'] ?? 0,
              'height': line['MaxHeight'] ?? 0,
            },
            'words_data': words.map((word) => {
              'text': word['WordText']?.toString() ?? '',
              'left': word['Left'] ?? 0,
              'top': word['Top'] ?? 0,
              'width': word['Width'] ?? 0,
              'height': word['Height'] ?? 0,
            }).toList(),
          };
          structuredOutput.add(lineData);
          _detectedLines.add(lineData);
        }
      }

      // Create processed image with bounding boxes
      await _createProcessedImage();

      setState(() {
        _detectedText = fullText;
        _structuredOutput = _formatStructuredOutput(structuredOutput);
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Processing error: $e';
      });
    }
  }

  Future<void> _createProcessedImage() async {
    if (_originalImageBytes == null || _detectedLines.isEmpty) return;

    try {
      // Load the original image
      final codec = await ui.instantiateImageCodec(_originalImageBytes!);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Create a picture recorder and canvas
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      // Draw the original image
      canvas.drawImage(image, Offset.zero, paint);

      // Calculate dynamic stroke width based on image size
      final baseStrokeWidth = image.width / 50; // Increased stroke width

      // Draw bounding boxes on the image with increased visibility
      for (var line in _detectedLines) {
        var bbox = line['bounding_box'] as Map<String, dynamic>;

        // Draw line bounding box (green) - make it more visible
        final lineRect = Rect.fromLTWH(
          (bbox['left'] as num).toDouble(),
          (bbox['top'] as num).toDouble(),
          (bbox['width'] as num).toDouble(),
          (bbox['height'] as num).toDouble(),
        );

        // Draw thicker green rectangle for line
        canvas.drawRect(
          lineRect,
          Paint()
            ..color = Colors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = baseStrokeWidth * 1.5, // Increased stroke width
        );

        // Draw filled semi-transparent background for better visibility
        canvas.drawRect(
          lineRect,
          Paint()
            ..color = Colors.green.withOpacity(0.2)
            ..style = PaintingStyle.fill,
        );

        // Draw word bounding boxes (red) - make them more visible
        var wordsData = line['words_data'] as List<dynamic>;
        for (var wordData in wordsData) {
          final wordRect = Rect.fromLTWH(
            (wordData['left'] as num).toDouble(),
            (wordData['top'] as num).toDouble(),
            (wordData['width'] as num).toDouble(),
            (wordData['height'] as num).toDouble(),
          );

          // Draw thicker red rectangle for word
          canvas.drawRect(
            wordRect,
            Paint()
              ..color = Colors.red
              ..style = PaintingStyle.stroke
              ..strokeWidth = baseStrokeWidth, // Increased stroke width
          );

          // Draw filled semi-transparent background for better visibility
          canvas.drawRect(
            wordRect,
            Paint()
              ..color = Colors.red.withOpacity(0.1)
              ..style = PaintingStyle.fill,
          );
        }
      }

      // Convert the canvas to an image
      final picture = recorder.endRecording();
      final processedImage = await picture.toImage(image.width, image.height);
      final byteData = await processedImage.toByteData(format: ui.ImageByteFormat.png);

      setState(() {
        _processedImageBytes = byteData?.buffer.asUint8List();
      });
    } catch (e) {
      print('Error creating processed image: $e');
    }
  }

  String _formatStructuredOutput(List<Map<String, dynamic>> output) {
    if (output.isEmpty) return 'No structured data available';

    var buffer = StringBuffer();

    for (var i = 0; i < output.length; i++) {
      var item = output[i];
      buffer.writeln('Line ${i + 1}:');
      buffer.writeln('  Text: "${item['text']}"');

      var words = item['words'] as List<String>;
      if (words.isNotEmpty) {
        buffer.writeln('  Words: $words');
      }

      var bbox = item['bounding_box'] as Map<String, dynamic>;
      buffer.writeln('  Position: (${bbox['left']}, ${bbox['top']})');
      buffer.writeln('  Size: ${bbox['width']}x${bbox['height']}');

      // Add word-level coordinates
      var wordsData = item['words_data'] as List<dynamic>;
      if (wordsData.isNotEmpty) {
        buffer.writeln('  Word Coordinates:');
        for (var wordData in wordsData) {
          buffer.writeln('    "${wordData['text']}": (${wordData['left']}, ${wordData['top']}) ${wordData['width']}x${wordData['height']}');
        }
      }
      buffer.writeln('─' * 50);
    }

    return buffer.toString();
  }

  Widget _buildImageSection(String title, Uint8List? imageBytes, Color color, String description) {
    if (imageBytes == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  void _clearResults() {
    setState(() {
      _detectedText = '';
      _structuredOutput = '';
      _detectedLines = [];
      _errorMessage = '';
      _processedImageBytes = null;
    });
  }

  void _copyToClipboard(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Text Detection',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_detectedText.isNotEmpty)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
              onPressed: _clearResults,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Original Image
              if (_originalImageBytes != null)
                _buildImageSection(
                    'Original Image',
                    _originalImageBytes!,
                    Colors.blue,
                    'Uploaded image for text detection'
                ),

              const SizedBox(height: 20),

              // Processed Image with Bounding Boxes
              if (_processedImageBytes != null)
                _buildImageSection(
                    'Processed Image with Bounding Boxes',
                    _processedImageBytes!,
                    Colors.green,
                    'Green boxes: Line boundaries | Red boxes: Word boundaries'
                ),

              const SizedBox(height: 20),

              // Process Button
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.green, Colors.lightGreen],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _callTextDetectionAPI,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: _isProcessing
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Detecting Text...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                      : const Text(
                    'Process with pen to pixel  OCR Model',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Loading Indicator
              if (_isProcessing)
                const Column(
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 10),
                    Text(
                      'Calling OCR API...',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),

              // Detected Text Section
              if (_detectedText.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Detected Text:',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.green),
                          onPressed: () => _copyToClipboard(_detectedText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: SelectableText(
                        _detectedText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

              // Structured Output Section
              if (_structuredOutput.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bounding Box Data:',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.blue),
                          onPressed: () => _copyToClipboard(_structuredOutput),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _structuredOutput,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              // Error Message
              if (_errorMessage.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Error:',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: SelectableText(
                        _errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

              // Empty State
              if (!_isProcessing && _detectedText.isEmpty && _errorMessage.isEmpty)
                Container(
                  height: 200,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.text_fields, size: 64, color: Colors.green),
                        SizedBox(height: 20),
                        Text(
                          'pen to pixel for Text Detection',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Press the button to detect text using pen to pixel ORC model',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}