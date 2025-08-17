import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/rideshare_service.dart';
import '../services/riderequest_service.dart';
import '../services/friends_service.dart';

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
      final response = await RideRequestService.getUserRequests(currentUser!.id);
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

  void _applySearch() {
    print('Applying search. Source: "${searchSourceController.text}", Destination: "${searchDestinationController.text}"');
    print('Total ride posts: ${ridePosts.length}');
    
    if (searchSourceController.text.isEmpty && searchDestinationController.text.isEmpty) {
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
          final destination = post['destination']?.toString().toLowerCase() ?? '';
          final searchSource = searchSourceController.text.toLowerCase();
          final searchDestination = searchDestinationController.text.toLowerCase();

          bool matchesSource = searchSource.isEmpty || source.contains(searchSource);
          bool matchesDestination = searchDestination.isEmpty || destination.contains(searchDestination);

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
        
        print('Loaded ${ridePosts.length} ride posts, filtered to ${filteredRidePosts.length}');
        print('Current user ID: ${currentUser?.id}');
        for (final post in ridePosts.take(3)) {
          print('Post: ${post['_id']}, userId: ${post['userId']}, source: ${post['source']}, destination: ${post['destination']}');
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
            content: Text(response['message'] ?? 'Failed to accept ride request'),
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
            content: Text(response['message'] ?? 'Failed to reject ride request'),
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
    
    print('Building request button for post: $postId, status: $requestStatus, currentUser: ${currentUser?.id}');
    
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

  Widget _buildRideRequestsSection(Map<String, dynamic> post) {
    final requests = rideRequests[post['_id']] ?? [];
    final pendingRequests = requests.where((req) => req['status'] == 'pending').toList();
    
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
          ...pendingRequests.map((request) => Container(
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
                      onPressed: () => _acceptRideRequest(request['_id'], post['_id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      onPressed: () => _rejectRideRequest(request['_id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          )).toList(),
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
                          if (isOwnPost) _buildRideRequestsSection(post),
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
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.yellow[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Info',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.yellow[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Total ride posts: ${ridePosts.length}'),
                  Text('Filtered ride posts: ${filteredRidePosts.length}'),
                  Text('Current user: ${currentUser?.id ?? 'null'}'),
                  Text('Is searching: $isSearching'),
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
                  
                  print('Building ride post item $index: ${post['_id']}, source: ${post['source']}, destination: ${post['destination']}');

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
