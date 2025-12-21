import 'package:flutter/material.dart';
import '../services/bus_service.dart';
import '../services/fav_bus_service.dart';
import '../services/auth_service.dart';
import '../services/rating_service.dart';
import '../models/bus.dart';
import 'review.dart';
import '../utils/loading_widgets.dart';
import '../utils/error_widgets.dart';
import '../utils/app_theme.dart';

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});

  @override
  _BusScreenState createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  List<Bus> allBuses = [];
  List<Bus> filteredBuses = [];
  bool isLoadingAll = false;
  String? errorMessage;
  String? currentUserId;
  String? currentUserGender;
  String? currentUserPass;
  Map<String, bool> favoriteStatus = {};
  Map<String, double> busRatings = {}; // busId -> rating
  bool isLoadingRatings = false;
  
  // Search and filter
  final TextEditingController searchController = TextEditingController();
  String? selectedTypeFilter; // 'women', 'regular'
  String? selectedSortFilter; // 'a-z', 'z-a'
  bool showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _loadAllBuses();
    _getCurrentUserId();
    _loadBusRatings();
    searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadBusRatings() async {
    setState(() {
      isLoadingRatings = true;
    });

    try {
      final result = await RatingService.getAllBusRatings();
      print('Rating service result: $result');
      if (result['success'] && result['data'] != null) {
        final ratingsMap = result['data'] as Map<String, dynamic>;
        print('Ratings map received: ${ratingsMap.keys.length} buses');
        setState(() {
          busRatings = {};
          ratingsMap.forEach((busId, ratingData) {
            if (ratingData is Map && ratingData['averageRating'] != null) {
              final rating = (ratingData['averageRating'] is num)
                  ? ratingData['averageRating'].toDouble()
                  : double.tryParse(ratingData['averageRating'].toString()) ?? 0.0;
              // Store with cleaned busId (trim whitespace)
              final cleanBusId = busId.toString().trim();
              busRatings[cleanBusId] = rating;
              print('Loaded rating for bus $cleanBusId: $rating');
            }
          });
          print('Total ratings loaded: ${busRatings.length}');
          isLoadingRatings = false;
        });
      } else {
        print('Failed to load ratings: ${result['message']}');
        setState(() {
          isLoadingRatings = false;
        });
      }
    } catch (e) {
      print('Error loading bus ratings: $e');
      setState(() {
        isLoadingRatings = false;
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    List<Bus> result = List<Bus>.from(allBuses);
    
    // Apply search filter
    final searchQuery = searchController.text.trim().toLowerCase();
    if (searchQuery.isNotEmpty) {
      result = result.where((bus) {
        return bus.busName.toLowerCase().contains(searchQuery) ||
               (bus.routeNumber != null && bus.routeNumber!.toLowerCase().contains(searchQuery));
      }).toList();
    }
    
    // Apply favorites filter
    if (showFavoritesOnly) {
      result = result.where((bus) => favoriteStatus[bus.id] == true).toList();
    }
    
    // Apply type filter
    if (selectedTypeFilter == 'women') {
      result = result.where((bus) => bus.busType == 'women').toList();
    } else if (selectedTypeFilter == 'regular') {
      result = result.where((bus) => bus.busType != 'women').toList();
    }
    
    // Apply sort filter
    if (selectedSortFilter == 'a-z') {
      result.sort((a, b) => a.busName.compareTo(b.busName));
    } else if (selectedSortFilter == 'z-a') {
      result.sort((a, b) => b.busName.compareTo(a.busName));
    } else if (selectedSortFilter == 'rating') {
      result.sort((a, b) {
        final aRating = busRatings[a.id] ?? 0.0;
        final bRating = busRatings[b.id] ?? 0.0;
        return bRating.compareTo(aRating); // Highest rating first
      });
    }
    
    setState(() {
      filteredBuses = result;
    });
    
    // Reload ratings when buses are filtered
    if (busRatings.isEmpty && !isLoadingRatings) {
      _loadBusRatings();
    }
  }

  Future<void> _getCurrentUserId() async {
    final user = await AuthService.getUser();
    if (user != null) {
      setState(() {
        currentUserId = user.id;
        currentUserGender = user.gender;
        currentUserPass = user.pass;
      });
      _loadFavoriteStatuses();
    }
  }

  Future<void> _loadFavoriteStatuses() async {
    if (currentUserId == null) return;

    for (final bus in allBuses) {
      try {
        final response = await FavBusService.checkIfFavorited(
          userId: currentUserId!,
          busId: bus.id,
        );
        if (response['success']) {
          setState(() {
            favoriteStatus[bus.id] = response['isFavorited'];
          });
        }
      } catch (e) {
        setState(() {
          favoriteStatus[bus.id] = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(Bus bus) async {
    if (currentUserId == null) return;

    if (bus.busType == 'women' && currentUserGender == 'male') {
      ErrorSnackbar.show(
        context,
        'Male users cannot favorite women-designated buses',
      );
      return;
    }

    try {
      if (favoriteStatus[bus.id] == true) {
        await FavBusService.removeFromFavorites(
          userId: currentUserId!,
          busId: bus.id,
        );
        setState(() {
          favoriteStatus[bus.id] = false;
        });
        SuccessSnackbar.show(context, 'Removed from favorites');
        _applyFilters(); // Refresh filter if favorites filter is active
      } else {
        await FavBusService.addToFavorites(
          userId: currentUserId!,
          busId: bus.id,
          busName: bus.busName,
          routeNumber: bus.routeNumber,
          operator: bus.operator,
        );
        setState(() {
          favoriteStatus[bus.id] = true;
        });
        SuccessSnackbar.show(context, 'Added to favorites');
        _applyFilters(); // Refresh filter if favorites filter is active
      }
    } catch (e) {
      ErrorSnackbar.show(
        context,
        'Failed to update favorite: ${e.toString()}',
      );
    }
  }

  Widget _buildBusList() {
    final busesToShow = filteredBuses.isEmpty && 
            searchController.text.isEmpty && 
            selectedTypeFilter == null && 
            selectedSortFilter == null &&
            !showFavoritesOnly
        ? allBuses
        : filteredBuses;

    if (isLoadingAll) {
      return RefreshIndicator(
        onRefresh: _loadAllBuses,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 80, bottom: 8),
          itemCount: 5,
          itemBuilder: (context, index) => const SkeletonCard(),
        ),
      );
    }

    if (errorMessage != null && allBuses.isEmpty) {
      return ErrorDisplayWidget(
        message: errorMessage!,
        onRetry: _loadAllBuses,
      );
    }

    if (busesToShow.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAllBuses,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: EmptyStateWidget(
              title: searchController.text.isNotEmpty || 
                      selectedTypeFilter != null || 
                      selectedSortFilter != null ||
                      showFavoritesOnly
                  ? 'No buses found'
                  : 'No buses available',
              message: searchController.text.isNotEmpty || 
                       selectedTypeFilter != null || 
                       selectedSortFilter != null ||
                       showFavoritesOnly
                  ? 'Try adjusting your search or filter'
                  : 'No buses found in the system',
              icon: Icons.directions_bus_outlined,
              action: () {
                searchController.clear();
                setState(() {
                  selectedTypeFilter = null;
                  selectedSortFilter = null;
                  showFavoritesOnly = false;
                });
                _applyFilters();
              },
              actionLabel: 'Clear',
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllBuses,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 80, bottom: 8),
        itemCount: busesToShow.length,
        itemBuilder: (context, index) {
          final bus = busesToShow[index];
          // Get rating for this bus - match by bus ID
          // The bus.id comes from bus._id in the JSON response
          final busIdStr = bus.id.toString().trim();
          final rating = busRatings[busIdStr] ?? 0.0;
          
          return BusResultCard(
            bus: bus,
            isFavorited: favoriteStatus[bus.id] ?? false,
            onFavoriteToggle: () => _toggleFavorite(bus),
            userPass: currentUserPass,
            currentUserGender: currentUserGender,
            rating: rating,
          );
        },
      ),
    );
  }

  Future<void> _loadAllBuses() async {
    setState(() {
      isLoadingAll = true;
      errorMessage = null;
    });

    try {
      final response = await BusService.getAllBuses();

      if (response['success']) {
        setState(() {
          allBuses = (response['data'] as List)
              .map((json) => Bus.fromJson(json))
              .toList();
          filteredBuses = List<Bus>.from(allBuses);
          isLoadingAll = false;
        });
        _loadFavoriteStatuses();
        _loadBusRatings();
        _applyFilters();
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load buses';
          isLoadingAll = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoadingAll = false;
      });
    }
  }


  void _showBusModal(Bus bus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bus name header
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: bus.busType == 'women'
                          ? LinearGradient(
                              colors: [
                                Colors.pink.shade400,
                                Colors.pink.shade600,
                              ],
                            )
                          : AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.directions_bus_filled,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bus.busName,
                          style: AppTheme.heading3Dark(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (bus.routeNumber != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Route ${bus.routeNumber}',
                            style: AppTheme.bodySmallDark(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Action buttons
              // Add to Favorites
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (bus.busType == 'women' && currentUserGender?.toLowerCase() == 'male')
                      ? null
                      : () {
                          Navigator.pop(context);
                          _toggleFavorite(bus);
                        },
                  icon: Icon(
                    favoriteStatus[bus.id] ?? false
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                  ),
                  label: Text(
                    (bus.busType == 'women' && currentUserGender?.toLowerCase() == 'male')
                        ? 'Not Available for Male Users'
                        : (favoriteStatus[bus.id] ?? false)
                            ? 'Remove from Favorites'
                            : 'Add to Favorites',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (bus.busType == 'women' && currentUserGender?.toLowerCase() == 'male')
                        ? AppTheme.textTertiary.withOpacity(0.1)
                        : (favoriteStatus[bus.id] ?? false)
                            ? AppTheme.accentRed.withOpacity(0.1)
                            : AppTheme.primaryBlue,
                    foregroundColor: (bus.busType == 'women' && currentUserGender?.toLowerCase() == 'male')
                        ? AppTheme.textTertiary
                        : (favoriteStatus[bus.id] ?? false)
                            ? AppTheme.accentRed
                            : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Reviews
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReviewScreen(bus: bus),
                      ),
                    );
                  },
                  icon: const Icon(Icons.reviews_rounded, size: 20),
                  label: const Text('View Reviews'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Details
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showBusDetails(bus);
                  },
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filter Buses',
                style: AppTheme.heading4Dark(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Favourite Buses
              InkWell(
                onTap: () {
                  setState(() {
                    showFavoritesOnly = !showFavoritesOnly;
                  });
                  _applyFilters();
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: showFavoritesOnly 
                        ? AppTheme.accentRed.withOpacity(0.1) 
                        : (isDark ? AppTheme.darkSurface : AppTheme.backgroundLight),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: showFavoritesOnly 
                          ? AppTheme.accentRed 
                          : (isDark ? AppTheme.darkBorder : AppTheme.borderLight),
                      width: showFavoritesOnly ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: AppTheme.accentRed,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child:                         Text(
                          'Favourite Buses',
                          style: AppTheme.bodyLargeDark(context).copyWith(
                            fontWeight: showFavoritesOnly 
                                ? FontWeight.w600 
                                : FontWeight.normal,
                            color: showFavoritesOnly 
                                ? AppTheme.accentRed 
                                : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                          ),
                        ),
                      ),
                      if (showFavoritesOnly)
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.accentRed,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Women Only
              _buildFilterOption(
                icon: Icons.woman,
                label: 'Women Only',
                value: 'women',
                color: Colors.pink,
                isTypeFilter: true,
              ),
              const SizedBox(height: 12),
              // Regular
              _buildFilterOption(
                icon: Icons.people_alt_rounded,
                label: 'Regular',
                value: 'regular',
                color: AppTheme.primaryBlue,
                isTypeFilter: true,
              ),
              const SizedBox(height: 12),
              // A-Z
              _buildFilterOption(
                icon: Icons.sort_by_alpha_rounded,
                label: 'Sort A-Z',
                value: 'a-z',
                color: AppTheme.accentGreen,
                isTypeFilter: false,
              ),
              const SizedBox(height: 12),
              // Z-A
              _buildFilterOption(
                icon: Icons.sort_by_alpha_rounded,
                label: 'Sort Z-A',
                value: 'z-a',
                color: AppTheme.accentOrange,
                isTypeFilter: false,
              ),
              const SizedBox(height: 12),
              // Sort by Rating
              _buildFilterOption(
                icon: Icons.star_rounded,
                label: 'Sort by Rating',
                value: 'rating',
                color: AppTheme.primaryBlue,
                isTypeFilter: false,
              ),
              const SizedBox(height: 12),
              // Clear filter
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      selectedTypeFilter = null;
                      selectedSortFilter = null;
                      showFavoritesOnly = false;
                    });
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.textTertiary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Clear Filter',
                    style: AppTheme.bodyMediumDark(context).copyWith(
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isTypeFilter,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = isTypeFilter
        ? selectedTypeFilter == value
        : selectedSortFilter == value;
    return InkWell(
      onTap: () {
        setState(() {
          if (isTypeFilter) {
            selectedTypeFilter = isSelected ? null : value;
          } else {
            selectedSortFilter = isSelected ? null : value;
          }
        });
        _applyFilters();
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.1) 
              : (isDark ? AppTheme.darkSurface : AppTheme.backgroundLight),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? color 
                : (isDark ? AppTheme.darkBorder : AppTheme.borderLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyLargeDark(context).copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected 
                      ? color 
                      : (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: color,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  void _showBusDetails(Bus bus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: bus.busType == 'women'
                      ? LinearGradient(
                          colors: [
                            Colors.pink.shade400,
                            Colors.pink.shade600,
                          ],
                        )
                      : AppTheme.primaryGradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_bus_filled,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bus.busName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (bus.routeNumber != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Route ${bus.routeNumber}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type and Fare
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: bus.busType == 'women'
                                    ? LinearGradient(
                                        colors: [
                                          Colors.pink.shade50,
                                          Colors.pink.shade100,
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          AppTheme.primaryBlue.withOpacity(0.1),
                                          AppTheme.primaryBlue.withOpacity(0.15),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: bus.busType == 'women'
                                      ? Colors.pink.shade300
                                      : AppTheme.primaryBlue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    bus.busType == 'women'
                                        ? Icons.woman
                                        : Icons.people_alt_rounded,
                                    size: 20,
                                    color: bus.busType == 'women'
                                        ? Colors.pink.shade700
                                        : AppTheme.primaryBlue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    bus.busType == 'women' ? 'WOMEN ONLY' : 'REGULAR',
                                    style: AppTheme.labelLarge.copyWith(
                                      color: bus.busType == 'women'
                                          ? Colors.pink.shade700
                                          : AppTheme.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: AppTheme.accentGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '৳${(currentUserPass == 'student' ? bus.baseFare * 0.5 : bus.baseFare).toStringAsFixed(0)}',
                                  style: AppTheme.heading3.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (currentUserPass == 'student')
                                  Text(
                                    'Student',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Route Information
                        Text(
                          'Route Information',
                          style: AppTheme.heading4Dark(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                          ),
                        ),
                        child: Column(
                          children: bus.stopNames.asMap().entries.map((entry) {
                            int index = entry.key;
                            String stop = entry.value;
                            bool isLast = index == bus.stops.length - 1;
                            bool isFirst = index == 0;
                            
                            return Container(
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(
                                        bottom: BorderSide(
                                          color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                                          width: 1,
                                        ),
                                      ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: isFirst
                                            ? LinearGradient(
                                                colors: [
                                                  AppTheme.accentGreen,
                                                  AppTheme.accentGreen.withOpacity(0.8),
                                                ],
                                              )
                                            : isLast
                                                ? LinearGradient(
                                                    colors: [
                                                      AppTheme.accentRed,
                                                      AppTheme.accentRed.withOpacity(0.8),
                                                    ],
                                                  )
                                                : LinearGradient(
                                                    colors: [
                                                      AppTheme.primaryBlue,
                                                      AppTheme.primaryBlue.withOpacity(0.8),
                                                    ],
                                                  ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isFirst
                                            ? Icons.play_circle_filled_rounded
                                            : isLast
                                                ? Icons.flag_circle_rounded
                                                : Icons.location_on_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                        stop,
                                        style: AppTheme.bodyLargeDark(context).copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isFirst
                                            ? 'Starting Point'
                                            : isLast
                                                ? 'Final Destination'
                                                : 'Stop ${index + 1}',
                                        style: AppTheme.bodySmallDark(context),
                                      ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      if (bus.operator != null || bus.frequency != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Additional Information',
                          style: AppTheme.heading4Dark(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (bus.operator != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : AppTheme.backgroundLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.business_rounded,
                                  color: AppTheme.primaryBlue,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Operator',
                                        style: AppTheme.bodySmallDark(context),
                                      ),
                                      Text(
                                        bus.operator!,
                                        style: AppTheme.bodyLargeDark(context).copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (bus.frequency != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : AppTheme.backgroundLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  color: AppTheme.primaryBlue,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Frequency',
                                        style: AppTheme.bodySmallDark(context),
                                      ),
                                      Text(
                                        bus.frequency!,
                                        style: AppTheme.bodyLargeDark(context).copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              color: AppTheme.accentGreen,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Per Kilometer Fare',
                                    style: AppTheme.bodySmallDark(context),
                                  ),
                                  Text(
                                    '৳${bus.perKmFare.toStringAsFixed(0)}/km',
                                    style: AppTheme.bodyLargeDark(context).copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundLight,
      body: Stack(
        children: [
          _buildBusList(),
          // Fixed search bar at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    // Search bar
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: searchController,
                        builder: (context, value, child) {
                          return TextField(
                            controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search buses...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                              suffixIcon: value.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () {
                                        searchController.clear();
                                      },
                                    )
                                  : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryBlue,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark ? AppTheme.darkSurface : AppTheme.backgroundLight,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _applyFilters(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Search/Cross icon button
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchController,
                      builder: (context, value, child) {
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              value.text.isNotEmpty
                                  ? Icons.close_rounded
                                  : Icons.search_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              if (value.text.isNotEmpty) {
                                searchController.clear();
                              } else {
                                _applyFilters();
                              }
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    // Filter button
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (selectedTypeFilter != null || 
                                selectedSortFilter != null || 
                                showFavoritesOnly)
                            ? AppTheme.primaryBlue
                            : (isDark ? AppTheme.darkSurface : AppTheme.backgroundLight),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (selectedTypeFilter != null || 
                                  selectedSortFilter != null || 
                                  showFavoritesOnly)
                              ? AppTheme.primaryBlue
                              : (isDark ? AppTheme.darkBorder : AppTheme.borderLight),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.tune_rounded,
                          color: (selectedTypeFilter != null || 
                                  selectedSortFilter != null || 
                                  showFavoritesOnly)
                              ? Colors.white
                              : AppTheme.primaryBlue,
                        ),
                        onPressed: _showFilterDialog,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BusResultCard extends StatefulWidget {
  final Bus bus;
  final bool isFavorited;
  final VoidCallback onFavoriteToggle;
  final String? userPass;
  final String? currentUserGender;
  final double rating;

  const BusResultCard({
    super.key,
    required this.bus,
    required this.isFavorited,
    required this.onFavoriteToggle,
    this.userPass,
    this.currentUserGender,
    this.rating = 0.0,
  });

  @override
  _BusResultCardState createState() => _BusResultCardState();
}

class _BusResultCardState extends State<BusResultCard> {
  @override
  Widget build(BuildContext context) {
    final isWomenBus = widget.bus.busType == 'women';
    
    return GestureDetector(
      onTap: () {
        final state = context.findAncestorStateOfType<_BusScreenState>();
        if (state != null) {
          state._showBusModal(widget.bus);
        }
      },
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Bus icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: isWomenBus
                          ? LinearGradient(
                              colors: [
                                Colors.pink.shade400,
                                Colors.pink.shade600,
                              ],
                            )
                          : AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.directions_bus_filled,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Bus info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.bus.busName,
                          style: AppTheme.heading4Dark(context).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: isWomenBus
                                    ? LinearGradient(
                                        colors: [
                                          Colors.pink.shade50,
                                          Colors.pink.shade100,
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          AppTheme.primaryBlue.withOpacity(0.1),
                                          AppTheme.primaryBlue.withOpacity(0.15),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isWomenBus
                                      ? Colors.pink.shade300
                                      : AppTheme.primaryBlue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isWomenBus ? Icons.woman : Icons.people_alt_rounded,
                                    size: 14,
                                    color: isWomenBus
                                        ? Colors.pink.shade700
                                        : AppTheme.primaryBlue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isWomenBus ? 'WOMEN' : 'REGULAR',
                                    style: AppTheme.labelSmall.copyWith(
                                      color: isWomenBus
                                          ? Colors.pink.shade700
                                          : AppTheme.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.bus.routeNumber != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Route ${widget.bus.routeNumber}',
                                style: AppTheme.bodySmallDark(context),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Rating on the right side
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue,
                          AppTheme.primaryBlueLight,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.rating > 0 
                              ? widget.rating.toStringAsFixed(1)
                              : '4.0',
                          style: AppTheme.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

