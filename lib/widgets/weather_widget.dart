import 'package:flutter/material.dart';
import '../services/weather_service.dart';

class WeatherWidget extends StatefulWidget {
  final String destination;

  const WeatherWidget({super.key, required this.destination});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  Map<String, dynamic>? _currentWeather;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentWeather = await WeatherService.getWeatherData(widget.destination);
      setState(() {
        _currentWeather = currentWeather;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load weather data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Weather in ${widget.destination}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _loadWeatherData,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _buildErrorWidget()
            else
              _buildWeatherContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Failed to load weather data',
            style: TextStyle(color: Colors.red.shade700),
            textAlign: TextAlign.center,
          ),
          if (_error?.contains('API key not set') == true) ...[
            const SizedBox(height: 8),
            Text(
              'Please update the OpenWeatherMap API key in lib/services/weather_service.dart',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeatherContent() {
    if (_currentWeather == null) {
      return const Text('No weather data available');
    }

    final main = _currentWeather!['main'];
    final weather = _currentWeather!['weather'][0];
    final wind = _currentWeather!['wind'];
    final humidity = main['humidity'];
    final temp = main['temp'].round();
    final feelsLike = main['feels_like'].round();
    final weatherCode = weather['icon'];
    final description = weather['description'];

    return Column(
      children: [
        Row(
          children: [
            Text(WeatherService.getWeatherIcon(weatherCode), style: const TextStyle(fontSize: 48)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$temp°C', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  Text(description.toString().toUpperCase(), style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  Text('Feels like $feelsLike°C', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildWeatherDetail(Icons.water_drop, 'Humidity', '$humidity%'),
            _buildWeatherDetail(Icons.air, 'Wind', '${wind['speed'].round()} m/s'),
            _buildWeatherDetail(Icons.visibility, 'Visibility', '${(_currentWeather!['visibility'] / 1000).round()} km'),
          ],
        ),
      ],
    );
  }

  Widget _buildWeatherDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.teal, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
} 