import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/rideshare_service.dart';
import '../services/riderequest_service.dart';
import '../services/friends_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RideshareScreen extends StatefulWidget {
  final String? source;
  final String? destination;

  const RideshareScreen({super.key, this.source, this.destination});

  @override
  State<RideshareScreen> createState() => _RideshareScreenState();
}

class _RideshareScreenState extends State<RideshareScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> ridePosts = [];
  List<Map<String, dynamic>> filteredRidePosts = [];
  bool isLoading = false;
  String? errorMessage;
  User? currentUser;
  final TextEditingController sourceController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController searchSourceController = TextEditingController();
  final TextEditingController searchDestinationController =
      TextEditingController();
  String? selectedGender;
  bool isSearching = false;
  bool isFindRideExpanded = false;
  Map<String, List<Map<String, dynamic>>> rideRequests = {};
  Map<String, List<Map<String, dynamic>>> rideParticipants = {};
  List<Map<String, dynamic>> userRides = [];
  bool isYourRideExpanded = false;
  List<Map<String, dynamic>> friends = [];
  bool isLoadingFriends = false;
  Map<String, String> userRequestStatus = {};
  double? estimatedDistanceKm;
  double? estimatedFare;
  bool isFareCalculating = false;
  Timer? _fareDebounce;
  final Map<String, Map<String, double>> _fareCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        _loadRidePosts();
        _loadUserRides();
        if (currentUser != null) {
          _loadUserRequestStatus();
        }
      }
    });
    _loadCurrentUser();
    _loadRidePosts();
    _loadUserRides();

    if (widget.source != null) {
      sourceController.text = widget.source!;
    }
    if (widget.destination != null) {
      destinationController.text = widget.destination!;
    }

    // Trigger fare calculation if both source and destination are pre-filled
    if (widget.source != null && widget.destination != null) {
      print(
          'Pre-filled values detected: source="${widget.source}", destination="${widget.destination}"');
      print(
          'Source length: ${widget.source!.length}, Destination length: ${widget.destination!.length}');

      // Use a small delay to ensure the controllers are properly set
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          print('Triggering automatic fare calculation...');
          print(
              'Controllers set - Source: "${sourceController.text}", Destination: "${destinationController.text}"');
          _forceFareCalculation();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (currentUser != null) {
      _loadUserRequestStatus();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    sourceController.dispose();
    destinationController.dispose();
    searchSourceController.dispose();
    searchDestinationController.dispose();
    _fareDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      print('Loading current user...');
      final user = await AuthService.getUser();
      print('Current user loaded: ${user?.id}, ${user?.name}');
      setState(() {
        currentUser = user;
      });

      if (user != null) {
        await _loadUserRides();
        await _loadFriends();
        await _loadUserRequestStatus();
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  Future<void> _loadUserRequestStatus() async {
    if (currentUser == null) return;

    try {
      final response =
          await RideRequestService.getUserRequests(currentUser!.id);
      if (response['success']) {
        final requests = List<Map<String, dynamic>>.from(response['data']);
        final statusMap = <String, String>{};

        for (final request in requests) {
          statusMap[request['ridePostId']] = request['status'];
        }

        setState(() {
          userRequestStatus = statusMap;
        });
      }
    } catch (e) {
      print('Error loading user request status: $e');
    }
  }

  Future<Map<String, double>?> _geocode(String query) async {
    try {
      print('Geocoding query: "$query"');

      // Try multiple geocoding strategies
      final result = await _tryGeocodingStrategies(query);
      if (result != null) {
        return result;
      }

      // If all strategies fail, try with simplified address
      final simplifiedQuery = _simplifyAddress(query);
      if (simplifiedQuery != query) {
        print('Trying simplified address: "$simplifiedQuery"');
        final simplifiedResult = await _tryGeocodingStrategies(simplifiedQuery);
        if (simplifiedResult != null) {
          return simplifiedResult;
        }
      }

      // Last resort: try with just the first meaningful part
      final fallbackQuery = _getFallbackAddress(query);
      if (fallbackQuery != query && fallbackQuery != simplifiedQuery) {
        print('Trying fallback address: "$fallbackQuery"');
        final fallbackResult = await _tryGeocodingStrategies(fallbackQuery);
        if (fallbackResult != null) {
          return fallbackResult;
        }
      }

      print('All geocoding strategies failed for: "$query"');
      return null;
    } catch (e) {
      print('Geocoding error for "$query": $e');
      return null;
    }
  }

  Future<Map<String, double>?> _tryGeocodingStrategies(String query) async {
    // Strategy 1: Try with Bangladesh country code
    final result1 = await _geocodeWithParams(query, {'countrycodes': 'bd'});
    if (result1 != null) return result1;

    // Strategy 2: Try without country restriction
    final result2 = await _geocodeWithParams(query, {});
    if (result2 != null) return result2;

    // Strategy 3: Try with Dhaka context
    final result3 = await _geocodeWithParams('$query, Dhaka, Bangladesh', {});
    if (result3 != null) return result3;

    // Strategy 4: Try with just the main part of the address
    final mainPart = _extractMainAddressPart(query);
    if (mainPart != query) {
      final result4 = await _geocodeWithParams('$mainPart, Dhaka', {});
      if (result4 != null) return result4;
    }

    return null;
  }

  Future<Map<String, double>?> _geocodeWithParams(
      String query, Map<String, String> params) async {
    try {
      final defaultParams = {
        'q': query,
        'format': 'json',
        'limit': '1',
        'addressdetails': '1',
      };

      final allParams = {...defaultParams, ...params};

      final uri =
          Uri.parse('https://nominatim.openstreetmap.org/search').replace(
        queryParameters: allParams,
      );

      print('Geocoding URL: $uri');

      final res = await http.get(
        uri,
        headers: {'User-Agent': 'CSE471-Project/1.0 (rideshare)'},
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Geocoding request timed out for: "$query"');
          throw TimeoutException(
              'Geocoding request timed out', Duration(seconds: 10));
        },
      );

      if (res.statusCode != 200) {
        print('Geocoding failed with status: ${res.statusCode}');
        return null;
      }

      final list = json.decode(res.body) as List<dynamic>;
      if (list.isEmpty) {
        return null;
      }

      final item = list.first as Map<String, dynamic>;
      final lat = double.tryParse(item['lat']?.toString() ?? '');
      final lon = double.tryParse(item['lon']?.toString() ?? '');

      if (lat == null || lon == null) {
        return null;
      }

      // Validate coordinates are reasonable for Bangladesh
      if (lat < 20.0 || lat > 27.0 || lon < 88.0 || lon > 93.0) {
        print(
            'Warning: Coordinates outside Bangladesh bounds: lat=$lat, lon=$lon');
        // Don't return null here, just log the warning
      }

      print('Geocoding successful for "$query": lat=$lat, lon=$lon');
      return {'lat': lat, 'lon': lon};
    } catch (e) {
      print('Geocoding error for "$query": $e');
      return null;
    }
  }

  String _simplifyAddress(String address) {
    // Remove common suffixes and prefixes that might cause geocoding issues
    String simplified = address.trim();

    // Remove postal codes
    simplified = simplified.replaceAll(RegExp(r'\b\d{4}\b'), '');

    // Remove common building/floor indicators
    simplified = simplified.replaceAll(
        RegExp(
            r'\b(floor|fl|room|rm|apt|apartment|suite|ste|building|bldg|tower|plaza|mall|center|centre|complex)\b',
            caseSensitive: false),
        '');

    // Remove specific numbers that might be house numbers
    simplified = simplified.replaceAll(RegExp(r'^\d+\s+'), '');

    // Clean up extra spaces and commas
    simplified = simplified.replaceAll(RegExp(r'\s+'), ' ').trim();
    simplified = simplified.replaceAll(RegExp(r',+'), ',').trim();

    // Remove trailing commas
    if (simplified.endsWith(',')) {
      simplified = simplified.substring(0, simplified.length - 1).trim();
    }

    print('Simplified address: "$address" -> "$simplified"');
    return simplified;
  }

  String _extractMainAddressPart(String address) {
    // Extract the main part of the address (usually the first meaningful part)
    final parts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return address;

    // Take the first 1-2 meaningful parts
    if (parts.length >= 2) {
      return '${parts[0]}, ${parts[1]}';
    } else {
      return parts[0];
    }
  }

  String _getFallbackAddress(String address) {
    // Create a very simple fallback address
    final parts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'Dhaka';

    // Take just the first meaningful part and add Dhaka
    final firstPart = parts.first;
    if (firstPart.toLowerCase().contains('dhaka') ||
        firstPart.toLowerCase().contains('dhaaka')) {
      return firstPart;
    }

    return '$firstPart, Dhaka';
  }

  Future<Map<String, double>?> _computeFare(
      String source, String destination) async {
    final key =
        '${source.trim().toLowerCase()}|${destination.trim().toLowerCase()}';
    if (_fareCache.containsKey(key)) return _fareCache[key];

    print('Computing fare for: $source -> $destination');

    // Try geocoding first
    final src = await _geocode(source);
    final dst = await _geocode(destination);
    
    if (src != null && dst != null) {
      // Calculate distance using Haversine formula
      final km = const Distance().as(
        LengthUnit.Kilometer,
        LatLng(src['lat']!, src['lon']!),
        LatLng(dst['lat']!, dst['lon']!),
      );

      // Round to 1 decimal place for better display
      final roundedKm = (km * 10).round() / 10;
      final fare = roundedKm * 30.0;

      print('Geocoding successful: ${roundedKm}km (৳${fare.toStringAsFixed(0)})');

      final result = <String, double>{
        'distanceKm': roundedKm, 
        'fare': fare
      };
      _fareCache[key] = result;
      return result;
    }

    // If geocoding fails, always use fallback estimation
    print('Geocoding failed, using fallback estimation');
    final estimatedDistance = _estimateDistanceFromAddresses(source, destination);
    
    if (estimatedDistance != null) {
      final fare = estimatedDistance * 30.0;
      print('Fallback estimation: ${estimatedDistance}km (৳${fare.toStringAsFixed(0)})');

      final result = <String, double>{
        'distanceKm': estimatedDistance,
        'fare': fare
      };
      _fareCache[key] = result;
      return result;
    }

    // Last resort: provide a reasonable default
    print('All methods failed, using default estimation');
    final defaultDistance = 10.0; // Default 10km
    final defaultFare = defaultDistance * 30.0;
    
    final result = <String, double>{
      'distanceKm': defaultDistance,
      'fare': defaultFare
    };
    _fareCache[key] = result;
    return result;
  }

  double? _estimateDistanceFromAddresses(String source, String destination) {
    try {
      // Common Dhaka area distances (in km) - expanded list
      final commonAreas = {
        'gulshan': {'lat': 23.7937, 'lon': 90.4066},
        'banani': {'lat': 23.7941, 'lon': 90.4065},
        'dhanmondi': {'lat': 23.7467, 'lon': 90.3708},
        'mohammadpur': {'lat': 23.7645, 'lon': 90.3650},
        'uttara': {'lat': 23.8700, 'lon': 90.3800},
        'mirpur': {'lat': 23.8067, 'lon': 90.3683},
        'lalbagh': {'lat': 23.7167, 'lon': 90.3833},
        'old dhaka': {'lat': 23.7167, 'lon': 90.3833},
        'rampura': {'lat': 23.7500, 'lon': 90.4000},
        'badda': {'lat': 23.7833, 'lon': 90.4167},
        'tejgaon': {'lat': 23.7667, 'lon': 90.4000},
        'farmgate': {'lat': 23.7500, 'lon': 90.3833},
        'shahbagh': {'lat': 23.7333, 'lon': 90.3833},
        'tajgaon': {'lat': 23.7667, 'lon': 90.4000},
        'kakrail': {'lat': 23.7333, 'lon': 90.4000},
        'paltan': {'lat': 23.7333, 'lon': 90.4000},
        'motijheel': {'lat': 23.7167, 'lon': 90.4000},
        'sadarghat': {'lat': 23.7167, 'lon': 90.4000},
        'chittagong road': {'lat': 23.7167, 'lon': 90.4000},
        'airport': {'lat': 23.8700, 'lon': 90.3800},
        'tongi': {'lat': 23.9000, 'lon': 90.4000},
        'gazipur': {'lat': 23.9500, 'lon': 90.4000},
        'narayanganj': {'lat': 23.6167, 'lon': 90.5000},
        'savar': {'lat': 23.8500, 'lon': 90.2500},
        'bashundhara': {'lat': 23.8000, 'lon': 90.4200},
        'baridhara': {'lat': 23.8000, 'lon': 90.4200},
        'niketon': {'lat': 23.7900, 'lon': 90.4100},
        'mohakhali': {'lat': 23.7800, 'lon': 90.4000},
        'khilgaon': {'lat': 23.7500, 'lon': 90.4200},
        'demra': {'lat': 23.7500, 'lon': 90.4500},
        'jatrabari': {'lat': 23.7167, 'lon': 90.4500},
        'sutrapur': {'lat': 23.7167, 'lon': 90.4000},
        'wari': {'lat': 23.7167, 'lon': 90.4000},
        'azimpur': {'lat': 23.7167, 'lon': 90.4000},
        'new market': {'lat': 23.7333, 'lon': 90.3833},
        'kalabagan': {'lat': 23.7500, 'lon': 90.3700},
        'adabor': {'lat': 23.7500, 'lon': 90.3700},
        'agargaon': {'lat': 23.7667, 'lon': 90.3833},
        'sher-e-bangla nagar': {'lat': 23.7667, 'lon': 90.3833},
      };

      // Find source and destination in common areas
      String? sourceArea;
      String? destArea;

      for (final entry in commonAreas.entries) {
        if (source.toLowerCase().contains(entry.key)) {
          sourceArea = entry.key;
        }
        if (destination.toLowerCase().contains(entry.key)) {
          destArea = entry.key;
        }
      }

      if (sourceArea != null && destArea != null && sourceArea != destArea) {
        final srcCoords = commonAreas[sourceArea]!;
        final dstCoords = commonAreas[destArea]!;

        final km = const Distance().as(
          LengthUnit.Kilometer,
          LatLng(srcCoords['lat']!, srcCoords['lon']!),
          LatLng(dstCoords['lat']!, dstCoords['lon']!),
        );

        final roundedKm = (km * 10).round() / 10;
        print(
            'Estimated distance using common areas: $sourceArea -> $destArea = ${roundedKm}km');
        return roundedKm;
      }

      // If no common areas found, provide a reasonable estimate based on text length and content
      final sourceWords = source
          .toLowerCase()
          .split(RegExp(r'[,\s]+'))
          .where((word) => word.length > 2)
          .length;
      final destWords = destination
          .toLowerCase()
          .split(RegExp(r'[,\s]+'))
          .where((word) => word.length > 2)
          .length;

      // Simple heuristic: more specific addresses usually mean longer distances
      final totalWords = sourceWords + destWords;
      if (totalWords >= 8) {
        return 15.0; // Long detailed addresses
      } else if (totalWords >= 5) {
        return 10.0; // Medium detailed addresses
      } else {
        return 8.0; // Short addresses
      }
    } catch (e) {
      print('Error estimating distance: $e');
      return null;
    }
  }

  Map<String, dynamic>? _computeIndividualFare(
      Map<String, dynamic> post, Map<String, double>? fareData) {
    if (fareData == null) return null;

    final requests = rideRequests[post['_id']] ?? [];
    final acceptedRequests =
        requests.where((req) => req['status'] == 'accepted').toList();

    // Always include the ride creator as a participant
    final totalParticipants = acceptedRequests.length + 1; // +1 for the creator
    final totalFare = fareData['fare'] ?? 0;

    // If no participants yet, individual fare equals total fare
    final individualFare =
        totalParticipants > 1 ? totalFare / totalParticipants : totalFare;

    print('Individual fare calculation for post ${post['_id']}:');
    print('  - Accepted requests: ${acceptedRequests.length}');
    print('  - Total participants: $totalParticipants');
    print('  - Total fare: ৳${totalFare.toStringAsFixed(0)}');
    print('  - Individual fare: ৳${individualFare.toStringAsFixed(0)}');

    return {
      'originalFare': totalFare,
      'individualFare': individualFare,
      'participantCount': totalParticipants,
    };
  }

  void _scheduleFareCalculation() {
    final src = sourceController.text.trim();
    final dst = destinationController.text.trim();
    _fareDebounce?.cancel();
    if (src.isEmpty || dst.isEmpty) {
      setState(() {
        estimatedDistanceKm = null;
        estimatedFare = null;
        isFareCalculating = false;
      });
      return;
    }
    setState(() {
      isFareCalculating = true;
    });
    _fareDebounce = Timer(const Duration(milliseconds: 600), () async {
      final result = await _computeFare(src, dst);
      if (!mounted) return;
      setState(() {
        estimatedDistanceKm = result?['distanceKm'];
        estimatedFare = result?['fare'];
        isFareCalculating = false;
      });
    });
  }

  void _forceFareCalculation() async {
    final src = sourceController.text.trim();
    final dst = destinationController.text.trim();

    print(
        'Force fare calculation called with: source="$src", destination="$dst"');

    if (src.isEmpty || dst.isEmpty) {
      print('Empty source or destination, clearing fare state');
      setState(() {
        estimatedDistanceKm = null;
        estimatedFare = null;
        isFareCalculating = false;
      });
      return;
    }

    setState(() {
      isFareCalculating = true;
    });

    try {
      print('Starting fare calculation...');
      final result = await _computeFare(src, dst).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          print('Fare calculation timed out after 30 seconds');
          return null;
        },
      );

      if (!mounted) return;

      if (result != null) {
        print(
            'Fare calculation successful: ${result['distanceKm']}km, ৳${result['fare']}');
        setState(() {
          estimatedDistanceKm = result['distanceKm'];
          estimatedFare = result['fare'];
          isFareCalculating = false;
        });
      } else {
        print('Fare calculation returned null result');
        _showFareCalculationError();
      }
    } catch (e) {
      print('Error calculating fare: $e');
      if (!mounted) return;
      _showFareCalculationError();
    }
  }

  bool _shouldShowCalculateFareButton() {
    final src = sourceController.text.trim();
    final dst = destinationController.text.trim();
    return src.isNotEmpty &&
        dst.isNotEmpty &&
        estimatedFare == null &&
        !isFareCalculating;
  }

  void _showFareCalculationError() {
    if (!mounted) return;

    setState(() {
      isFareCalculating = false;
      estimatedDistanceKm = null;
      estimatedFare = null;
    });

    // Show a snackbar with error message and helpful tips
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fare calculation failed',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Try using simpler addresses (e.g., "Gulshan" instead of full address)',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _forceFareCalculation,
        ),
      ),
    );
  }

  void _applySearch() {
    print(
        'Applying search. Source: "${searchSourceController.text}", Destination: "${searchDestinationController.text}"');
    print('Total ride posts: ${ridePosts.length}');

    if (searchSourceController.text.isEmpty &&
        searchDestinationController.text.isEmpty) {
      setState(() {
        filteredRidePosts = ridePosts.where((post) {
          if (currentUser != null && post['userId'] == currentUser!.id) {
            return false;
          }
          return true;
        }).toList();
        isSearching = false;
      });
    } else {
      setState(() {
        filteredRidePosts = ridePosts.where((post) {
          if (currentUser != null && post['userId'] == currentUser!.id) {
            return false;
          }

          final source = post['source']?.toString().toLowerCase() ?? '';
          final destination =
              post['destination']?.toString().toLowerCase() ?? '';
          final searchSource = searchSourceController.text.toLowerCase();
          final searchDestination =
              searchDestinationController.text.toLowerCase();

          bool matchesSource =
              searchSource.isEmpty || source.contains(searchSource);
          bool matchesDestination = searchDestination.isEmpty ||
              destination.contains(searchDestination);

          return matchesSource && matchesDestination;
        }).toList();
        isSearching = true;
      });
    }

    print('Filtered ride posts: ${filteredRidePosts.length}');
  }

  Future<void> _loadRidePosts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      print('Loading ride posts...');
      final response = await RideshareService.getAllRidePosts();
      print('Ride posts API response: $response');
      if (response['success']) {
        setState(() {
          ridePosts = List<Map<String, dynamic>>.from(response['data']);
          filteredRidePosts = ridePosts.where((post) {
            if (currentUser != null && post['userId'] == currentUser!.id) {
              return false;
            }

            return true;
          }).toList();
          isLoading = false;
        });

        print(
            'Loaded ${ridePosts.length} ride posts, filtered to ${filteredRidePosts.length}');
        print('Current user ID: ${currentUser?.id}');
        for (final post in ridePosts.take(3)) {
          print(
              'Post: ${post['_id']}, userId: ${post['userId']}, source: ${post['source']}, destination: ${post['destination']}');
        }

        await _loadRideRequests();
        if (currentUser != null) {
          await _loadUserRequestStatus();
        }
        _applySearch();
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load ride posts';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadUserRides() async {
    if (currentUser == null) return;

    try {
      final response = await RideshareService.getUserRides(currentUser!.id);
      if (response['success']) {
        setState(() {
          userRides = List<Map<String, dynamic>>.from(response['data']);
        });

        await _loadRideRequests();
        if (currentUser != null) {
          await _loadUserRequestStatus();
        }
      }
    } catch (e) {
      print('Error loading user rides: $e');
    }
  }

  Future<void> _loadRideRequests() async {
    final allPosts = [...ridePosts, ...userRides];

    for (final post in allPosts) {
      try {
        final response = await RideRequestService.getRideRequests(post['_id']);
        if (response['success']) {
          setState(() {
            rideRequests[post['_id']] =
                List<Map<String, dynamic>>.from(response['data']);
          });
        }
      } catch (e) {
        print('Error loading ride requests for post ${post['_id']}: $e');
      }
    }
  }

  Future<void> _loadFriends() async {
    if (currentUser == null) return;

    print('Loading friends for user: ${currentUser!.id}');
    setState(() {
      isLoadingFriends = true;
    });

    try {
      final response = await FriendsService.getFriends();
      print('Friends API response: $response');

      if (response['success']) {
        setState(() {
          friends = List<Map<String, dynamic>>.from(response['data']);
          isLoadingFriends = false;
        });
        print('Friends loaded successfully: ${friends.length} friends');
      } else {
        setState(() {
          isLoadingFriends = false;
        });
        print('Failed to load friends: ${response['message']}');
      }
    } catch (e) {
      setState(() {
        isLoadingFriends = false;
      });
      print('Error loading friends: $e');
    }
  }

  Future<void> _sendRideRequest(String ridePostId) async {
    if (currentUser == null) return;

    try {
      final response = await RideRequestService.sendRideRequest(
        ridePostId: ridePostId,
        requesterId: currentUser!.id,
        requesterName: currentUser!.name,
        requesterGender: currentUser!.gender ?? 'Not specified',
      );

      if (response['success']) {
        setState(() {
          userRequestStatus[ridePostId] = 'pending';
        });
        await _loadRideRequests();
        await _loadUserRequestStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride request sent successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to send ride request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending ride request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptRideRequest(String requestId, String ridePostId) async {
    try {
      final response = await RideRequestService.acceptRideRequest(
        requestId: requestId,
        ridePostId: ridePostId,
      );

      if (response['success']) {
        await _loadRideRequests();
        await _loadRidePosts();
        await _loadUserRides();
        if (currentUser != null) {
          await _loadUserRequestStatus();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ride request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(response['message'] ?? 'Failed to accept ride request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting ride request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectRideRequest(String requestId) async {
    try {
      final response = await RideRequestService.rejectRideRequest(requestId);

      if (response['success']) {
        await _loadRideRequests();
        if (currentUser != null) {
          await _loadUserRequestStatus();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ride request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(response['message'] ?? 'Failed to reject ride request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting ride request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRequestButton(Map<String, dynamic> post) {
    if (currentUser == null) return SizedBox.shrink();

    final postId = post['_id'];
    final requestStatus = userRequestStatus[postId];

    print(
        'Building request button for post: $postId, status: $requestStatus, currentUser: ${currentUser?.id}');

    if (requestStatus == 'pending') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Text(
          'Request Pending',
          style: TextStyle(
            color: Colors.orange[700],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (requestStatus == 'accepted') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green[300]!),
        ),
        child: Text(
          'Request Accepted',
          style: TextStyle(
            color: Colors.green[700],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (requestStatus == 'rejected') {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red[300]!),
        ),
        child: Text(
          'Request Rejected',
          style: TextStyle(
            color: Colors.red[700],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => _sendRideRequest(postId),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      child: Text(
        'Request to Join',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAcceptedParticipantsSection(Map<String, dynamic> post) {
    final requests = rideRequests[post['_id']] ?? [];
    final acceptedRequests =
        requests.where((req) => req['status'] == 'accepted').toList();

    // Create a list of all participants including the ride creator
    final allParticipants = <Map<String, dynamic>>[];

    // Add the ride creator as the first participant
    allParticipants.add({
      'requesterName': post['userName'] ?? 'Unknown User',
      'isCreator': true,
    });

    // Add accepted participants
    allParticipants.addAll(acceptedRequests.map((req) => {
          ...req,
          'isCreator': false,
        }));

    if (allParticipants.length <= 1) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700], size: 16),
              SizedBox(width: 8),
              Text(
                'Participants (${allParticipants.length})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allParticipants
                .map((participant) => Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: participant['isCreator'] == true
                            ? Colors.orange[100]
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: participant['isCreator'] == true
                              ? Colors.orange[300]!
                              : Colors.green[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundColor: participant['isCreator'] == true
                                ? Colors.orange[200]
                                : Colors.green[200],
                            radius: 12,
                            child: Text(
                              participant['requesterName']?[0]?.toUpperCase() ??
                                  'U',
                              style: TextStyle(
                                color: participant['isCreator'] == true
                                    ? Colors.orange[700]
                                    : Colors.green[700],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '${participant['requesterName'] ?? 'Unknown User'}${participant['isCreator'] == true ? ' (Creator)' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: participant['isCreator'] == true
                                  ? Colors.orange[700]
                                  : Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRideRequestsSection(Map<String, dynamic> post) {
    final requests = rideRequests[post['_id']] ?? [];
    final pendingRequests =
        requests.where((req) => req['status'] == 'pending').toList();

    if (pendingRequests.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending Requests (${pendingRequests.length})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
          SizedBox(height: 8),
          ...pendingRequests
              .map((request) => Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          radius: 16,
                          child: Text(
                            request['requesterName']?[0]?.toUpperCase() ?? 'U',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request['requesterName'] ?? 'Unknown User',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Gender: ${request['requesterGender'] ?? 'Not specified'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => _acceptRideRequest(
                                  request['_id'], post['_id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: Text(
                                'Accept',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () =>
                                  _rejectRideRequest(request['_id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: Text(
                                'Reject',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  bool _hasExistingPost() {
    if (currentUser == null) return false;
    return ridePosts.any((post) => post['userId'] == currentUser!.id);
  }

  Map<String, dynamic>? _getExistingPost() {
    if (currentUser == null) return null;
    try {
      return ridePosts.firstWhere((post) => post['userId'] == currentUser!.id);
    } catch (e) {
      return null;
    }
  }

  Widget _buildExistingPostCard(Map<String, dynamic> post) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Text(
                'From: ${post['source'] ?? 'Unknown location'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.flag, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Text(
                'To: ${post['destination'] ?? 'Unknown location'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Posted ${_formatDate(DateTime.parse(post['createdAt'] ?? DateTime.now().toIso8601String()))}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 8),
          FutureBuilder<Map<String, double>?>(
            future:
                _computeFare(post['source'] ?? '', post['destination'] ?? ''),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Calculating fare...'),
                  ],
                );
              }
              final data = snapshot.data;
              if (data == null) return SizedBox.shrink();
              final km = data['distanceKm'] ?? 0;
              final fare = data['fare'] ?? 0;

              // Calculate individual fare
              final individualFareData = _computeIndividualFare(post, data);
              final originalFare = individualFareData?['originalFare'] ?? fare;
              final individualFare =
                  individualFareData?['individualFare'] ?? fare;
              final participantCount =
                  individualFareData?['participantCount'] ?? 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments, color: Colors.blue, size: 16),
                      SizedBox(width: 6),
                      Text(
                        '${km.toStringAsFixed(1)} km · ৳${originalFare.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  if (participantCount > 1) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people, color: Colors.green, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Individual: ৳${individualFare.toStringAsFixed(0)} (${participantCount.toInt()} participants)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _postRide() async {
    if (sourceController.text.trim().isEmpty ||
        destinationController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter both source and destination';
      });
      return;
    }

    if (estimatedFare == null || estimatedDistanceKm == null) {
      setState(() {
        errorMessage = 'Please wait for fare estimation to complete';
      });
      return;
    }

    if (currentUser == null) {
      setState(() {
        errorMessage = 'Please login to post a ride';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await RideshareService.createRidePost(
        source: sourceController.text.trim(),
        destination: destinationController.text.trim(),
        userId: currentUser!.id,
        userName: currentUser!.name,
        gender: currentUser!.gender ?? 'Not specified',
      );

      if (response['success']) {
        sourceController.clear();
        destinationController.clear();
        setState(() {
          estimatedDistanceKm = null;
          estimatedFare = null;
        });
        await _loadRidePosts();
        await _loadUserRides();
        await _loadRideRequests();
        if (currentUser != null) {
          await _loadUserRequestStatus();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride posted successfully!')),
        );
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to post ride';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _deleteRidePost(String postId) async {
    try {
      final response = await RideshareService.deleteRidePost(postId);
      if (response['success']) {
        await _loadRidePosts();
        await _loadUserRides();
        await _loadRideRequests();
        if (currentUser != null) {
          await _loadUserRequestStatus();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride post deleted successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(response['message'] ?? 'Failed to delete ride post')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting ride post')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildYourRideSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                isYourRideExpanded = !isYourRideExpanded;
              });
            },
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_car,
                    color: Colors.green,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Your Ride',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    isYourRideExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (isYourRideExpanded) ...[
            SizedBox(height: 16),
            if (userRides.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No rides yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Post a ride or join one to see it here',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: userRides.length,
                itemBuilder: (context, index) {
                  final post = userRides[index];
                  final isOwnPost = currentUser?.id == post['userId'];

                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isOwnPost ? Icons.star : Icons.person_add,
                                color: isOwnPost ? Colors.orange : Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                isOwnPost ? 'Your Post' : 'Joined Ride',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isOwnPost
                                      ? Colors.orange[700]
                                      : Colors.blue[700],
                                ),
                              ),
                              Spacer(),
                              if (isOwnPost)
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteRidePost(post['_id']),
                                ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.location_on,
                                            color: Colors.green, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          'From:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      post['source'] ?? 'Unknown location',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.flag,
                                            color: Colors.red, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          'To:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      post['destination'] ?? 'Unknown location',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Posted ${_formatDate(DateTime.parse(post['createdAt'] ?? DateTime.now().toIso8601String()))}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          SizedBox(height: 8),
                          FutureBuilder<Map<String, double>?>(
                            future: _computeFare(post['source'] ?? '',
                                post['destination'] ?? ''),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                );
                              }
                              final data = snapshot.data;
                              if (data == null) return SizedBox.shrink();
                              final km = data['distanceKm'] ?? 0;
                              final fare = data['fare'] ?? 0;

                              // Calculate individual fare
                              final individualFareData =
                                  _computeIndividualFare(post, data);
                              final originalFare =
                                  individualFareData?['originalFare'] ?? fare;
                              final individualFare =
                                  individualFareData?['individualFare'] ?? fare;
                              final participantCount =
                                  individualFareData?['participantCount'] ?? 1;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.payments,
                                          color: Colors.blue, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        '${km.toStringAsFixed(1)} km · ৳${originalFare.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (participantCount > 1) ...[
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.people,
                                            color: Colors.green, size: 14),
                                        SizedBox(width: 6),
                                        Text(
                                          'Individual: ৳${individualFare.toStringAsFixed(0)} (${participantCount.toInt()} participants)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          if (isOwnPost) ...[
                            _buildAcceptedParticipantsSection(post),
                            _buildRideRequestsSection(post),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFindRideSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                isFindRideExpanded = !isFindRideExpanded;
              });
            },
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Colors.blue,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Find a Ride',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    isFindRideExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (isFindRideExpanded) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search & Filter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: searchSourceController,
                    decoration: InputDecoration(
                      hintText: 'Search by source location',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      prefixIcon: Icon(Icons.location_on, color: Colors.green),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: searchDestinationController,
                    decoration: InputDecoration(
                      hintText: 'Search by destination location',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      prefixIcon: Icon(Icons.flag, color: Colors.red),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _applySearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Search',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            searchSourceController.clear();
                            searchDestinationController.clear();
                            _applySearch();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            if (isSearching)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing ${filteredRidePosts.length} of ${ridePosts.length} results',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (isLoading)
              Center(child: CircularProgressIndicator())
            else if (filteredRidePosts.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      isSearching ? Icons.search_off : Icons.local_taxi,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      isSearching
                          ? 'No matching rides found'
                          : 'No ride posts available',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      isSearching
                          ? 'Try adjusting your search criteria or filters'
                          : 'Be the first to post a ride request!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: filteredRidePosts.length,
                itemBuilder: (context, index) {
                  final post = filteredRidePosts[index];
                  final isOwnPost = currentUser?.id == post['userId'];

                  print(
                      'Building ride post item $index: ${post['_id']}, source: ${post['source']}, destination: ${post['destination']}');

                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: Text(
                                  post['userName']?.isNotEmpty == true
                                      ? post['userName'][0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post['userName'] ?? 'Unknown User',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.wc,
                                            color: Colors.purple, size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          post['gender'] ?? 'Not specified',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isOwnPost)
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteRidePost(post['_id']),
                                ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.location_on,
                                            color: Colors.green, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          'From:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      post['source'] ?? 'Unknown location',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.flag,
                                            color: Colors.red, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          'To:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      post['destination'] ?? 'Unknown location',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Posted ${_formatDate(DateTime.parse(post['createdAt'] ?? DateTime.now().toIso8601String()))}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              _buildRequestButton(post),
                            ],
                          ),
                          SizedBox(height: 8),
                          FutureBuilder<Map<String, double>?>(
                            future: _computeFare(post['source'] ?? '',
                                post['destination'] ?? ''),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                );
                              }
                              final data = snapshot.data;
                              if (data == null) return SizedBox.shrink();
                              final km = data['distanceKm'] ?? 0;
                              final fare = data['fare'] ?? 0;

                              // Calculate individual fare
                              final individualFareData =
                                  _computeIndividualFare(post, data);
                              final originalFare =
                                  individualFareData?['originalFare'] ?? fare;
                              final individualFare =
                                  individualFareData?['individualFare'] ?? fare;
                              final participantCount =
                                  individualFareData?['participantCount'] ?? 1;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.payments,
                                          color: Colors.blue, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        '${km.toStringAsFixed(1)} km · ৳${originalFare.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (participantCount > 1) ...[
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.people,
                                            color: Colors.green, size: 14),
                                        SizedBox(width: 6),
                                        Text(
                                          'Individual: ৳${individualFare.toStringAsFixed(0)} (${participantCount.toInt()} participants)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          _buildAcceptedParticipantsSection(post),
                          _buildRideRequestsSection(post),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 245),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Rideshare',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: [
            Tab(
              icon: Icon(Icons.post_add),
              text: 'Post',
            ),
            Tab(
              icon: Icon(Icons.people),
              text: 'Friend',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostScreen(),
          _buildFriendScreen(),
        ],
      ),
    );
  }

  Widget _buildPostScreen() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadRidePosts();
        await _loadUserRides();
        if (currentUser != null) {
          await _loadUserRequestStatus();
        }
      },
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Post a Ride',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12),
                  if (_hasExistingPost()) ...[
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.orange[700], size: 20),
                              SizedBox(width: 8),
                              Text(
                                'You already have an active ride post',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildExistingPostCard(_getExistingPost()!),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _deleteRidePost(_getExistingPost()!['_id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Delete Current Post',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: sourceController,
                      onChanged: (_) {
                        _scheduleFareCalculation();
                        // Clear previous fare when source changes
                        if (estimatedFare != null) {
                          setState(() {
                            estimatedDistanceKm = null;
                            estimatedFare = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter source location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon:
                            Icon(Icons.location_on, color: Colors.green),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: destinationController,
                      onChanged: (_) {
                        _scheduleFareCalculation();
                        // Clear previous fare when destination changes
                        if (estimatedFare != null) {
                          setState(() {
                            estimatedDistanceKm = null;
                            estimatedFare = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter destination location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: Icon(Icons.flag, color: Colors.red),
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_taxi, color: Colors.blue),
                          SizedBox(width: 8),
                          if (isFareCalculating)
                            Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Estimating fare...'),
                              ],
                            )
                          else if (estimatedFare != null &&
                              estimatedDistanceKm != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${estimatedDistanceKm!.toStringAsFixed(1)} km · ৳${estimatedFare!.toStringAsFixed(0)} (৳30/km)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                  if (_fareCache[
                                          '${sourceController.text.trim().toLowerCase()}|${destinationController.text.trim().toLowerCase()}'] !=
                                      null)
                                    Text(
                                      'Fare calculated automatically',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          else
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sourceController.text.trim().isNotEmpty &&
                                            destinationController.text
                                                .trim()
                                                .isNotEmpty
                                        ? 'Click Calculate Fare to see pricing'
                                        : 'Enter source and destination to see fare (৳30/km)',
                                    style: TextStyle(color: Colors.blue[800]),
                                  ),
                                  if (_shouldShowCalculateFareButton()) ...[
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: _forceFareCalculation,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue[600],
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            child: Text(
                                              'Calculate Fare',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () {
                                            print('=== DEBUG INFO ===');
                                            print(
                                                'Source: "${sourceController.text}"');
                                            print(
                                                'Destination: "${destinationController.text}"');
                                            print(
                                                'Source length: ${sourceController.text.length}');
                                            print(
                                                'Destination length: ${destinationController.text.length}');
                                            print(
                                                'Estimated fare: $estimatedFare');
                                            print(
                                                'Estimated distance: $estimatedDistanceKm');
                                            print(
                                                'Is calculating: $isFareCalculating');
                                            print('==================');
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[600],
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: Text(
                                            'Debug',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (sourceController.text.trim().isNotEmpty &&
                                      destinationController.text
                                          .trim()
                                          .isNotEmpty &&
                                      estimatedFare == null &&
                                      !isFareCalculating) ...[
                                    SizedBox(height: 8),
                                    Text(
                                      'If geocoding fails, try using more specific addresses',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    if (currentUser != null) ...[
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.blue, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Posted by: ${currentUser!.name}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(width: 16),
                          Icon(Icons.wc, color: Colors.purple, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Gender: ${currentUser!.gender ?? 'Not specified'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (isLoading || currentUser == null)
                            ? null
                            : _postRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              currentUser == null ? Colors.grey : Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          currentUser == null ? 'Login Required' : 'Post Ride',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (errorMessage != null)
              Container(
                width: double.infinity,
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            _buildYourRideSection(),
            _buildFindRideSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendScreen() {
    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        color: Colors.blue,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Friends',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.blue),
                        onPressed: _loadFriends,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildFriendsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (isLoadingFriends) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (friends.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No friends yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add friends to see them here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Text(
                  friend['name']![0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend['name']!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      friend['email']!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  _inviteFriend(friend);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  'Invite to Ride',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _inviteFriend(Map<String, dynamic> friend) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite functionality will be implemented later'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
