import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart' show EventsCompanion;
import '../data/repositories/event_repository.dart';
import '../data/models/enums.dart';

/// Passive background service to retrieve environmental metrics from Open-Meteo
/// and record them as system events.
class WeatherSensingService {
  final EventRepository _eventRepo;

  WeatherSensingService({required EventRepository eventRepo})
      : _eventRepo = eventRepo;

  // Defaults to Graz, Austria (FH Joanneum location) if location resolution fails
  static const double defaultLat = 47.0707;
  static const double defaultLon = 15.4395;

  /// Retrieves weather metrics for a specific calendar day and saves them.
  Future<void> syncWeather(DateTime date, {String? sessionId}) async {
    try {
      final activeSessionId = sessionId ?? const Uuid().v4();
      final prefs = await SharedPreferences.getInstance();

      // 1. Resolve Location Coordinates (Cached or GeoIP)
      final bool useManual = prefs.getBool('weather_use_manual_location') ?? false;
      double? lat = prefs.getDouble('weather_lat');
      double? lon = prefs.getDouble('weather_lon');
      String? locationName = prefs.getString('weather_location_name');
      final int lastLookup = prefs.getInt('weather_last_geoip_lookup_time') ?? 0;
      final int nowMillis = DateTime.now().millisecondsSinceEpoch;

      final bool needsGeoIpLookup = !useManual && 
          (lat == null || lon == null || (nowMillis - lastLookup > 24 * 60 * 60 * 1000));

      if (needsGeoIpLookup) {
        debugPrint('[WeatherSensingService] Fetching IP location (Automatic mode)...');
        try {
          final ipResponse = await http
              .get(Uri.parse('http://ip-api.com/json/'))
              .timeout(const Duration(seconds: 5));
          if (ipResponse.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(ipResponse.body);
            if (data['status'] == 'success') {
              lat = double.tryParse(data['lat'].toString());
              lon = double.tryParse(data['lon'].toString());
              if (lat != null && lon != null) {
                await prefs.setDouble('weather_lat', lat);
                await prefs.setDouble('weather_lon', lon);
                
                final city = data['city']?.toString() ?? '';
                final region = data['regionName']?.toString() ?? '';
                final country = data['country']?.toString() ?? '';
                final parts = [city, region, country].where((s) => s.isNotEmpty).join(', ');
                locationName = parts.isNotEmpty ? parts : 'Unknown';
                await prefs.setString('weather_location_name', locationName);
                await prefs.setInt('weather_last_geoip_lookup_time', nowMillis);

                debugPrint('[WeatherSensingService] IP Geolocation Success: Lat=$lat, Lon=$lon ($locationName)');
              }
            }
          }
        } catch (e) {
          debugPrint('[WeatherSensingService] GeoIP lookup failed: $e');
        }
      }

      // Fallback if IP lookup failed
      lat ??= defaultLat;
      lon ??= defaultLon;

      if (lat == defaultLat && lon == defaultLon) {
        locationName = 'Graz, Styria, Austria (Default)';
      }
      locationName ??= 'Cached Location';

      // Format date for Open-Meteo: YYYY-MM-DD
      final String dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      // 2. Fetch Daily Metrics from Open-Meteo
      final url = 'https://api.open-meteo.com/v1/forecast?'
          'latitude=$lat&longitude=$lon&'
          'daily=rain_sum,shortwave_radiation_sum,wind_speed_10m_max&'
          'timezone=auto&start_date=$dateStr&end_date=$dateStr';

      debugPrint('[WeatherSensingService] Querying Open-Meteo: $url');
      final weatherResponse = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (weatherResponse.statusCode != 200) {
        debugPrint('[WeatherSensingService] Open-Meteo API returned error status: ${weatherResponse.statusCode}');
        return;
      }

      final Map<String, dynamic> weatherData = json.decode(weatherResponse.body);
      final daily = weatherData['daily'];
      if (daily == null) {
        debugPrint('[WeatherSensingService] Weather daily key is missing in API response.');
        return;
      }

      // Open-Meteo returns daily values as lists containing one item for the single date query
      final dynamic rawRain = daily['rain_sum']?[0];
      final dynamic rawSun = daily['shortwave_radiation_sum']?[0];
      final dynamic rawWind = daily['wind_speed_10m_max']?[0];

      if (rawRain == null || rawSun == null || rawWind == null) {
        debugPrint('[WeatherSensingService] Incomplete weather metrics returned.');
        return;
      }

      final double rainSum = double.tryParse(rawRain.toString()) ?? 0.0;
      final double sunRad = double.tryParse(rawSun.toString()) ?? 0.0;
      final double windSpeed = double.tryParse(rawWind.toString()) ?? 0.0;

      // 3. Map values to Covary 1-10 Likert scales
      // Rain: 0.0mm -> 1.0 (Dry), >= 10.0mm -> 10.0 (Downpour)
      final double rainVal = (1.0 + (rainSum * 0.9)).clamp(1.0, 10.0);

      // Sun: 0.0 MJ/m² -> 1.0 (Dark/Overcast), >= 22.5 MJ/m² -> 10.0 (Bright Sunshine)
      final double sunVal = (1.0 + (sunRad / 2.5)).clamp(1.0, 10.0);

      // Wind: 0.0 km/h -> 1.0 (Calm), >= 50.0 km/h -> 10.0 (Gale/Storm)
      final double windVal = (1.0 + (windSpeed / 5.5)).clamp(1.0, 10.0);

      // 4. Log daily events to Database (Deduplicated)
      final timestamp = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final String locationValue = '$locationName ($lat, $lon)';

      await _logDailyWeather(
        category: EventCategory.weather,
        label: 'core_weather_location',
        value: locationValue,
        sessionId: activeSessionId,
        timestamp: timestamp,
      );

      await _logDailyWeather(
        category: EventCategory.weather,
        label: 'core_weather_rain',
        value: rainVal.toStringAsFixed(1),
        sessionId: activeSessionId,
        timestamp: timestamp,
      );

      await _logDailyWeather(
        category: EventCategory.weather,
        label: 'core_weather_sun',
        value: sunVal.toStringAsFixed(1),
        sessionId: activeSessionId,
        timestamp: timestamp,
      );

      await _logDailyWeather(
        category: EventCategory.weather,
        label: 'core_weather_wind',
        value: windVal.toStringAsFixed(1),
        sessionId: activeSessionId,
        timestamp: timestamp,
      );

      debugPrint('[WeatherSensingService] Saved: Rain=${rainVal.toStringAsFixed(1)} (raw:${rainSum}mm), '
          'Sun=${sunVal.toStringAsFixed(1)} (raw:${sunRad}MJ), '
          'Wind=${windVal.toStringAsFixed(1)} (raw:${windSpeed}kmh) for $dateStr '
          'at Location: $locationValue');
    } catch (e) {
      debugPrint('[WeatherSensingService] Error syncing weather metrics: $e');
    }
  }

  /// Writes daily weather record using Drift database helper.
  Future<void> _logDailyWeather({
    required EventCategory category,
    required String label,
    required String value,
    required String sessionId,
    required DateTime timestamp,
  }) async {
    final dayStart = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final dayEnd = dayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    final existing = await _eventRepo.findSystemEvent(
      category: category,
      label: label,
      start: dayStart,
      end: dayEnd,
    );

    if (existing != null) {
      await _eventRepo.updateEvent(
        existing.id,
        EventsCompanion(
          value: Value(value),
          sessionId: Value(sessionId),
          timestamp: Value(timestamp),
        ),
      );
    } else {
      await _eventRepo.insertEvent(
        EventsCompanion(
          category: Value(category),
          label: Value(label),
          value: Value(value),
          latencyMs: const Value(0),
          triggerSource: const Value(TriggerSource.system),
          interactionType: const Value(InteractionType.click),
          sessionId: Value(sessionId),
          timestamp: Value(timestamp),
        ),
      );
    }
  }
}
