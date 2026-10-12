import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LocationTrackerApp());
}

class LocationTrackerApp extends StatelessWidget {
  const LocationTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Live Location Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const LocationMapScreen(),
    );
  }
}

class LocationMapScreen extends StatefulWidget {
  const LocationMapScreen({super.key});

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  GoogleMapController? _mapController;
  Timer? _timer;

  LatLng? _currentLocation;

  final List<LatLng> _routePoints = [];

  String _status = 'Getting your current location...';
  bool _isFetching = false;
  bool _isMapReady = false;

  Set<Marker> get _markers {
    if (_currentLocation == null) {
      return {};
    }

    return {
      Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLocation!,
        infoWindow: InfoWindow(
          title: 'My current location',
          snippet:
              'Latitude: ${_currentLocation!.latitude.toStringAsFixed(6)}, '
              'Longitude: ${_currentLocation!.longitude.toStringAsFixed(6)}',
        ),
      ),
    };
  }

  Set<Polyline> get _polylines {
    if (_routePoints.length < 2) {
      return {};
    }

    return {
      Polyline(
        polylineId: const PolylineId('location_route'),
        points: List<LatLng>.of(_routePoints),
        color: Colors.blue,
        width: 5,
        geodesic: true,
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    await _updateLocation();

    if (!mounted) return;

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateLocation();
    });
  }

  Future<void> _updateLocation() async {
    if (_isFetching) return;

    _isFetching = true;

    try {
      // Check whether the device location service is enabled.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _status = 'Please enable your device location/GPS.';
          });
        }
        return;
      }

      // Check location permission.
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _status = 'Location permission denied.';
          });
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _status =
                'Location permission permanently denied. '
                'Enable it in app settings.';
          });
        }
        return;
      }

      // Get the latest device position.
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final LatLng newLocation = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _currentLocation = newLocation;

        // Add each new position to the route.
        if (_routePoints.isEmpty || _routePoints.last != newLocation) {
          _routePoints.add(newLocation);
        }

        _status = 'Location updated successfully.';
      });

      // Animate the map to the current location.
      if (_isMapReady && _mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newLocation, zoom: 17),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _status = 'Location request timed out. Trying again soon.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Unable to get location. Please try again.';
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentLocation == null) {
      await _updateLocation();
      return;
    }

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLocation!, zoom: 17),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Temporary initial camera position until GPS is available.
    const LatLng initialPosition = LatLng(23.8103, 90.4125);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Location Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh location',
            onPressed: _updateLocation,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: initialPosition,
                zoom: 12,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _isMapReady = true;

                if (_currentLocation != null) {
                  _goToCurrentLocation();
                }
              },
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              mapToolbarEnabled: true,
            ),
          ),

          // Location details panel.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.teal, size: 28),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'My Current Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      _currentLocation != null
                          ? Icons.check_circle
                          : Icons.location_searching,
                      color: _currentLocation != null
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_currentLocation != null) ...[
                  Text(
                    'Latitude: '
                    '${_currentLocation!.latitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Longitude: '
                    '${_currentLocation!.longitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 6),
                  Text('Route points: ${_routePoints.length}'),
                ] else
                  const Text('Waiting for GPS coordinates...'),

                const SizedBox(height: 12),

                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _goToCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Go to My Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
