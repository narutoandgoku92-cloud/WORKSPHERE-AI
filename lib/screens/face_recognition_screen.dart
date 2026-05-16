// lib/screens/face_recognition_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class FaceRecognitionScreen extends ConsumerStatefulWidget {
  const FaceRecognitionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends ConsumerState<FaceRecognitionScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isProcessing = false;
  bool _isSuccess = false;
  String _status = 'Initializing camera...';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize();
      if (mounted) {
        setState(() => _status = 'Camera ready. Position your face in the frame.');
      }
    } catch (e) {
      setState(() => _status = 'Camera initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _recognizeFace() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not ready')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Processing face recognition...';
    });

    try {
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      setState(() => _status = 'Verifying face with server...');

      // TODO: Replace with actual face recognition API call
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/face-recognition/verify',
        data: {'face_image': base64Image},
      );

      if (response.statusCode == 200) {
        final result = response.data;
        final isVerified = result['verified'] ?? false;
        final confidence = (result['confidence'] ?? 0.0).toDouble();

        if (isVerified && confidence > 0.8) {
          setState(() {
            _isSuccess = true;
            _status = '✅ Face verified successfully! Confidence: ${(confidence * 100).toInt()}%';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face recognition successful!')),
          );

          // Auto-proceed to check-in after success
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) context.go('/check-in');
          });
        } else {
          setState(() {
            _status = '❌ Face verification failed. Please try again.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face not recognized. Please try again.')),
          );
        }
      } else {
        throw Exception('Face verification failed');
      }
    } catch (e) {
      setState(() => _status = 'Face recognition error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recognition failed: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition'),
        actions: [
          TextButton(
            onPressed: () => context.go('/check-in'),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isSuccess ? Colors.green[50] : Colors.indigo[50],
            child: Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isSuccess ? Colors.green[800] : Colors.indigo[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Camera Preview
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (_controller != null) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CameraPreview(_controller!),
                        // Face detection overlay
                        Container(
                          width: 250,
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _isSuccess ? Colors.green : Colors.white,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        // Instructions
                        Positioned(
                          bottom: 100,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Text(
                              'Position your face in the frame',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return const Center(child: Text('Camera not available'));
                  }
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (_isProcessing)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: _recognizeFace,
                    icon: const Icon(Icons.camera),
                    label: const Text('Verify Face'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go('/enroll-face'),
                        child: const Text('Enroll Face'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go('/check-in'),
                        child: const Text('Manual Check-in'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  'Face recognition ensures secure attendance tracking',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
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