import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const MyApp());

// Data Models
class WeatherDetail {
  final String title;
  final String value;
  final IconData icon;

  const WeatherDetail({
    required this.title,
    required this.value,
    required this.icon,
  });
}

class DailyForecast {
  final String day;
  final int high;
  final int low;
  final IconData icon;
  final String condition;

  const DailyForecast({
    required this.day,
    required this.high,
    required this.low,
    required this.icon,
    required this.condition,
  });
}

class HourlyForecast {
  final String time;
  final int temp;
  final IconData icon;
  final String condition;

  const HourlyForecast({
    required this.time,
    required this.temp,
    required this.icon,
    required this.condition,
  });
}

class CurrentWeather {
  final int temp;
  final String condition;
  final String location;
  final int high;
  final int low;
  final IconData icon;

  const CurrentWeather({
    required this.temp,
    required this.condition,
    required this.location,
    required this.high,
    required this.low,
    required this.icon,
  });
}

// API Models

class WeatherApiResponse {
  final Location location;
  final Current current;
  final Forecast forecast;

  WeatherApiResponse({
    required this.location,
    required this.current,
    required this.forecast,
  });

  factory WeatherApiResponse.fromJson(Map<String, dynamic> json) {
    return WeatherApiResponse(
      location: Location.fromJson(json['location']),
      current: Current.fromJson(json['current']),
      forecast: Forecast.fromJson(json['forecast']),
    );
  }
}

class Location {
  final String name;
  final String region;
  final String country;

  Location({
    required this.name,
    required this.region,
    required this.country,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      name: json['name'],
      region: json['region'],
      country: json['country'],
    );
  }
}

class Current {
  final double tempC;
  final Condition condition;
  final double windKph;
  final int humidity;
  final double pressureMb;
  final double uv;

  Current({
    required this.tempC,
    required this.condition,
    required this.windKph,
    required this.humidity,
    required this.pressureMb,
    required this.uv,
  });

  factory Current.fromJson(Map<String, dynamic> json) {
    return Current(
      tempC: json['temp_c'],
      condition: Condition.fromJson(json['condition']),
      windKph: json['wind_kph'],
      humidity: json['humidity'],
      pressureMb: json['pressure_mb'],
      uv: json['uv'],
    );
  }
}

class Condition {
  final String text;
  final String icon;

  Condition({
    required this.text,
    required this.icon,
  });

  factory Condition.fromJson(Map<String, dynamic> json) {
    return Condition(
      text: json['text'],
      icon: json['icon'],
    );
  }
}

class Forecast {
  final List<ForecastDay> forecastday;

  Forecast({
    required this.forecastday,
  });

  factory Forecast.fromJson(Map<String, dynamic> json) {
    var list = json['forecastday'] as List;
    List<ForecastDay> forecastDays = list.map((i) => ForecastDay.fromJson(i)).toList();
    return Forecast(forecastday: forecastDays);
  }
}

class ForecastDay {
  final String date;
  final Day day;
  final Astro astro;
  final List<Hour> hour;

  ForecastDay({
    required this.date,
    required this.day,
    required this.astro,
    required this.hour,
  });

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    var hourList = json['hour'] as List;
    List<Hour> hours = hourList.map((i) => Hour.fromJson(i)).toList();
    return ForecastDay(
      date: json['date'],
      day: Day.fromJson(json['day']),
      astro: Astro.fromJson(json['astro']),
      hour: hours,
    );
  }
}

class Astro {
  final String sunrise;
  final String sunset;

  Astro({
    required this.sunrise,
    required this.sunset,
  });

  factory Astro.fromJson(Map<String, dynamic> json) {
    return Astro(
      sunrise: json['sunrise'],
      sunset: json['sunset'],
    );
  }
}

class Day {
  final double maxtempC;
  final double mintempC;
  final Condition condition;

  Day({
    required this.maxtempC,
    required this.mintempC,
    required this.condition,
  });

  factory Day.fromJson(Map<String, dynamic> json) {
    return Day(
      maxtempC: json['maxtemp_c'],
      mintempC: json['mintemp_c'],
      condition: Condition.fromJson(json['condition']),
    );
  }
}

class Hour {
  final String time;
  final double tempC;
  final Condition condition;

  Hour({
    required this.time,
    required this.tempC,
    required this.condition,
  });

  factory Hour.fromJson(Map<String, dynamic> json) {
    return Hour(
      time: json['time'],
      tempC: json['temp_c'],
      condition: Condition.fromJson(json['condition']),
    );
  }
}


class WeatherApiException implements Exception {
  final String message;
  final int? statusCode;

  const WeatherApiException({
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'WeatherApiException: $message';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class WeatherService {
  static const String _baseUrl = 'http://api.weatherapi.com/v1';
  static const String _apiKey = 'API_KEY';
  static const String _endpoint = '/forecast.json';
  static const int _days = 7;
  static const Duration _timeoutDuration = Duration(seconds: 10);

  Future<WeatherApiResponse> fetchWeather(String location) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_endpoint?key=$_apiKey&q=$location&days=$_days&aqi=no&alerts=no'),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        return WeatherApiResponse.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']['message'] ?? 'Unknown API error';
        throw WeatherApiException(
          message: errorMessage,
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw const NetworkException('No internet connection');
    } on TimeoutException {
      throw const NetworkException('Request timed out');
    } on FormatException {
      throw WeatherApiException(message: 'Invalid data format from server');
    } on http.ClientException {
      throw const NetworkException('Failed to connect to the server');
    } catch (e) {
      throw WeatherApiException(message: 'Failed to load weather data: ${e.toString()}');
    }
  }
}

// Main App

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'SamsungOne',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
      ),
      home: const WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final WeatherService _weatherService = WeatherService();
  final ScrollController _hourlyScrollController = ScrollController();
  final TextEditingController _locationController = TextEditingController();
  bool _useFahrenheit = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  Position? _currentPosition;
  WeatherApiResponse? _weatherData;
  bool _isLoading = false;
  String _errorMessage = '';
  String _lastLocation = 'Mumbai';
  bool _showingGpsLocation = false;
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
    _initializeLocation();
  }

  @override
  void dispose() {
    _hourlyScrollController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool _shouldShowReturnButton() {
    debugPrint('Should show button? CurrentPosition: $_currentPosition, ShowingGPS: $_showingGpsLocation');
  return _currentPosition != null && !_showingGpsLocation;
}

//   Future<void> _initializeLocation() async {
//   final prefs = await SharedPreferences.getInstance();
//   final savedLocation = prefs.getString('lastLocation');
  
//   if (savedLocation == null) {
//     await _getCurrentLocation(); // Auto-detect on first launch
//   } else {
//     _fetchWeather(savedLocation);
//   }
// }
  Future<void> _initializeApp() async {
    _loadTemperatureUnitPreference();
    await _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocation = prefs.getString('lastLocation');
    
    if (savedLocation != null && savedLocation.isNotEmpty) {
    if (savedLocation.contains(',')) {
      // Handle saved GPS coordinates
      final parts = savedLocation.split(',');
      setState(() {
        _currentPosition = Position(
          latitude: double.parse(parts[0]),
          longitude: double.parse(parts[1]),
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
        _showingGpsLocation = true;
      });
    } else {
      setState(() {
        _showingGpsLocation = false;
      });
    }
    _fetchWeather(savedLocation);
  } else {
      await _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
  setState(() {
    _isLoading = true;
    _errorMessage = ''; 
  });
  
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are required')),
        );
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
    
    await _fetchWeather('${position.latitude},${position.longitude}');
    setState(() {
      _currentPosition = position;
      _showingGpsLocation = true;
    });
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to get location: ${e.toString()}')),
    );
    _setDefaultLocation();
  } finally {
    setState(() => _isLoading = false);
  }
}

  void _setDefaultLocation() async {
  const defaultLocation = 'Mumbai';
  await _fetchWeather(defaultLocation);
}

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  
  Future<void> _saveLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastLocation', location);
  }



  Future<void> _fetchWeather(String location) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _showingGpsLocation = location.contains(',');
    });

    final isConnected = await _checkInternetConnection();
    if (!isConnected) {
      setState(() {
        _errorMessage = 'No internet connection. Showing cached data if available.';
        _isLoading = false;
      });
      return;
    }

    try {
      final weatherData = await _weatherService.fetchWeather(location);
      await _saveLocation(location);
      
      setState(() {
        _weatherData = weatherData;
        _lastLocation = location;
        _isLoading = false;
      });
    } on NetworkException catch (e) {
      setState(() {
        _errorMessage = _getUserFriendlyErrorMessage(e);
        _isLoading = false;
      });
    } on WeatherApiException catch (e) {
      setState(() {
        _errorMessage = _getUserFriendlyErrorMessage(e);
        _isLoading = false;

        if (location.contains(',')) {
        _setDefaultLocation();
      }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTemperatureUnitPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useFahrenheit = prefs.getBool('useFahrenheit') ?? false;
    });
  }

  Future<void> _saveTemperatureUnitPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useFahrenheit', value);
  }

  Future<void> _handleRefresh() async {
    await _fetchWeather(_lastLocation);
  }

  String _formatTemperature(double tempC) {
    if (_useFahrenheit) {
      final tempF = (tempC * 9 / 5) + 32;
      return '${tempF.round()}°F';
    }
    return '${tempC.round()}°C';
  }

  String _getUserFriendlyErrorMessage(Exception e) {
    if (e is NetworkException) {
      return 'Network error: ${e.message}. Please check your internet connection.';
    } else if (e is WeatherApiException) {
      if (e.statusCode == 400) {
        return 'Invalid location. Please try another city.';
      } else if (e.statusCode == 401) {
        return 'Authentication error. Please contact support.';
      } else if (e.statusCode == 404) {
        return 'Weather data not found for this location.';
      } else if (e.statusCode == 500) {
        return 'Server error. Please try again later.';
      } else {
        return e.message;
      }
    }
    return 'An error occurred. Please try again.';
  }

  IconData _getWeatherIcon(String condition, DateTime time) {
    final hour = time.hour;
    final isDayTime = hour >= 6 && hour < 18;
    
    switch (condition.toLowerCase()) {
      case 'sunny':
        return isDayTime ? WeatherIcons.day_sunny : WeatherIcons.night_clear;
      case 'clear':
        return isDayTime ? WeatherIcons.day_sunny : WeatherIcons.night_clear;
      case 'partly cloudy':
        return isDayTime ? WeatherIcons.day_cloudy : WeatherIcons.night_alt_cloudy;
      case 'cloudy':
        return WeatherIcons.cloudy;
      case 'overcast':
        return WeatherIcons.cloud;
      case 'mist':
      case 'fog':
        return WeatherIcons.fog;
      case 'patchy rain possible':
      case 'light rain':
      case 'moderate rain':
      case 'heavy rain':
      case 'light rain shower':
      case 'moderate or heavy rain shower':
      case 'torrential rain shower':
        return isDayTime ? WeatherIcons.day_rain : WeatherIcons.night_rain;
      case 'patchy snow possible':
      case 'light snow':
      case 'moderate snow':
      case 'heavy snow':
      case 'light snow showers':
      case 'moderate or heavy snow showers':
        return isDayTime ? WeatherIcons.day_snow : WeatherIcons.night_snow;
      case 'patchy sleet possible':
      case 'light sleet':
      case 'moderate or heavy sleet':
      case 'light sleet showers':
      case 'moderate or heavy sleet showers':
        return WeatherIcons.sleet;
      case 'patchy freezing drizzle possible':
      case 'freezing drizzle':
      case 'heavy freezing drizzle':
      case 'light freezing rain':
      case 'moderate or heavy freezing rain':
        return WeatherIcons.rain_mix;
      case 'thundery outbreaks possible':
      case 'patchy light rain with thunder':
      case 'moderate or heavy rain with thunder':
        return isDayTime ? WeatherIcons.day_thunderstorm : WeatherIcons.night_thunderstorm;
      default:
        return isDayTime ? WeatherIcons.day_sunny : WeatherIcons.night_clear;
    }
  }

  Color _getBackgroundColor() {
    if (_weatherData == null) return Colors.blue.shade800;
    
    final hour = DateTime.now().hour;
    final isDayTime = hour >= 6 && hour < 18;
    final condition = _weatherData!.current.condition.text.toLowerCase();
    
    if (condition.contains('rain') || condition.contains('drizzle')) {
      return Colors.blueGrey.shade800;
    } else if (condition.contains('snow') || condition.contains('sleet')) {
      return Colors.blue.shade100;
    } else if (condition.contains('thunder')) {
      return Colors.deepPurple.shade800;
    } else if (condition.contains('cloud')) {
      return isDayTime ? Colors.blue.shade600 : Colors.blue.shade900;
    } else {
      return isDayTime ? Colors.blue.shade400 : Colors.blue.shade800;
    }
  }

  CurrentWeather _getCurrentWeather() {
    if (_weatherData == null) {
      return const CurrentWeather(
        temp: 0,
        condition: 'Sunny',
        location: 'Mumbai, Maharashtra',
        high: 0,
        low: 0,
        icon: WeatherIcons.day_sunny,
      );
    }
    
    final current = _weatherData!.current;
    final today = _weatherData!.forecast.forecastday[0].day;
    final location = _weatherData!.location;
    
    return CurrentWeather(
      temp: current.tempC.round(),
      condition: current.condition.text,
      location: '${location.name}, ${location.region}',
      high: today.maxtempC.round(),
      low: today.mintempC.round(),
      icon: _getWeatherIcon(current.condition.text, DateTime.now()),
    );
  }

  List<HourlyForecast> _getHourlyForecast() {
    if (_weatherData == null) {
      return List.generate(24, (index) => HourlyForecast(
        time: '$index:00',
        temp: 18 + (index % 5),
        icon: index < 6 || index > 18 
          ? WeatherIcons.moon_alt_waxing_crescent_3 
          : WeatherIcons.day_sunny,
        condition: index < 6 || index > 18 ? 'Clear' : 'Sunny',
      ));
    }
    
    final now = DateTime.now();
    final currentHour = now.hour;
    final todayHours = _weatherData!.forecast.forecastday[0].hour;
    
    List<Hour> remainingTodayHours = todayHours.where((hour) {
      final hourTime = DateTime.parse(hour.time);
      return hourTime.hour >= currentHour;
    }).toList();
    
    List<Hour> nextDayHours = [];
    if (remainingTodayHours.length < 24 && _weatherData!.forecast.forecastday.length > 1) {
      final tomorrowHours = _weatherData!.forecast.forecastday[1].hour;
      final neededHours = 24 - remainingTodayHours.length;
      nextDayHours = tomorrowHours.take(neededHours).toList();
    }
    
    final allHours = [...remainingTodayHours, ...nextDayHours].take(24).toList();
    
    return allHours.map((hour) {
      final hourTime = DateTime.parse(hour.time);
      return HourlyForecast(
        time: DateFormat('h:mm a').format(hourTime),
        temp: hour.tempC.round(),
        icon: _getWeatherIcon(hour.condition.text, hourTime),
        condition: hour.condition.text,
      );
    }).toList();
  }

  List<DailyForecast> _getDailyForecast() {
    if (_weatherData == null) {
      return const [
        DailyForecast(day: 'Monday', high: 0, low: 0, icon: WeatherIcons.day_sunny, condition: 'Sunny'),
        DailyForecast(day: 'Tuesday', high: 0, low: 0, icon: WeatherIcons.day_cloudy, condition: 'Cloudy'),
        DailyForecast(day: 'Wednesday', high: 0, low: 0, icon: WeatherIcons.rain, condition: 'Rain'),
        DailyForecast(day: 'Thursday', high: 0, low: 0, icon: WeatherIcons.day_cloudy_high, condition: 'Cloudy'),
        DailyForecast(day: 'Friday', high: 0, low: 0, icon: WeatherIcons.day_sunny, condition: 'Sunny'),
        DailyForecast(day: 'Saturday', high: 0, low: 0, icon: WeatherIcons.day_sunny, condition: 'Sunny'),
        DailyForecast(day: 'Sunday', high: 0, low: 0, icon: WeatherIcons.day_sunny_overcast, condition: 'Cloudy'),
      ];
    }
    
    return _weatherData!.forecast.forecastday.map((forecastDay) {
      final date = DateTime.parse(forecastDay.date);
      final dayName = DateFormat('EEEE').format(date);
      final day = forecastDay.day;
      
      return DailyForecast(
        day: dayName,
        high: day.maxtempC.round(),
        low: day.mintempC.round(),
        icon: _getWeatherIcon(day.condition.text, date),
        condition: day.condition.text,
      );
    }).toList();
  }

  List<WeatherDetail> _getWeatherDetails() {
    if (_weatherData == null) {
      return const [
        WeatherDetail(title: 'Humidity', value: '65%', icon: WeatherIcons.humidity),
        WeatherDetail(title: 'Wind', value: '12 km/h', icon: WeatherIcons.strong_wind),
        WeatherDetail(title: 'UV Index', value: '5', icon: WeatherIcons.day_sunny),
        WeatherDetail(title: 'Pressure', value: '1012 hPa', icon: WeatherIcons.barometer),
        WeatherDetail(title: 'Sunrise', value: '6:45 AM', icon: WeatherIcons.sunrise),
        WeatherDetail(title: 'Sunset', value: '7:30 PM', icon: WeatherIcons.sunset),
      ];
    }
    
    final current = _weatherData!.current;
    final astro = _weatherData!.forecast.forecastday[0].astro;
    
    return [
      WeatherDetail(title: 'Humidity', value: '${current.humidity}%', icon: WeatherIcons.humidity),
      WeatherDetail(title: 'Wind', value: '${current.windKph} km/h', icon: WeatherIcons.strong_wind),
      WeatherDetail(title: 'UV Index', value: '${current.uv}', icon: WeatherIcons.day_sunny),
      WeatherDetail(title: 'Pressure', value: '${current.pressureMb} hPa', icon: WeatherIcons.barometer),
      WeatherDetail(title: 'Sunrise', value: astro.sunrise, icon: WeatherIcons.sunrise),
      WeatherDetail(title: 'Sunset', value: astro.sunset, icon: WeatherIcons.sunset),
    ];
  }

  void _showLocationDialog() {
    final currentLocation = _lastLocation;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Enter city name',
                errorText: _locationController.text.isEmpty ? 'Please enter a location' : null,
              ),
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_locationController.text.isEmpty) {
    setState(() {
      _errorMessage = 'Please enter a location';
    });
    return;
  }
  
  try {
    await _fetchWeather(_locationController.text);
    Navigator.pop(context);
    _locationController.clear();
  } catch (e) {
    Navigator.pop(context);
  }
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_locationController.text.isEmpty) {
                setState(() {
                  _errorMessage = 'Please enter a location';
                });
                return;
              }
              
              try {
                await _fetchWeather(_locationController.text);
                Navigator.pop(context);
                _locationController.clear();
              } catch (e) {
                Navigator.pop(context);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentWeather = _getCurrentWeather();
    final hourlyForecast = _getHourlyForecast();
    final dailyForecast = _getDailyForecast();
    final weatherDetails = _getWeatherDetails();

     return Scaffold(
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _handleRefresh,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _getBackgroundColor(),
                _getBackgroundColor().withOpacity(0.8),
                Colors.blue.shade900,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add_location_alt, color: Colors.white),
                        onPressed: _showLocationDialog, 
                      ),
                      Text(
                        currentWeather.location,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _useFahrenheit ? '°F' : '°C',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Switch(
                            value: _useFahrenheit,
                            onChanged: (value) {
                              setState(() {
                                _useFahrenheit = value;
                              });
                              _saveTemperatureUnitPreference(value);
                            },
                            activeColor: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else if (_errorMessage.isNotEmpty)
  Expanded(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.blue, // text color
              backgroundColor: Colors.white, // background color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => _fetchWeather(_lastLocation),
            child: const Text('Try Again'),
          ),
        ],
      ),
    ),
  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                Icon(
                                  currentWeather.icon,
                                  size: 100,
                                  color: Colors.white,
                                ),
                                Text(
                                  _formatTemperature(currentWeather.temp.toDouble()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 72,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                Text(
                                  currentWeather.condition,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'H:${_formatTemperature(currentWeather.high.toDouble())} L:${_formatTemperature(currentWeather.low.toDouble())}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),

                       
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              controller: _hourlyScrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: hourlyForecast.length,
                              itemBuilder: (context, index) {
                                final hour = hourlyForecast[index];
                                return Container(
                                  width: 70,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(hour.time, style: const TextStyle(color: Colors.white)),
                                      const SizedBox(height: 8),
                                      Icon(hour.icon, color: Colors.white),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatTemperature(hour.temp.toDouble()),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                    
                          Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: dailyForecast.map((day) => ListTile(
                                leading: Text(
                                  day.day,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(day.icon, color: Colors.white, size: 20),
                                    const SizedBox(width: 16),
                                    Text(
                                      _formatTemperature(day.high.toDouble()),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      _formatTemperature(day.low.toDouble()),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7)),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),

                        
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              childAspectRatio: 1.8,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: weatherDetails.map((detail) => Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      detail.icon,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      detail.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      detail.value,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _shouldShowReturnButton()
  ? FloatingActionButton(
      mini: true,
      backgroundColor: Colors.white,
      onPressed: () async {
        debugPrint('Current Position: $_currentPosition');
        debugPrint('Showing GPS Location: $_showingGpsLocation');
        await _getCurrentLocation();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Returning to current location')),
        );
      },
      tooltip: 'Return to current location',
      child: const Icon(Icons.gps_fixed, color: Colors.blue),
    )
  : null,
    );
  }
}