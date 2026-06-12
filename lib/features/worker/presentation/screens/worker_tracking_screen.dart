import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';

class WorkerTrackingScreen extends ConsumerStatefulWidget {
  final String jobId;
  const WorkerTrackingScreen({super.key, required this.jobId});

  @override
  ConsumerState<WorkerTrackingScreen> createState() => _WorkerTrackingScreenState();
}

class _WorkerTrackingScreenState extends ConsumerState<WorkerTrackingScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPos;
  LatLng? _jobPos;
  String? _jobLocationName;
  bool _isCompleting = false;
  bool _permissionGranted = false;
  bool _loadingPermission = true;
  List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _positionSubscription;
  double? _distanceToJob;
  double _workerHeading = 0;
  bool _firstFit = true;

  static const LatLng _initialPosition = LatLng(33.6844, 73.0479);

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _fetchJobDetails();
    _listenForJobStatus();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    // Get initial position
    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _handlePositionUpdate(pos);
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_handlePositionUpdate);
  }

  void _handlePositionUpdate(Position pos) {
    final newPos = LatLng(pos.latitude, pos.longitude);
    
    if (mounted) {
      setState(() {
        _currentPos = newPos;
        _workerHeading = pos.heading;
        if (_jobPos != null) {
          _distanceToJob = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            _jobPos!.latitude,
            _jobPos!.longitude,
          );
        }
      });
      
      // Update RTDB for client to see
      final user = ref.read(authServiceProvider).currentUser;
      if (user != null) {
        ref.read(jobServiceProvider).updateWorkerLocation(
          widget.jobId,
          user.uid,
          pos.latitude,
          pos.longitude,
        );
      }

      if (_currentPos != null && _jobPos != null) {
        _fetchRoute();
        if (_firstFit) {
          _firstFit = false;
          _fitBounds();
        }
      }

      if (!_firstFit) {
        _updateCamera(newPos);
      }
    }
  }

  void _listenForJobStatus() {
    FirebaseDatabase.instance
        .ref('active_jobs/${widget.jobId}/status')
        .onValue
        .listen((event) {
      final status = event.snapshot.value;
      if (status == 'completed' && mounted) {
        // Check if a dialog is already showing to avoid multiple dialogs
        if (ModalRoute.of(context)?.isCurrent != true) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Job Completed'),
            content: const Text('The job has been marked as completed. Thank you for your service!'),
            actions: [
              TextButton(
                onPressed: () {
                  // Use the outer context for navigation to ensure it's not the dialog context
                  context.go(AppRouter.workerDashboard);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (status == 'cancelled' && mounted) {
        if (ModalRoute.of(context)?.isCurrent != true) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Job Cancelled'),
            content: const Text('The job has been cancelled.'),
            actions: [
              TextButton(
                onPressed: () {
                  context.go(AppRouter.workerDashboard);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _fetchJobDetails() async {
    try {
      final doc = await ref.read(jobServiceProvider).getJobDetails(widget.jobId);
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _jobPos = LatLng(data['lat'], data['lng']);
          _jobLocationName = data['location_name'];
        });
        if (_currentPos != null) {
          _fetchRoute();
        }
      }
    } catch (e) {
      debugPrint('Error fetching job details: $e');
    }
  }

  Future<void> _fetchRoute() async {
    if (_currentPos == null || _jobPos == null) return;

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${_currentPos!.longitude},${_currentPos!.latitude};'
          '${_jobPos!.longitude},${_jobPos!.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
        
        setState(() {
          _routePoints = coordinates
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
      setState(() {
        _routePoints = [_currentPos!, _jobPos!];
      });
    }
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _loadingPermission = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _loadingPermission = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _loadingPermission = false);
      return;
    }

    if (mounted) {
      setState(() {
        _permissionGranted = true;
        _loadingPermission = false;
      });
      _startTracking();
    }
  }

  void _updateCamera(LatLng position) {
    _mapController.move(position, 16.0);
  }

  void _fitBounds() {
    if (_currentPos != null && _jobPos != null) {
      final bounds = LatLngBounds(_currentPos!, _jobPos!);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPermission) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_permissionGranted) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Location permissions are required for tracking.'),
              ElevatedButton(
                onPressed: _checkPermissions,
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job in Progress', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined, color: AppColors.primary),
            onPressed: () => context.push(AppRouter.chatDetail, extra: widget.jobId),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPos ?? _jobPos ?? _initialPosition,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.kamkaj.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Border/Shadow for route
                    Polyline(
                      points: _routePoints,
                      color: AppColors.primary.withValues(alpha: 0.3),
                      strokeWidth: 10,
                    ),
                    // Main route line
                    Polyline(
                      points: _routePoints,
                      color: AppColors.primary,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_jobPos != null)
                    Marker(
                      point: _jobPos!,
                      width: 45,
                      height: 45,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 45,
                      ),
                    ),
                  if (_currentPos != null)
                    Marker(
                      point: _currentPos!,
                      width: 45,
                      height: 45,
                      child: Transform.rotate(
                        angle: _workerHeading * (3.14159 / 180),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_bike,
                            color: AppColors.primary,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  onPressed: () {
                    if (_currentPos != null) {
                      _updateCamera(_currentPos!);
                    }
                  },
                  backgroundColor: Colors.white,
                  heroTag: 'center_me',
                  child: const Icon(Icons.my_location, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  onPressed: _fitBounds,
                  backgroundColor: Colors.white,
                  heroTag: 'fit_bounds',
                  child: const Icon(Icons.zoom_out_map, color: AppColors.primary),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_distanceToJob != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Distance remaining: ${(_distanceToJob! / 1000).toStringAsFixed(2)} km',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  Text(
                    'Heading to: ${_jobLocationName ?? 'Job Location'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You are being tracked by the client',
                    style: TextStyle(color: AppColors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isCompleting ? null : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Cancel Job'),
                                content: const Text('Are you sure you want to cancel this job?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('YES')),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              setState(() => _isCompleting = true);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await ref.read(jobServiceProvider).cancelJob(widget.jobId, 'Cancelled by Worker');
                              } catch (e) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isCompleting = false);
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(0, 50),
                          ),
                          child: const Text('CANCEL'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isCompleting ? null : () async {
                            setState(() => _isCompleting = true);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await ref.read(jobServiceProvider).completeJob(widget.jobId);
                              // Navigation is handled by _listenForJobStatus
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isCompleting = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(0, 50),
                          ),
                          child: _isCompleting 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('MARK COMPLETE'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
