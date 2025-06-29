import 'package:http/http.dart' as http;
import 'dart:convert';

class WeatherService {
  static const String _apiKey = '407547c43d0ce993402b7b4b83a459f4';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  static Future<Map<String, dynamic>?> getWeatherData(String city) async {
    // Check if API key is set
    if (_apiKey == 'YOUR_OPENWEATHERMAP_API_KEY') {
      print('OpenWeatherMap API key not set. Please update the API key in weather_service.dart');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/weather?q=$city&appid=$_apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Weather API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Weather API Exception: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getForecastData(String city) async {
    // Check if API key is set
    if (_apiKey == 'YOUR_OPENWEATHERMAP_API_KEY') {
      print('OpenWeatherMap API key not set. Please update the API key in weather_service.dart');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/forecast?q=$city&appid=$_apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Weather Forecast API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Weather Forecast API Exception: $e');
      return null;
    }
  }

  static String getWeatherIcon(String weatherCode) {
    // Map weather codes to icon names
    switch (weatherCode) {
      case '01d':
        return '☀️';
      case '01n':
        return '🌙';
      case '02d':
      case '02n':
        return '⛅';
      case '03d':
      case '03n':
        return '☁️';
      case '04d':
      case '04n':
        return '☁️';
      case '09d':
      case '09n':
        return '🌧️';
      case '10d':
        return '🌦️';
      case '10n':
        return '🌧️';
      case '11d':
      case '11n':
        return '⛈️';
      case '13d':
      case '13n':
        return '❄️';
      case '50d':
      case '50n':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  static String getWeatherDescription(String weatherCode) {
    switch (weatherCode) {
      case '01d':
      case '01n':
        return 'Clear sky';
      case '02d':
      case '02n':
        return 'Few clouds';
      case '03d':
      case '03n':
        return 'Scattered clouds';
      case '04d':
      case '04n':
        return 'Broken clouds';
      case '09d':
      case '09n':
        return 'Shower rain';
      case '10d':
      case '10n':
        return 'Rain';
      case '11d':
      case '11n':
        return 'Thunderstorm';
      case '13d':
      case '13n':
        return 'Snow';
      case '50d':
      case '50n':
        return 'Mist';
      default:
        return 'Unknown';
    }
  }
} 