import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/event_repository.dart';
import '../../services/weather_sensing_service.dart';

/// Bottom sheet widget allowing users to select how their weather location is tracked.
/// Supports both automatic (IP-based GeoIP lookup) and manual city search using Open-Meteo Geocoding.
class WeatherLocationBottomSheet extends StatefulWidget {
  const WeatherLocationBottomSheet({super.key});

  @override
  State<WeatherLocationBottomSheet> createState() => _WeatherLocationBottomSheetState();
}

class _WeatherLocationBottomSheetState extends State<WeatherLocationBottomSheet> {
  bool _useManual = false;
  bool _isLoading = false;
  String? _currentLocationName;
  double? _currentLat;
  double? _currentLon;
  
  // Search query & results
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useManual = prefs.getBool('weather_use_manual_location') ?? false;
      _currentLocationName = prefs.getString('weather_location_name');
      _currentLat = prefs.getDouble('weather_lat');
      _currentLon = prefs.getDouble('weather_lon');
    });
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ipResponse = await http
          .get(Uri.parse('http://ip-api.com/json/'))
          .timeout(const Duration(seconds: 5));
      if (ipResponse.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(ipResponse.body);
        if (data['status'] == 'success') {
          final lat = double.tryParse(data['lat'].toString());
          final lon = double.tryParse(data['lon'].toString());
          if (lat != null && lon != null) {
            final city = data['city']?.toString() ?? '';
            final region = data['regionName']?.toString() ?? '';
            final country = data['country']?.toString() ?? '';
            final parts = [city, region, country].where((s) => s.isNotEmpty).join(', ');
            final resolvedName = parts.isNotEmpty ? parts : 'Unknown';

            final prefs = await SharedPreferences.getInstance();
            await prefs.setDouble('weather_lat', lat);
            await prefs.setDouble('weather_lon', lon);
            await prefs.setString('weather_location_name', resolvedName);
            await prefs.setInt('weather_last_geoip_lookup_time', DateTime.now().millisecondsSinceEpoch);

            setState(() {
              _currentLat = lat;
              _currentLon = lon;
              _currentLocationName = resolvedName;
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Estimated Location Detected: $resolvedName'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } else {
          throw Exception(data['message'] ?? 'Lookup returned status: fail');
        }
      } else {
        throw Exception('Server returned status code: ${ipResponse.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to detect location: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchCity(query);
    });
  }

  Future<void> _searchCity(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final url = 'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(cleanQuery)}&count=5&language=en&format=json';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final resultsList = data['results'] as List<dynamic>?;
        if (resultsList != null) {
          setState(() {
            _searchResults = resultsList.map((item) => Map<String, dynamic>.from(item)).toList();
          });
        } else {
          setState(() {
            _searchResults = [];
          });
        }
      }
    } catch (e) {
      debugPrint('[WeatherLocationBottomSheet] City search failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _saveSelection({
    required bool useManual,
    double? lat,
    double? lon,
    String? name,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('weather_use_manual_location', useManual);
      
      if (useManual) {
        if (lat != null && lon != null && name != null) {
          await prefs.setDouble('weather_lat', lat);
          await prefs.setDouble('weather_lon', lon);
          await prefs.setString('weather_location_name', name);
        }
      } else {
        // Switching back to Automatic. If current cached coordinates are missing, detect location.
        if (_currentLat == null || _currentLon == null) {
          await _detectLocation();
        }
      }

      // Sync weather for today immediately in background using the new coordinates
      if (mounted) {
        final eventRepo = context.read<EventRepository>();
        final weather = WeatherSensingService(eventRepo: eventRepo);
        
        // Fire-and-forget sync for today
        unawaited(weather.syncWeather(DateTime.now()).catchError((e) {
          debugPrint('[WeatherLocationBottomSheet] Immediate weather sync failed: $e');
        }));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(useManual 
              ? 'Saved manual location: $name' 
              : 'Switched to Automatic IP location detection'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weather Location',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Choose how your weather telemetry is collected',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Segmented Button
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(
                value: false,
                label: Text('Automatic (GeoIP)'),
                icon: Icon(Icons.compass_calibration_rounded),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Manual Search'),
                icon: Icon(Icons.search_rounded),
              ),
            ],
            selected: <bool>{_useManual},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() {
                _useManual = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 24),

          // Content body based on selection
          if (!_useManual) ...[
            // Automatic Mode
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withAlpha(50),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CURRENT DETECTED LOCATION',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_currentLocationName != null) ...[
                    Text(
                      _currentLocationName!,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coordinates: Lat=${_currentLat?.toStringAsFixed(4)}, Lon=${_currentLon?.toStringAsFixed(4)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'No estimated location resolved yet.',
                      style: textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Detect Location Button
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _detectLocation,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: const Text('Detect Current Location Now'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Save/Confirm Button
            FilledButton(
              onPressed: _isLoading ? null : () => _saveSelection(useManual: false),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Use Automatic Location', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            // Manual Mode
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Type a city name (e.g. London, Vienna)...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 16),
            
            if (_isSearching) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (_searchResults.isNotEmpty) ...[
              Text(
                'SEARCH RESULTS',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => const Divider(height: 8),
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    final name = item['name']?.toString() ?? '';
                    final admin1 = item['admin1']?.toString() ?? '';
                    final country = item['country']?.toString() ?? '';
                    
                    final parts = [name, admin1, country].where((s) => s.isNotEmpty).join(', ');
                    final lat = double.tryParse(item['latitude'].toString()) ?? 0.0;
                    final lon = double.tryParse(item['longitude'].toString()) ?? 0.0;
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(
                        parts,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
                      onTap: () => _saveSelection(
                        useManual: true,
                        lat: lat,
                        lon: lon,
                        name: parts,
                      ),
                    );
                  },
                ),
              ),
            ] else if (_searchController.text.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'No cities found for "${_searchController.text}"',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.map_rounded, size: 48, color: colorScheme.onSurfaceVariant.withAlpha(100)),
                      const SizedBox(height: 8),
                      Text(
                        'Enter a city name to search.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
