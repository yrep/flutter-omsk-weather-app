import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_app/weather_data.dart';
import 'package:weather_app/api_key.dart';

class WeatherScreen extends StatefulWidget {
  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with WidgetsBindingObserver {
  WeatherData? weatherData;
  String? errorMessage;
  bool isLoading = false;
  String city = 'Omsk';
  Timer? updateTimer;
  bool hasInternetAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWeatherData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    updateTimer?.cancel();
    super.dispose();
  }

  Future<bool> _internet() async {
    try {
      final result = await http.get(Uri.parse('https://www.google.com'));
      if(result.statusCode==200){
        return true;
      }
      else{
        return false;
      }
    }
    on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _loadWeatherData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? lastUpdated = prefs.getInt('lastUpdate');
    DateTime lastRequestTime = lastUpdated != null
        ? DateTime.fromMillisecondsSinceEpoch(lastUpdated)
        : DateTime(1970);

    if (DateTime.now().difference(lastRequestTime).inMinutes < 60) {
      String? weatherJson = prefs.getString('weatherData');
      if (weatherJson != null && weatherJson.isNotEmpty) {
        try {
          setState(() {
            weatherData = WeatherData.fromJsonCache(jsonDecode(weatherJson));
          });
        } catch (e) {
          print(e);
          setState(() {
            errorMessage = 'Ошибка при загрузке сохранённых данных. Нажмите на кнопку обновить для получения новых данных.';
          });
        }
      } else {
        await _fetchWeatherData();
      }
    } else {
      await _fetchWeatherData();
    }
  }

  Future<void> _fetchWeatherData() async {

    hasInternetAccess = await _internet();

    if (!hasInternetAccess) {
      setState(() {
        errorMessage = "Нет доступа к интернету. Подключитесь к интернету или предоставьте доступ приложению.";
      });
      return;
    }

    const String apiUrl = 'https://api.weatherapi.com/v1/current.json?key=$apiKey&q=';

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(apiUrl + city)).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newWeatherData = WeatherData.fromJson(data);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('weatherData', jsonEncode(newWeatherData.toJson()));
        await prefs.setInt('lastUpdate', DateTime.now().millisecondsSinceEpoch);

        setState(() {
          weatherData = newWeatherData;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Город не найден';
          isLoading = false;
        });
      }
    } catch (e) {
      print(e);
      if (e is TimeoutException) {
        setState(() {
          errorMessage = 'Проблема с сетевым подключением или сервис недоступен. Попробуйте позже. ${e}';
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Ошибка сети: $e';
          isLoading = false;
        });
      }
    }
  }

  void _changeCity(String newCity) {
    setState(() {
      city = newCity;
      weatherData = null;
      errorMessage = null;
    });
    _fetchWeatherData();
    Navigator.pop(context);
  }

  void _showCityChangeDialog() {
    final cityController = TextEditingController(text: city);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Изменить город'),
          content: TextField(
            controller: cityController,
            decoration: InputDecoration(labelText: 'Город'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                _changeCity(cityController.text);
              },
              child: Text('Изменить'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Отмена'),
            ),
          ],
        );
      },
    );
  }

  void _clearData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('weatherData');
    await prefs.remove('lastUpdate');

    setState(() {
      weatherData = null;
      errorMessage = null;
    });
  }

  void _startUpdateTimer() {
    updateTimer?.cancel();
    updateTimer = Timer(Duration(minutes: 60), () {
      _fetchWeatherData();
    });
  }

  void _onAppResumed() {
    _loadWeatherData();
    _startUpdateTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      updateTimer?.cancel();
    }
  }

  Widget _buildErrorMessage() {
    if (errorMessage == null) return SizedBox.shrink();

    return Column(
      children: [
        Text(
          errorMessage!,
          style: TextStyle(
            color: Colors.red,
            fontSize: 18,
          ),
        ),
        if (errorMessage == 'Город не найден') ...[
          SizedBox(height: 10),
          InkWell(
            onTap: () {
              setState(() {
                city = 'Omsk';
                weatherData = null;
                errorMessage = null;
              });
              _fetchWeatherData();
            },
            child: Text(
              'Показать погоду в Омске',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: Text('Погода в Омске'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _showCityChangeDialog,
          )
        ],
      ),
      body: Column(
        children: [
          if (city != 'Omsk') ...[
            InkWell(
              onTap: () {
                setState(() {
                  city = 'Omsk';
                  weatherData = null;
                  errorMessage = null;
                });
                _fetchWeatherData();
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Вернуться к погоде в Омске',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : weatherData == null
                  ? Center(child: _buildErrorMessage())
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weatherData?.city ?? '',
                        style: TextStyle(
                            fontSize: 48, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: _showCityChangeDialog,
                        child: Text(
                          'изменить',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Image.network('https:${weatherData?.icon}'),
                  SizedBox(height: 20),
                  Text(
                    '${weatherData?.tempC}°C',
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text('Условия: ${weatherData?.condition}', style: Theme.of(context).textTheme.bodyLarge,),
                  Text('Скорость ветра: ${weatherData?.windKph} км/ч', style: Theme.of(context).textTheme.bodyLarge,),
                  Text('Влажность: ${weatherData?.humidity}%', style: Theme.of(context).textTheme.bodyLarge,),
                ],
              ),
            ),
          ),
          Container(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _clearData,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        padding: EdgeInsets.all(28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // No rounded corners (no frame)
                        foregroundColor: Colors.blue,
                        backgroundColor: Colors.grey[200],
                      ),
                      child: Text('Очистить'),
                    ),
                  ),
                  SizedBox(
                    width: 2,
                    ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _fetchWeatherData,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        padding: EdgeInsets.all(28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // No rounded corners (no frame)
                        foregroundColor: Colors.blue,
                        backgroundColor: Colors.grey[200],
                      ),
                      child: Text('Обновить'),
                    ),
                  ),
                ],
              )
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFFFFFFF)
    ),
    debugShowCheckedModeBanner: false,
    home: WeatherScreen(),
  ));
}
