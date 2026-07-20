import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherApiKeyNotifier extends StateNotifier<AsyncValue<String>> {
  WeatherApiKeyNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('weather_api_key') ?? '';
    state = AsyncValue.data(savedKey);
  }

  Future<void> saveKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weather_api_key', key);
    state = AsyncValue.data(key);
  }
}

final weatherApiKeyProvider = StateNotifierProvider<WeatherApiKeyNotifier, AsyncValue<String>>((ref) {
  return WeatherApiKeyNotifier();
});

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

  String get icon => getWeatherIcon(weatherCode, isDay);
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

// WeatherAPI standardized codes
String getWeatherIcon(int code, bool isDay) {
  final text = code.toString().toLowerCase();
  
  if (text.contains('1000')) return isDay ? '☀️' : '🌙'; // Sunny/Clear
  if (text.contains('1003') || text.contains('1006') || text.contains('1009')) return isDay ? '🌤️' : '☁️'; // Clouds
  if (text.contains('1030') || text.contains('1135') || text.contains('1147')) return '🌫️'; // Mist/Fog
  
  // Rain
  if (text.contains('1063') || text.contains('1150') || text.contains('1153') || 
      text.contains('1180') || text.contains('1183') || text.contains('1186') || 
      text.contains('1189') || text.contains('1192') || text.contains('1195') || 
      text.contains('1240') || text.contains('1243') || text.contains('1246')) {
    return '🌧️';
  }
  
  // Snow/Sleet/Ice
  if (text.contains('1066') || text.contains('1069') || text.contains('1072') || 
      text.contains('1114') || text.contains('1117') || text.contains('1168') || 
      text.contains('1171') || text.contains('1198') || text.contains('1201') || 
      text.contains('1204') || text.contains('1207') || text.contains('1210') || 
      text.contains('1213') || text.contains('1216') || text.contains('1219') || 
      text.contains('1222') || text.contains('1225') || text.contains('1237') || 
      text.contains('1249') || text.contains('1252') || text.contains('1255') || 
      text.contains('1258') || text.contains('1261') || text.contains('1264')) {
    return '❄️';
  }
  
  // Thunder
  if (text.contains('1087') || text.contains('1273') || text.contains('1276') || 
      text.contains('1279') || text.contains('1282')) {
    return '⛈️';
  }

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
      locationStr = 'Lat: ${lat.toStringAsFixed(2)}, Lon: ${lon.toStringAsFixed(2)}';
    }

    final apiKeyAsync = ref.watch(weatherApiKeyProvider);
    final customApiKey = apiKeyAsync.value ?? '';
    final apiKey = customApiKey.isNotEmpty ? customApiKey : (dotenv.env['WEATHER_API_KEY'] ?? '');
    
    if (apiKey.isEmpty) return null;

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
