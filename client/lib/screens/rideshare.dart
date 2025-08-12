import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/rideshare_service.dart';

class RideshareScreen extends StatefulWidget {
  final String? source;
  final String? destination;

  const RideshareScreen({super.key, this.source, this.destination});

  @override
  State<RideshareScreen> createState() => _RideshareScreenState();
}

class _RideshareScreenState extends State<RideshareScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadRidePosts();

    if (widget.source != null) {
      sourceController.text = widget.source!;
    }
    if (widget.destination != null) {
      destinationController.text = widget.destination!;
    }
  }

  @override
  void dispose() {
    sourceController.dispose();
    destinationController.dispose();
    searchSourceController.dispose();
    searchDestinationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthService.getUser();
      setState(() {
        currentUser = user;
      });
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  Future<void> _loadRidePosts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await RideshareService.getAllRidePosts();
      if (response['success']) {
        setState(() {
          ridePosts = List<Map<String, dynamic>>.from(response['data']);
          filteredRidePosts = List<Map<String, dynamic>>.from(response['data']);
          isLoading = false;
        });
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

  void _applySearchAndFilter() {
    setState(() {
      isSearching = searchSourceController.text.isNotEmpty ||
          searchDestinationController.text.isNotEmpty ||
          selectedGender != null;

      filteredRidePosts = ridePosts.where((post) {
        bool matchesSource = true;
        bool matchesDestination = true;
        bool matchesGender = true;

        // Source filter
        if (searchSourceController.text.isNotEmpty) {
          matchesSource = post['source']
                  ?.toLowerCase()
                  .contains(searchSourceController.text.toLowerCase()) ??
              false;
        }

        // Destination filter
        if (searchDestinationController.text.isNotEmpty) {
          matchesDestination = post['destination']
                  ?.toLowerCase()
                  .contains(searchDestinationController.text.toLowerCase()) ??
              false;
        }

        // Gender filter
        if (selectedGender != null && selectedGender != 'All') {
          matchesGender = post['gender'] == selectedGender;
        }

        return matchesSource && matchesDestination && matchesGender;
      }).toList();
    });
  }

  void _clearSearch() {
    setState(() {
      searchSourceController.clear();
      searchDestinationController.clear();
      selectedGender = null;
      isSearching = false;
      filteredRidePosts = ridePosts;
    });
  }

  Future<void> _postRide() async {
    if (sourceController.text.trim().isEmpty ||
        destinationController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter both source and destination';
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
        await _loadRidePosts();
        _applySearchAndFilter(); // Refresh filtered results
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
        _applySearchAndFilter(); // Refresh filtered results
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 245),
      body: SingleChildScrollView(
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
                  TextField(
                    controller: sourceController,
                    decoration: InputDecoration(
                      hintText: 'Enter source location',
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
                    controller: destinationController,
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
                      onPressed:
                          (isLoading || currentUser == null) ? null : _postRide,
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
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find a Ride',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12),

                  // Search and Filter Section
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

                        // Source Search
                        TextField(
                          controller: searchSourceController,
                          decoration: InputDecoration(
                            hintText: 'Search by source location',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon:
                                Icon(Icons.location_on, color: Colors.green),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.search),
                              onPressed: _applySearchAndFilter,
                            ),
                          ),
                          onSubmitted: (_) => _applySearchAndFilter(),
                        ),
                        SizedBox(height: 12),

                        // Destination Search
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
                            suffixIcon: IconButton(
                              icon: Icon(Icons.search),
                              onPressed: _applySearchAndFilter,
                            ),
                          ),
                          onSubmitted: (_) => _applySearchAndFilter(),
                        ),
                        SizedBox(height: 12),

                        // Gender Filter
                        Row(
                          children: [
                            Text(
                              'Preferred Gender: ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedGender,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                hint: Text('All'),
                                items: [
                                  DropdownMenuItem(
                                      value: null, child: Text('All')),
                                  DropdownMenuItem(
                                      value: 'Male', child: Text('Male')),
                                  DropdownMenuItem(
                                      value: 'Female', child: Text('Female')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedGender = value;
                                  });
                                  _applySearchAndFilter();
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // Search and Clear Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _applySearchAndFilter,
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
                                onPressed: _clearSearch,
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

                  // Results Section
                  if (isSearching)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue[700], size: 16),
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

                  SizedBox(height: 12),

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
                          if (isSearching) ...[
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _clearSearch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Clear Search',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                  color: Colors.purple,
                                                  size: 14),
                                              SizedBox(width: 4),
                                              Text(
                                                post['gender'] ??
                                                    'Not specified',
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
                                        icon: Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _deleteRidePost(post['_id']),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.location_on,
                                                  color: Colors.green,
                                                  size: 16),
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
                                            post['source'] ??
                                                'Unknown location',
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            post['destination'] ??
                                                'Unknown location',
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
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
}
