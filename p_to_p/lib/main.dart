
import 'package:flutter/material.dart';
import 'package:p_to_p/pictures.dart';
import 'package:camera/camera.dart';


// A global list to store available cameras.
List<CameraDescription> cameras = [];

// Main function to run the app. It must be an async function to initialize the cameras.
Future<void> main() async {
  // Ensure that plugin services are initialized.
  WidgetsFlutterBinding.ensureInitialized();
print(Path);
  // Fetch the list of available cameras.
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint("Error initializing cameras: $e");
  }

  runApp(const PenToPixel());
}

// The main application widget.
