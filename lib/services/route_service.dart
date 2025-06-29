import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class RouteService {
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied');
      return null;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  static Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return null;
  }

  static Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return {
          'latitude': locations[0].latitude,
          'longitude': locations[0].longitude,
        };
      }
    } catch (e) {
      print('Error getting coordinates: $e');
    }
    return null;
  }

  static Future<void> openRouteInMaps(String destination) async {
    try {
      // Try to get current location
      Position? currentPosition = await getCurrentLocation();
      
      if (currentPosition != null) {
        // Use Google Maps with current location
        final url = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&origin=${currentPosition.latitude},${currentPosition.longitude}&destination=${Uri.encodeComponent(destination)}&travelmode=driving'
        );
        
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          // Fallback to just destination
          final fallbackUrl = Uri.parse(
            'https://www.google.com/maps/search/${Uri.encodeComponent(destination)}'
          );
          if (await canLaunchUrl(fallbackUrl)) {
            await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
          }
        }
      } else {
        // No current location, just search for destination
        final url = Uri.parse(
          'https://www.google.com/maps/search/${Uri.encodeComponent(destination)}'
        );
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      print('Error opening route: $e');
    }
  }

  static Future<Map<String, dynamic>?> getRouteInfo(String destination) async {
    try {
      Position? currentPosition = await getCurrentLocation();
      
      if (currentPosition != null) {
        // Get destination coordinates
        Map<String, double>? destCoords = await getCoordinatesFromAddress(destination);
        
        if (destCoords != null) {
          // Calculate distance
          double distance = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            destCoords['latitude']!,
            destCoords['longitude']!,
          );
          
          // Estimate travel time (assuming average speed of 50 km/h for driving)
          double estimatedTimeHours = distance / 50000; // 50 km/h = 50000 m/h
          int estimatedTimeMinutes = (estimatedTimeHours * 60).round();
          
          return {
            'distance': distance,
            'estimatedTime': estimatedTimeMinutes,
            'currentLocation': {
              'latitude': currentPosition.latitude,
              'longitude': currentPosition.longitude,
            },
            'destination': destCoords,
          };
        }
      }
    } catch (e) {
      print('Error getting route info: $e');
    }
    return null;
  }
} 