import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/rideshare_service.dart';
import '../services/riderequest_service.dart';

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
  bool isFindRideExpanded = false;
  Map<String, List<Map<String, dynamic>>> rideRequests = {};
  Map<String, List<Map<String, dynamic>>> rideParticipants = {};
  List<Map<String, dynamic>> userRides = [];
  bool isYourRideExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadRidePosts();
    _loadUserRides();

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

      // Load user rides after user is loaded
      if (user != null) {
        await _loadUserRides();
      }
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
          // Filter out current user's posts and rides where user is participant from the search results
          filteredRidePosts = ridePosts.where((post) {
            // Exclude current user's own posts
            if (currentUser != null && post['userId'] == currentUser!.id) {
              return false;
            }

            // Exclude rides where current user is already a participant
            if (currentUser != null && post['participants'] != null) {
              final isParticipant = post['participants'].any(
                  (participant) => participant['userId'] == currentUser!.id);
              if (isParticipant) {
                return false;
              }
            }

            return true;
          }).toList();
          isLoading = false;
        });

        await _loadRideRequests();
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
        // Exclude current user's own posts from search results
        if (currentUser != null && post['userId'] == currentUser!.id) {
          return false;
        }

        // Exclude rides where current user is already a participant
        if (currentUser != null && post['participants'] != null) {
          final isParticipant = post['participants']
              .any((participant) => participant['userId'] == currentUser!.id);
          if (isParticipant) {
            return false;
          }
        }

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

  Future<void> _loadRideRequests() async {
    // Load requests for all ride posts (including user's own posts)
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

  Future<void> _loadUserRides() async {
    if (currentUser == null) return;

    try {
      final response = await RideshareService.getUserRides(currentUser!.id);
      if (response['success']) {
        setState(() {
          userRides = List<Map<String, dynamic>>.from(response['data']);
        });

        // Load ride requests for user's own posts
        await _loadRideRequests();
      }
    } catch (e) {
      print('Error loading user rides: $e');
    }
  }

  Future<void> _sendRideRequest(Map<String, dynamic> post) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please login to send ride request')),
      );
      return;
    }

    try {
      final response = await RideRequestService.sendRideRequest(
        ridePostId: post['_id'],
        requesterId: currentUser!.id,
        requesterName: currentUser!.name,
        requesterGender: currentUser!.gender ?? 'Not specified',
      );

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride request sent successfully!')),
        );
        await _loadRideRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(response['message'] ?? 'Failed to send ride request')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending ride request')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride request accepted successfully!')),
        );

        // Refresh both ride posts and requests to get updated data
        // Force refresh of ride posts to get updated participant data
        await _loadRidePosts();
        await _loadRideRequests();
        await _loadUserRides();

        // Refresh filtered results to ensure they're up to date
        _applySearchAndFilter();

        // Force UI update
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(response['message'] ?? 'Failed to accept ride request')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting ride request')),
      );
    }
  }

  Future<void> _rejectRideRequest(String requestId) async {
    try {
      final response = await RideRequestService.rejectRideRequest(requestId);

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ride request rejected successfully!')),
        );
        await _loadRideRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(response['message'] ?? 'Failed to reject ride request')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting ride request')),
      );
    }
  }

  bool _canSendRequest(Map<String, dynamic> post) {
    if (currentUser == null) return false;
    if (post['userId'] == currentUser!.id) return false;

    // Check if user is already a participant
    if (post['participants'] != null) {
      final isAlreadyParticipant = post['participants']
          .any((participant) => participant['userId'] == currentUser!.id);
      if (isAlreadyParticipant) return false;
    }

    final currentParticipants = post['participants']?.length ?? 0;
    if (currentParticipants >= (post['maxParticipants'] ?? 3)) return false;

    final requests = rideRequests[post['_id']] ?? [];
    final hasExistingRequest = requests.any((req) =>
        req['requesterId'] == currentUser!.id && req['status'] == 'pending');

    return !hasExistingRequest;
  }

  int _getCurrentParticipantCount(Map<String, dynamic> post) {
    final participants = post['participants'] ?? [];
    return participants
        .length; // Creator is already in participants, so this shows total count
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
        ],
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      searchSourceController.clear();
      searchDestinationController.clear();
      selectedGender = null;
      isSearching = false;
      // Filter out current user's posts and rides where user is participant even when search is cleared
      filteredRidePosts = ridePosts.where((post) {
        // Exclude current user's own posts
        if (currentUser != null && post['userId'] == currentUser!.id) {
          return false;
        }

        // Exclude rides where current user is already a participant
        if (currentUser != null && post['participants'] != null) {
          final isParticipant = post['participants']
              .any((participant) => participant['userId'] == currentUser!.id);
          if (isParticipant) {
            return false;
          }
        }

        return true;
      }).toList();
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
        await _loadUserRides();
        await _loadRideRequests();
        // Refresh filtered results (this will automatically exclude the new post from search results)
        _applySearchAndFilter();
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
        // Refresh filtered results (this will automatically update the search results)
        _applySearchAndFilter();
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

                  // Show existing post if user has one
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
                    // Show post form only if user doesn't have an existing post
                    TextField(
                      controller: sourceController,
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

            // Your Ride Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Collapsible Your Ride Button
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

                  // Collapsible Your Ride Content
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
                                        isOwnPost
                                            ? Icons.star
                                            : Icons.person_add,
                                        color: isOwnPost
                                            ? Colors.orange
                                            : Colors.blue,
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
                                          icon: Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _deleteRidePost(post['_id']),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
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
                                                    color: Colors.red,
                                                    size: 16),
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

                                  // Participant count and status
                                  Row(
                                    children: [
                                      Icon(Icons.people,
                                          color: Colors.blue, size: 16),
                                      SizedBox(width: 8),
                                      Text(
                                        '${_getCurrentParticipantCount(post)}/3 participants (including creator)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                      Spacer(),
                                      if (_getCurrentParticipantCount(post) >=
                                          3)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red[100],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Full',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  // Small note about participant counting
                                  Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Note: Creator is counted as 1st participant',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),

                                  // Show participants if any
                                  if (post['participants'] != null &&
                                      post['participants'].isNotEmpty) ...[
                                    SizedBox(height: 12),
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.green[200]!),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Participants:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          ...post['participants']
                                              .map<Widget>((participant) =>
                                                  Padding(
                                                    padding: EdgeInsets.only(
                                                        bottom: 4),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                            participant['userId'] ==
                                                                    post[
                                                                        'userId']
                                                                ? Icons.star
                                                                : Icons.person,
                                                            color: participant[
                                                                        'userId'] ==
                                                                    post[
                                                                        'userId']
                                                                ? Colors
                                                                    .orange[600]
                                                                : Colors
                                                                    .green[600],
                                                            size: 16),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          '${participant['userName']} (${participant['gender']})',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: Colors
                                                                .green[700],
                                                            fontWeight: participant[
                                                                        'userId'] ==
                                                                    post[
                                                                        'userId']
                                                                ? FontWeight
                                                                    .w600
                                                                : FontWeight
                                                                    .normal,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ))
                                              .toList(),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Show pending requests for user's own posts in Your Ride section
                                  if (isOwnPost &&
                                      rideRequests[post['_id']] != null &&
                                      rideRequests[post['_id']]!.any((req) =>
                                          req['status'] == 'pending')) ...[
                                    SizedBox(height: 12),
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.orange[200]!),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Pending Requests:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          ...rideRequests[post['_id']]!
                                              .where((req) =>
                                                  req['status'] == 'pending')
                                              .map<Widget>((request) => Padding(
                                                    padding: EdgeInsets.only(
                                                        bottom: 8),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                '${request['requesterName']} (${request['requesterGender']})',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                          .orange[
                                                                      700],
                                                                ),
                                                              ),
                                                              Text(
                                                                'Requested ${_formatDate(DateTime.parse(request['createdAt']))}',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 11,
                                                                  color: Colors
                                                                          .orange[
                                                                      600],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Row(
                                                          children: [
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  _acceptRideRequest(
                                                                      request[
                                                                          '_id'],
                                                                      post[
                                                                          '_id']),
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    Colors
                                                                        .green,
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            4),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                ),
                                                              ),
                                                              child: Text(
                                                                'Accept',
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(width: 8),
                                                            ElevatedButton(
                                                              onPressed: () =>
                                                                  _rejectRideRequest(
                                                                      request[
                                                                          '_id']),
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    Colors.red,
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            4),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                ),
                                                              ),
                                                              child: Text(
                                                                'Reject',
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ))
                                              ,
                                        ],
                                      ),
                                    ),
                                  ],

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
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Collapsible Find a Ride Button
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

                  // Collapsible Search and Filter Section
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
                  ],

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
                                    if (!isOwnPost && _canSendRequest(post))
                                      ElevatedButton(
                                        onPressed: () => _sendRideRequest(post),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                        child: Text(
                                          'Request',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
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

                                // Participant count and status
                                Row(
                                  children: [
                                    Icon(Icons.people,
                                        color: Colors.blue, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      '${_getCurrentParticipantCount(post)}/3 participants (including creator)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                    Spacer(),
                                    if (_getCurrentParticipantCount(post) >= 3)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Full',
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                // Small note about participant counting
                                Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Note: Creator is counted as 1st participant',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),

                                // Show participants if any
                                if (post['participants'] != null &&
                                    post['participants'].isNotEmpty) ...[
                                  SizedBox(height: 12),
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          Border.all(color: Colors.green[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Participants:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        ...post['participants']
                                            .map<Widget>((participant) =>
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                      bottom: 4),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.person,
                                                          color:
                                                              Colors.green[600],
                                                          size: 16),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        '${participant['userName']} (${participant['gender']})',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              Colors.green[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ))
                                            .toList(),
                                      ],
                                    ),
                                  ),
                                ],

                                // Show pending requests for post owner
                                if (isOwnPost &&
                                    rideRequests[post['_id']] != null) ...[
                                  SizedBox(height: 12),
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.orange[200]!),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pending Requests:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange[700],
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        ...rideRequests[post['_id']]!
                                            .where((req) =>
                                                req['status'] == 'pending')
                                            .map<Widget>((request) => Padding(
                                                  padding: EdgeInsets.only(
                                                      bottom: 8),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              '${request['requesterName']} (${request['requesterGender']})',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                        .orange[
                                                                    700],
                                                              ),
                                                            ),
                                                            Text(
                                                              'Requested ${_formatDate(DateTime.parse(request['createdAt']))}',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                        .orange[
                                                                    600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Row(
                                                        children: [
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                _acceptRideRequest(
                                                                    request[
                                                                        '_id'],
                                                                    post[
                                                                        '_id']),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  Colors.green,
                                                              padding: EdgeInsets
                                                                  .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            4),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Accept',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(width: 8),
                                                          ElevatedButton(
                                                            onPressed: () =>
                                                                _rejectRideRequest(
                                                                    request[
                                                                        '_id']),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                              padding: EdgeInsets
                                                                  .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4),
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            4),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Reject',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ))
                                            ,
                                      ],
                                    ),
                                  ),
                                ],

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
