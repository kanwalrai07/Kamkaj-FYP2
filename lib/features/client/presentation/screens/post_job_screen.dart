import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/service_providers.dart';

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _descriptionController = TextEditingController();
  final _locationNameController = TextEditingController();
  final MapController _mapController = MapController();
  
  String? _selectedCategory;
  double _budget = 700.0;
  bool _isLoading = false;
  
  LatLng _selectedLocation = const LatLng(33.6844, 73.0479); // Default: Islamabad
  bool _locationPicked = false;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  Future<void> _setInitialLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _mapController.move(_selectedLocation, 15.0);
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }

  Future<void> _postJob() async {
    if (_selectedCategory == null || _descriptionController.text.isEmpty || !_locationPicked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and pick a location on map')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('Not logged in');

      await ref.read(jobServiceProvider).postJob(
            clientId: user.uid,
            category: _selectedCategory!,
            description: _descriptionController.text.trim(),
            location: _locationNameController.text.isEmpty ? 'Selected Location' : _locationNameController.text.trim(),
            budget: _budget,
            lat: _selectedLocation.latitude,
            lng: _selectedLocation.longitude,
          );

      if (mounted) {
        context.go(AppRouter.clientHome);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post a Job', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Job Category', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      hintText: 'Select Category',
                      prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: ['Fan Installation', 'Plumbing', 'Electrician', 'AC Repair', 'Cleaning']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),
                  const SizedBox(height: 16),
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Tell us more about the job...'),
                  ),
                  const SizedBox(height: 24),
                  const Text('Pick Location on Map', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightGrey),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedLocation,
                          initialZoom: 15.0,
                          onTap: (tapPosition, point) {
                            setState(() {
                              _selectedLocation = point;
                              _locationPicked = true;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                            userAgentPackageName: 'com.kamkaj.app',
                          ),
                          if (_locationPicked)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _selectedLocation,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap on the map to mark your job location',
                    style: TextStyle(fontSize: 12, color: AppColors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text('Address / Nearby Landmark (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _locationNameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. House 123, Street 4...',
                      suffixIcon: Icon(Icons.edit_location_alt, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Budget', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Slider(
                    value: _budget,
                    min: 300,
                    max: 5000,
                    divisions: 47,
                    label: 'Rs. ${_budget.round()}',
                    onChanged: (val) => setState(() => _budget = val.roundToDouble()),
                    activeColor: AppColors.primary,
                  ),
                  Center(
                    child: Text(
                      'Rs. ${_budget.round()}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _postJob,
                    child: const Text('POST JOB'),
                  ),
                  const SizedBox(height: 16),
                  const Center(child: Text('Post a Job', style: TextStyle(color: AppColors.grey))),
                ],
              ),
            ),
    );
  }
}
