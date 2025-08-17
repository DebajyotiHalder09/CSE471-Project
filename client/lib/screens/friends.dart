import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class FriendsScreen extends StatefulWidget {
  static const routeName = '/friends';

  const FriendsScreen({super.key});

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  User? _searchedUser;
  bool _isSearching = false;
  bool _hasSearched = false;
  List<User> _friendsList = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoadingFriends = false;
  bool _isLoadingRequests = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriendsList();
    _loadPendingRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendsList() async {
    setState(() {
      _isLoadingFriends = true;
    });

    try {
      final friends = await AuthService.getFriendsList();
      setState(() {
        _friendsList = friends;
        _isLoadingFriends = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingFriends = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load friends: $e')),
      );
    }
  }

  Future<void> _loadPendingRequests() async {
    setState(() {
      _isLoadingRequests = true;
    });

    try {
      final requests = await AuthService.getPendingFriendRequests();
      setState(() {
        _pendingRequests = requests;
        _isLoadingRequests = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRequests = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load pending requests: $e')),
      );
    }
  }

  Future<void> _searchUserByFriendCode() async {
    final friendCode = _searchController.text.trim().toUpperCase();
    if (friendCode.isEmpty) {
      setState(() {
        _searchedUser = null;
        _hasSearched = false;
      });
      return;
    }

    if (friendCode.length != 5) {
      setState(() {
        _searchedUser = null;
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final user = await AuthService.searchUserByFriendCode(friendCode);
      setState(() {
        _searchedUser = user;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchedUser = null;
        _isSearching = false;
      });
    }
  }

  Future<void> _sendFriendRequest(String toUserId) async {
    try {
      await AuthService.sendFriendRequest(toUserId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent successfully!')),
      );
      _loadPendingRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send friend request: $e')),
      );
    }
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      await AuthService.acceptFriendRequest(requestId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request accepted!')),
      );
      _loadPendingRequests();
      _loadFriendsList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept friend request: $e')),
      );
    }
  }

  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      await AuthService.rejectFriendRequest(requestId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request rejected')),
      );
      _loadPendingRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject friend request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Friends'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Search'),
            Tab(text: 'Friends (${_friendsList.length})'),
            Tab(text: 'Requests (${_pendingRequests.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(),
          _buildFriendsTab(),
          _buildRequestsTab(),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Enter friend code',
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon:
                                    Icon(Icons.clear, color: Colors.grey[600]),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchedUser = null;
                                    _hasSearched = false;
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          setState(() {
                            _searchedUser = null;
                            _hasSearched = false;
                          });
                        }
                        if (value.length > 5) {
                          _searchController.text =
                              value.substring(0, 5).toUpperCase();
                          _searchController.selection =
                              TextSelection.collapsed(offset: 5);
                        }
                      },
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : _searchUserByFriendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: _isSearching
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('Search'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            if (_isSearching)
              Center(child: CircularProgressIndicator())
            else if (_hasSearched && _searchedUser == null)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text(
                      'No user found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No user found with the given friend code',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else if (_searchedUser != null)
              _buildUserCard(_searchedUser!),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: _isLoadingFriends
            ? Center(child: CircularProgressIndicator())
            : _friendsList.isEmpty
                ? Center(
                    child: Column(
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey[400]),
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
                          'Search for users and send friend requests to connect',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _friendsList.length,
                    itemBuilder: (context, index) {
                      return _buildFriendCard(_friendsList[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: _isLoadingRequests
            ? Center(child: CircularProgressIndicator())
            : _pendingRequests.isEmpty
                ? Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No pending requests',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'You have no pending friend requests',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _pendingRequests.length,
                    itemBuilder: (context, index) {
                      final request = _pendingRequests[index];
                      return _buildRequestCard(request);
                    },
                  ),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Container(
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
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.blue[100],
          child: Text(
            user.firstNameInitial,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
        ),
        title: Text(
          user.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              user.email,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.person_add,
            color: Colors.blue,
          ),
          onPressed: () {
            _sendFriendRequest(user.id);
          },
        ),
      ),
    );
  }

  Widget _buildFriendCard(User friend) {
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
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.green[100],
          child: Text(
            friend.firstNameInitial,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
        ),
        title: Text(
          friend.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          friend.email,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: Icon(
          Icons.check_circle,
          color: Colors.green,
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final fromUser = request['fromUserId'];
    final requestId = request['_id'];

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
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.orange[100],
          child: Text(
            fromUser['name']?.isNotEmpty == true
                ? fromUser['name'][0].toUpperCase()
                : 'U',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange[700],
            ),
          ),
        ),
        title: Text(
          fromUser['name'] ?? 'Unknown User',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          fromUser['email'] ?? '',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.check, color: Colors.green),
              onPressed: () => _acceptFriendRequest(requestId),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red),
              onPressed: () => _rejectFriendRequest(requestId),
            ),
          ],
        ),
      ),
    );
  }
}
