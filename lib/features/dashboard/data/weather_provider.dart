import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class HourlyWeather {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  final bool isDay;
  final String conditionText;

  HourlyWeather({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.isDay,
    required this.conditionText,
  });

  String get icon => _getIcon(
    weatherCode,
    isDay: isDay,
    conditionText: conditionText,
  );
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

String _getIcon(
  int code, {
  required bool isDay,
  required String conditionText,
}) {
  final text = conditionText.toLowerCase();

  if (text.contains('thunder')) return '⛈️';
  if (text.contains('snow') || text.contains('sleet') || text.contains('blizzard')) return '❄️';
  if (text.contains('rain') || text.contains('drizzle') || text.contains('shower')) return '🌧️';
  if (text.contains('fog') || text.contains('mist') || text.contains('haze')) return '🌫️';

  // WeatherAPI standardized codes
  if (code == 1000) return isDay ? '☀️' : '🌙'; // Sunny/Clear
  if (code == 1003) return isDay ? '⛅' : '☁️'; // Partly cloudy
  if (code == 1006) return '☁️'; // Cloudy
  if (code == 1009) return '☁️'; // Overcast
  if (code == 1030) return '🌫️'; // Mist
  if (code == 1063 || code == 1180 || code == 1183) return '🌦️'; // Patchy rain
  if (code >= 1186 && code <= 1201) return '🌧️'; // Rain
  if (code >= 1087 && code <= 1282) return '⛈️'; // Thunder/heavy
  if (code >= 1066 && code <= 1114) return '❄️'; // Snow

  if (text.contains('cloud')) return '☁️';
  if (text.contains('clear') || text.contains('sunny')) return isDay ? '☀️' : '🌙';

  return isDay ? '🌤️' : '🌙';
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

    final apiKey = dotenv.env['WEATHER_API_KEY'] ?? '';
    final weatherUrl =
        'https://api.weatherapi.com/v1/forecast.json?key=$apiKey&q=$lat,$lon&days=2&aqi=no&alerts=no';
    final weatherRes = await http.get(Uri.parse(weatherUrl));

    if (weatherRes.statusCode != 200) return null;
    final weatherData = jsonDecode(weatherRes.body);

    final currentObj = weatherData['current'];
    final currentTemp = (currentObj['temp_c'] as num).toDouble();
    final conditionText = currentObj['condition']['text'] as String;

    final todayForecast = weatherData['forecast']['forecastday'][0]['day'];
    final maxTemp = (todayForecast['maxtemp_c'] as num).toDouble();
    final minTemp = (todayForecast['mintemp_c'] as num).toDouble();

    List<HourlyWeather> hourlyForecast = [];
    final now = DateTime.now();

    // WeatherAPI returns hourly data inside forecastday array.
    // We combine today and tomorrow's hours to get a smooth 24h timeline.
    final allHours = [
      ...weatherData['forecast']['forecastday'][0]['hour'],
      ...weatherData['forecast']['forecastday'][1]['hour']
    ];

    for (var hourObj in allHours) {
      final time = DateTime.parse(hourObj['time']);
      if (time.isAfter(now.subtract(const Duration(hours: 1))) &&
          time.isBefore(now.add(const Duration(hours: 24)))) {
        hourlyForecast.add(
          HourlyWeather(
            time: time,
            temperature: (hourObj['temp_c'] as num).toDouble(),
            weatherCode: (hourObj['condition']['code'] as num).toInt(),
            isDay: ((hourObj['is_day'] as num?)?.toInt() ?? (time.hour >= 6 && time.hour < 18 ? 1 : 0)) == 1,
            conditionText: (hourObj['condition']['text'] as String?) ?? '',
          ),
        );
      }
    }

    return WeatherInfo(
      locationName: locationStr,
      currentTemp: currentTemp,
      currentCondition: conditionText, // Using text provided by WeatherAPI directly (e.g. "Sunny", "Light rain")
      maxTemp: maxTemp,
      minTemp: minTemp,
      hourly: hourlyForecast,
    );
  } catch (e) {
    return null;
  }
});
