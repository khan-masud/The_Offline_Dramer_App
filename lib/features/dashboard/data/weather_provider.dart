import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class HourlyWeather {
  final DateTime time;
  final double temperature;
  final int weatherCode;

  HourlyWeather({
    required this.time,
    required this.temperature,
    required this.weatherCode,
  });

  String get icon => _getIcon(weatherCode);
}

class WeatherInfo {
  final String locationName;
  final double currentTemp;
  final String currentCondition;
  final double maxTemp;
  final double minTemp;
  final List<HourlyWeather> hourly;

  WeatherInfo({
    required this.locationName,
    required this.currentTemp,
    required this.currentCondition,
    required this.maxTemp,
    required this.minTemp,
    required this.hourly,
  });
}

String _getConditionText(int code) {
  if (code == 0) return 'Clear Sky';
  if (code == 1) return 'Mainly Clear';
  if (code == 2) return 'Partly Cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Foggy';
  if (code >= 51 && code <= 55) return 'Drizzle';
  if (code >= 61 && code <= 65) return 'Rainy';
  if (code == 71 || code == 73 || code == 75) return 'Snowy';
  if (code >= 80 && code <= 82) return 'Rain Showers';
  if (code >= 95 && code <= 99) return 'Thunderstorm';
  return 'Unknown';
}

String _getIcon(int code) {
  if (code == 0) return '☀️';
  if (code == 1 || code == 2) return '⛅';
  if (code == 3) return '☁️';
  if (code == 45 || code == 48) return '🌫️';
  if (code >= 51 && code <= 55) return '🌧️';
  if (code >= 61 && code <= 65) return '🌧️';
  if (code >= 71 && code <= 75) return '❄️';
  if (code >= 80 && code <= 82) return '🌧️';
  if (code >= 95 && code <= 99) return '⛈️';
  return '🌡️';
}

final weatherProvider = FutureProvider<WeatherInfo?>((ref) async {
  try {
    double lat = 0.0;
    double lon = 0.0;
    String locationStr = 'Unknown Location';

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();        

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (serviceEnabled &&
        (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always)) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 10));
        lat = position.latitude;
        lon = position.longitude;
      } catch (e) {
        /* ignore */
      }
    }

    // Default to Dhaka if we can't get any location, or maybe return null so it doesn't show randomly?
    // Returning null if coordinates not found will hide the weather widget or show error.
    if (lat == 0.0 && lon == 0.0) {
      return null;
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final validParts = <String>[];
        
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          validParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          validParts.add(place.locality!);
        }
        if (validParts.isEmpty && place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
          validParts.add(place.subAdministrativeArea!);
        }
        if (validParts.isEmpty && place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          validParts.add(place.administrativeArea!);
        }
        if (validParts.isEmpty && place.country != null && place.country!.isNotEmpty) {
          validParts.add(place.country!);
        }

        if (validParts.isNotEmpty) {
          locationStr = validParts.join(', ');
        }
      }
    } catch (e) {
      // Fallback if Geocoding fails (e.g. some Emulators)
      locationStr = 'Lat: ${lat.toStringAsFixed(2)}, Lon: ${lon.toStringAsFixed(2)}';
    }

    final weatherUrl =
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code&hourly=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&forecast_days=2&timezone=auto';
    final weatherRes = await http.get(Uri.parse(weatherUrl));

    if (weatherRes.statusCode != 200) return null;
    final weatherData = jsonDecode(weatherRes.body);

    final currentObj = weatherData['current'];
    final currentTemp = (currentObj['temperature_2m'] as num).toDouble();      
    final currentCode = (currentObj['weather_code'] as num).toInt();

    final dailyObj = weatherData['daily'];
    final maxTemp = (dailyObj['temperature_2m_max'][0] as num).toDouble();     
    final minTemp = (dailyObj['temperature_2m_min'][0] as num).toDouble();     

    final times = List<String>.from(weatherData['hourly']['time']);
    final temps = List<double>.from(
      weatherData['hourly']['temperature_2m'].map((e) => (e as num).toDouble())
    );
    final codes = List<int>.from(
      weatherData['hourly']['weather_code'].map((e) => (e as num).toInt()),    
    );

    List<HourlyWeather> hourlyForecast = [];
    final now = DateTime.now();

    for (int i = 0; i < times.length; i++) {
      final time = DateTime.parse(times[i]);
      if (time.isAfter(now.subtract(const Duration(hours: 1))) &&
          time.isBefore(now.add(const Duration(hours: 24)))) {
        hourlyForecast.add(
          HourlyWeather(
            time: time,
            temperature: temps[i],
            weatherCode: codes[i],
          ),
        );
      }
    }

    return WeatherInfo(
      locationName: locationStr,
      currentTemp: currentTemp,
      currentCondition: _getConditionText(currentCode),
      maxTemp: maxTemp,
      minTemp: minTemp,
      hourly: hourlyForecast,
    );
  } catch (e) {
    return null;
  }
});
