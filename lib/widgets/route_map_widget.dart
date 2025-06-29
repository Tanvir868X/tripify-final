import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/route_service.dart';

class RouteMapWidget extends StatefulWidget {
  final String destination;
  final double? destLatitude;
  final double? destLongitude;

  const RouteMapWidget({
    super.key,
    required this.destination,
    this.destLatitude,
    this.destLongitude,
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  Position? _currentPosition;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _routeInfo;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final position = await RouteService.getCurrentLocation();
      
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });
        
        if (widget.destLatitude != null && widget.destLongitude != null) {
          _calculateRouteInfo();
        }
      } else {
        setState(() {
          _error = 'Unable to get current location. Please check location permissions.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  void _calculateRouteInfo() {
    if (_currentPosition != null && widget.destLatitude != null && widget.destLongitude != null) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        widget.destLatitude!,
        widget.destLongitude!,
      );
      
      final estimatedTimeMinutes = (distance / 50000 * 60).round();
      
      setState(() {
        _routeInfo = {
          'distance': distance,
          'estimatedTime': estimatedTimeMinutes,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _getCurrentLocation, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_currentPosition == null) {
      return const Center(child: Text('Location not available'));
    }

    LatLng mapCenter;
    List<LatLng> routePoints = [];

    if (widget.destLatitude != null && widget.destLongitude != null) {
      final currentLatLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      final destLatLng = LatLng(widget.destLatitude!, widget.destLongitude!);
      
      mapCenter = LatLng(
        (currentLatLng.latitude + destLatLng.latitude) / 2,
        (currentLatLng.longitude + destLatLng.longitude) / 2,
      );
      
      routePoints = [currentLatLng, destLatLng];
    } else {
      mapCenter = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }

    return Column(
      children: [
        if (_routeInfo != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(Icons.straighten, color: Colors.blue),
                    Text('${(_routeInfo!['distance'] / 1000).toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Distance'),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.access_time, color: Colors.blue),
                    Text('${_routeInfo!['estimatedTime']} min', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Est. Time'),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.directions_car, color: Colors.blue),
                    const Text('Driving', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Mode'),
                  ],
                ),
              ],
            ),
          ),
        
        Expanded(
          child: FlutterMap(
            options: MapOptions(initialCenter: mapCenter, initialZoom: 10.0),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              
              MarkerLayer(markers: [
                Marker(
                  point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                  ),
                ),
              ]),
              
              if (widget.destLatitude != null && widget.destLongitude != null)
                MarkerLayer(markers: [
                  Marker(
                    point: LatLng(widget.destLatitude!, widget.destLongitude!),
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.place, color: Colors.white, size: 20),
                      ),
                    ),
                ]),
              
              if (routePoints.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(points: routePoints, strokeWidth: 4, color: Colors.blue),
                ]),
            ],
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.navigation),
                  label: const Text('Open in Maps'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: () async {
                    await RouteService.openRouteInMaps(widget.destination);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  onPressed: _getCurrentLocation,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 