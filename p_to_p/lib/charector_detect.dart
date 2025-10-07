import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CharacterDetectPage extends StatefulWidget {
  final String imagePath;

  const CharacterDetectPage({super.key, required this.imagePath});

  @override
  State<CharacterDetectPage> createState() => _CharacterDetectPageState();
}

class _CharacterDetectPageState extends State<CharacterDetectPage> {
  bool _isProcessing = false;
  String _predictedCharacter = '';
  double _confidence = 0.0;
  Map<String, double> _topPredictions = {};
  Uint8List? _processedImageBytes;
  Uint8List? _originalImageBytes;
  String _errorMessage = '';

  // Replace with your actual API endpoint
  final String _apiUrl = "https://rnaveenpatil-p-to-p.hf.space/predict";

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

  Future<void> _callCharacterDetectionAPI() async {
    setState(() {
      _isProcessing = true;
      _predictedCharacter = '';
      _confidence = 0.0;
      _topPredictions = {};
      _processedImageBytes = null;
      _errorMessage = '';
    });

    try {
      // Read the image file
      File imageFile = File(widget.imagePath);
      List<int> imageBytes = await imageFile.readAsBytes();

      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));

      // Add the image file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        widget.imagePath,
      ));

      // Send request
      var response = await request.send().timeout(const Duration(seconds: 30));
      var responseData = await response.stream.bytesToString();
      var result = jsonDecode(responseData);

      if (response.statusCode == 200) {
        _processAPIResponse(result);
      } else {
        setState(() {
          _errorMessage = 'API Error: ${response.statusCode} - ${result['detail'] ?? 'Unknown error'}';
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

  void _processAPIResponse(Map<String, dynamic> result) {
    try {
      if (result['success'] == true) {
        var prediction = result['prediction'];
        var processedImageBase64 = result['processed_image'];

        // Decode the processed image (base64 string)
        if (processedImageBase64 != null && processedImageBase64.isNotEmpty) {
          // Remove data URL prefix if present
          String base64Data = processedImageBase64;
          if (base64Data.contains(',')) {
            base64Data = base64Data.split(',').last;
          }

          try {
            _processedImageBytes = base64.decode(base64Data);
          } catch (e) {
            print('Error decoding base64 image: $e');
            _processedImageBytes = null;
          }
        }

        setState(() {
          _predictedCharacter = prediction['predicted_character'] ?? 'Unknown';
          _confidence = (prediction['confidence'] ?? 0.0).toDouble();

          // Convert top_5 predictions to map
          var top5 = prediction['top_5'] as Map<String, dynamic>? ?? {};
          _topPredictions = top5.map((key, value) =>
              MapEntry(key, (value as num).toDouble())
          );
        });

        print('Prediction: $_predictedCharacter');
        print('Confidence: $_confidence');
        print('Top predictions: $_topPredictions');
        print('Processed image bytes: ${_processedImageBytes?.length}');

      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'API returned unsuccessful response';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing API response: $e';
      });
    }
  }

  void _clearResults() {
    setState(() {
      _predictedCharacter = '';
      _confidence = 0.0;
      _topPredictions = {};
      _processedImageBytes = null;
      _errorMessage = '';
    });
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return Colors.green;
    if (confidence > 0.6) return Colors.orange;
    if (confidence > 0.4) return Colors.yellow;
    return Colors.red;
  }

  String _getConfidenceFeedback(double confidence) {
    if (confidence > 0.8) return '🎉 High confidence prediction!';
    if (confidence > 0.6) return '👍 Good prediction';
    if (confidence > 0.4) return '⚠️ Moderate confidence';
    return '🔍 Low confidence. Try a clearer image.';
  }

  Widget _buildImageSection(String title, Uint8List? imageBytes, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity, // Make it full width
          height: 200, // Increased height
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5), width: 2),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: imageBytes != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
            ),
          )
              : Center(
            child: Icon(
              Icons.image,
              color: color.withOpacity(0.3),
              size: 50,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Predicted Character',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.blue, width: 3),
            ),
            child: Center(
              child: Text(
                _predictedCharacter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              color: _getConfidenceColor(_confidence),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _confidence,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              _getConfidenceColor(_confidence),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 8),
          Text(
            _getConfidenceFeedback(_confidence),
            style: TextStyle(
              color: _getConfidenceColor(_confidence),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopPredictions() {
    if (_topPredictions.isEmpty) return const SizedBox();

    // Sort predictions by confidence (descending)
    var sortedPredictions = _topPredictions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 Predictions:',
            style: TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: sortedPredictions.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Center(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: entry.value,
                        backgroundColor: Colors.green.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getConfidenceColor(entry.value),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(entry.value * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Character Detection',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_predictedCharacter.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _clearResults,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Image Comparison - Updated layout
              Card(
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'pen to pixel cnn ai model',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Original Image - Top
                      _buildImageSection('Original Image', _originalImageBytes, Colors.blue),

                      const SizedBox(height: 20),

                      // Processed Image - Bottom
                      _buildImageSection('Processed Image', _processedImageBytes, Colors.green),

                      if (_processedImageBytes != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Image processed to 128x128 format',
                                style: TextStyle(color: Colors.green, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Process Button
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.lightBlue],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _callCharacterDetectionAPI,
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
                        'Processing...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                      : const Text(
                    'proced to Pen to pixel model',
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
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 10),
                    Text(
                      'Analyzing character with AI...',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // Prediction Results
              if (_predictedCharacter.isNotEmpty) ...[
                _buildPredictionCard(),
                const SizedBox(height: 20),
                _buildTopPredictions(),
              ],

              // Error Message
              if (_errorMessage.isNotEmpty)
                Card(
                  color: Colors.red[900],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Empty State
              if (!_isProcessing && _predictedCharacter.isEmpty && _errorMessage.isEmpty)
                Container(
                  height: 200,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.text_fields, size: 64, color: Colors.blue),
                        SizedBox(height: 20),
                        Text(
                          'pen_to_pixel is ready  for Character Detection',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Press the button to analyze the character',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 14,
                          ),
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