import 'package:http/http.dart' as http;
import 'dart:convert';

class HotelService {
  static const String _clientId = 'QFNzNaI9uOx74mMfUfaAYZAlzZ55e8JB';
  static const String _clientSecret = 'yAltCw1JMsM9SwN9';
  static const String _authUrl = 'https://test.api.amadeus.com/v1/security/oauth2/token';
  static const String _hotelSearchUrl = 'https://test.api.amadeus.com/v1/reference-data/locations/hotels/by-city';

  static Future<String?> getAccessToken() async {
    final response = await http.post(
      Uri.parse(_authUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'client_credentials',
        'client_id': _clientId,
        'client_secret': _clientSecret,
      },
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['access_token'];
    } else {
      print('Failed to get Amadeus access token: ${response.body}');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchHotels({required String destination}) async {
    final token = await getAccessToken();
    if (token == null) return [];

    // Amadeus expects a city code (IATA), e.g., 'PAR' for Paris. We'll use the first 3 letters uppercased as a simple mapping.
    final cityCode = destination.trim().substring(0, 3).toUpperCase();
    final url = '$_hotelSearchUrl?cityCode=$cityCode';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final hotels = (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return hotels;
    } else {
      print('Failed to fetch hotels: ${response.body}');
      return [];
    }
  }
} 