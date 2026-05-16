// lib/screens/gps_verification_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';

class GpsVerificationScreen extends ConsumerStatefulWidget {
  const GpsVerificationScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GpsVerificationScreen> createState() => _GpsVerificationScreenState();
}

class _GpsVerificationScreenState extends ConsumerState<GpsVerificationScreen> {
  bool _isLoading = false;
  String _status = 'Initializing GPS verification...';
  Position? _currentPosition;
  bool _isLocationVerified = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() => _status = 'Checking location permissions...');

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _status = 'Location services are disabled. Please enable them.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() => _status = 'Location permission denied');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _status = 'Location permission permanently denied. Please enable in settings.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission permanently denied.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
        return;
      }

      setState(() => _status = 'Getting current location...');

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
        _status = 'Location obtained: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });

      // Verify location (simulate office location check)
      await _verifyLocation(position);

    } catch (e) {
      setState(() => _status = 'Error getting location: $e');
    }
  }

  Future<void> _verifyLocation(Position position) async {
    setState(() => _status = 'Verifying location...');

    try {
      // Call GPS validation API
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/gps/validate',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );

      final result = response.data;
      final isInside = result['is_inside'] ?? false;
      final distance = (result['distance_meters'] ?? 0.0).toDouble();

      if (isInside) {
        setState(() {
          _isLocationVerified = true;
          _status = '✅ Location verified! You are within office premises.';
        });
      } else {
        setState(() {
          _isLocationVerified = false;
          _status = '❌ Location verification failed. You are ${distance.toInt()}m away from office.';
        });
      }
    } catch (e) {
      setState(() => _status = 'Location verification error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS verification failed: $e')),
      );
    }
  }

  Future<void> _retryVerification() async {
    setState(() {
      _isLocationVerified = false;
      _status = 'Retrying location verification...';
    });
    await _initializeLocation();
  }

  void _proceedToNextStep() {
    if (_isLocationVerified) {
      // Navigate to face recognition or check-in
      context.go('/face-recognition');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your location first')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Verification'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Icon(
                _isLocationVerified ? Icons.location_on : Icons.location_searching,
                size: 80,
                color: _isLocationVerified ? Colors.green : Colors.indigo[600],
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                _isLocationVerified ? 'Location Verified!' : 'Verify Your Location',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isLocationVerified ? Colors.green : null,
                ),
              ),
              const SizedBox(height: 16),

              // Status Text
              Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _isLocationVerified ? Colors.green : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // Location Info Card
              if (_currentPosition != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.location_on),
                          title: const Text('Current Location'),
                          subtitle: Text(
                            '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.access_time),
                          title: const Text('Accuracy'),
                          subtitle: Text('${_currentPosition!.accuracy.toStringAsFixed(1)} meters'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.schedule),
                          title: const Text('Timestamp'),
                          subtitle: Text(_currentPosition!.timestamp.toString()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Loading Indicator
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Please wait...'),
              ],

              const Spacer(),

              // Action Buttons
              if (!_isLocationVerified) ...[
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _retryVerification,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Verification'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('Skip for Now'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _proceedToNextStep,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue to Face Recognition'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('Skip Face Recognition'),
                ),
              ],

              const SizedBox(height: 24),

              // Info Text
              Text(
                'GPS verification ensures you are at the correct location for attendance tracking.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}