import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final String jobId;
  const LiveTrackingScreen({super.key, required this.jobId});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  LatLng? _workerPos;
  LatLng? _jobPos;
  String? _jobLocationName;
  String? _workerId;
  List<LatLng> _routePoints = [];
  bool _isCompleting = false;
  double? _distanceRemaining;
  bool _firstFit = true;

  static const LatLng _initialPosition = LatLng(33.6844, 73.0479); // Islamabad

  @override
  void initState() {
    super.initState();
    _fetchJobDetails();
    _listenForJobStatus();
  }

  void _listenForJobStatus() {
    FirebaseDatabase.instance.ref('active_jobs/${widget.jobId}/status').onValue.listen((event) {
      final status = event.snapshot.value;
      if (status == 'completed' && mounted) {
        // Navigate to feedback screen
        if (_workerId != null) {
          context.go(AppRouter.rateWorker, extra: _workerId);
        } else {
          context.go(AppRouter.clientHome);
        }
      } else if (status == 'cancelled' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job has been cancelled')),
        );
        context.go(AppRouter.clientHome);
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
          _workerId = data['worker_id'];
        });
        if (_workerPos != null) {
          _fetchRoute();
          if (_firstFit) {
            _firstFit = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitBounds();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching job details: $e');
    }
  }

  Future<void> _fetchRoute() async {
    if (_workerPos == null || _jobPos == null) return;

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${_workerPos!.longitude},${_workerPos!.latitude};'
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
      // Fallback to straight line if OSRM fails
      setState(() {
        _routePoints = [_workerPos!, _jobPos!];
      });
    }
  }

  void _updateCamera(LatLng position) {
    _mapController.move(position, 16.0);
  }

  void _fitBounds() {
    if (_workerPos != null && _jobPos != null) {
      final bounds = LatLngBounds(_workerPos!, _jobPos!);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('active_jobs/${widget.jobId}/worker_location').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            try {
              final rawData = snapshot.data!.snapshot.value;
              if (rawData is Map) {
                final data = Map<String, dynamic>.from(rawData);
                final lat = (data['lat'] as num).toDouble();
                final lng = (data['lng'] as num).toDouble();
                final newPos = LatLng(lat, lng);
                
                if (_workerPos == null || (_workerPos!.latitude - newPos.latitude).abs() > 0.0001 || (_workerPos!.longitude - newPos.longitude).abs() > 0.0001) {
                  _workerPos = newPos;
                  _fetchRoute(); // Update route when worker moves
                  
                  if (_jobPos != null) {
                    _distanceRemaining = Geolocator.distanceBetween(
                      newPos.latitude,
                      newPos.longitude,
                      _jobPos!.latitude,
                      _jobPos!.longitude,
                    );
                  }

                  if (_jobPos != null && _firstFit) {
                    _firstFit = false;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _fitBounds();
                    });
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_firstFit) {
                      _updateCamera(newPos);
                    }
                  });
                }
              }
            } catch (e) {
              debugPrint('Error parsing worker location: $e');
            }
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _workerPos ?? _jobPos ?? _initialPosition,
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
                      if (_workerPos != null)
                        Marker(
                          point: _workerPos!,
                          width: 45,
                          height: 45,
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
                              color: Colors.orange,
                              size: 30,
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
                        if (_workerPos != null) {
                          _updateCamera(_workerPos!);
                        }
                      },
                      backgroundColor: Colors.white,
                      heroTag: 'center_worker',
                      child: const Icon(Icons.my_location, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      onPressed: _fitBounds,
                      backgroundColor: Colors.white,
                      heroTag: 'fit_bounds_client',
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
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Worker Status',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_distanceRemaining != null)
                                  Text(
                                    '${(_distanceRemaining! / 1000).toStringAsFixed(2)} km away',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                Text(
                                  _workerPos != null 
                                    ? 'On the way to ${_jobLocationName ?? 'destination'}...' 
                                    : 'Waiting for worker to start...',
                                  style: const TextStyle(color: AppColors.grey, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {}, // Add call logic
                                icon: const Icon(Icons.phone, color: AppColors.primary),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => context.push(AppRouter.chatDetail, extra: widget.jobId),
                                icon: const Icon(Icons.message, color: AppColors.primary),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
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
                                    await ref.read(jobServiceProvider).cancelJob(widget.jobId, 'Cancelled by Client');
                                    // Navigation is handled by _listenForJobStatus
                                  } catch (e) {
                                    if (mounted) {
                                      messenger.showSnackBar(SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ));
                                    }
                                  } finally {
                                    if (mounted) setState(() => _isCompleting = false);
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: const Text('CANCEL JOB'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isCompleting ? null : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Complete Job'),
                                    content: const Text('Are you sure the job is completed?'),
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
                                    await ref.read(jobServiceProvider).completeJob(widget.jobId);
                                    // Navigation is handled by _listenForJobStatus
                                  } catch (e) {
                                    if (mounted) {
                                      messenger.showSnackBar(SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ));
                                    }
                                  } finally {
                                    if (mounted) setState(() => _isCompleting = false);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              child: _isCompleting 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('COMPLETE JOB'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
