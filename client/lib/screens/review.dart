import 'package:flutter/material.dart';
import '../models/bus.dart';
import '../models/review.dart';
import '../models/user.dart';
import '../services/review_service.dart';
import '../services/auth_service.dart';

class ReviewScreen extends StatefulWidget {
  final Bus bus;

  const ReviewScreen({super.key, required this.bus});

  @override
  _ReviewScreenState createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<Review> reviews = [];
  bool isLoading = false;
  String? errorMessage;
  User? currentUser;
  final TextEditingController commentController = TextEditingController();
  final TextEditingController replyController = TextEditingController();
  String? replyingToReviewId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadReviews();
  }

  @override
  void dispose() {
    commentController.dispose();
    replyController.dispose();
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

  Future<void> _loadReviews() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      print('Loading reviews for bus: ${widget.bus.busName}');
      print('Bus ID: ${widget.bus.id}');
      final response = await ReviewService.getReviewsByBusId(widget.bus.id);

      if (response['success']) {
        setState(() {
          reviews = (response['data'] as List)
              .map((json) => Review.fromJson(json))
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load reviews';
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

  Future<void> _addReview() async {
    if (commentController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter a comment';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      print('Creating review for bus: ${widget.bus.busName}');
      print('Bus ID: ${widget.bus.id}');
      if (currentUser == null) {
        setState(() {
          errorMessage = 'Please login to post a review';
          isLoading = false;
        });
        return;
      }

      final response = await ReviewService.createReview(
        busId: widget.bus.id,
        userId: currentUser!.id,
        userName: currentUser!.name,
        comment: commentController.text.trim(),
      );

      if (response['success']) {
        commentController.clear();
        await _loadReviews();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review added successfully!')),
        );
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to add review';
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

  Future<void> _addReply(String reviewId) async {
    if (replyController.text.trim().isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      if (currentUser == null) {
        setState(() {
          errorMessage = 'Please login to post a reply';
          isLoading = false;
        });
        return;
      }

      final response = await ReviewService.addReply(
        reviewId: reviewId,
        userId: currentUser!.id,
        userName: currentUser!.name,
        comment: replyController.text.trim(),
      );

      if (response['success']) {
        replyController.clear();
        setState(() {
          replyingToReviewId = null;
        });
        await _loadReviews();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reply added successfully!')),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _likeReview(String reviewId) async {
    if (currentUser == null) {
      setState(() {
        errorMessage = 'Please login to like reviews';
      });
      return;
    }

    try {
      await ReviewService.likeReview(
        reviewId: reviewId,
        userId: currentUser!.id,
      );
      await _loadReviews();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _dislikeReview(String reviewId) async {
    if (currentUser == null) {
      setState(() {
        errorMessage = 'Please login to dislike reviews';
      });
      return;
    }

    try {
      await ReviewService.dislikeReview(
        reviewId: reviewId,
        userId: currentUser!.id,
      );
      await _loadReviews();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Reviews - ${widget.bus.busName}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
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
                Row(
                  children: [
                    Text(
                      'Add a Review',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (currentUser != null) ...[
                      Spacer(),
                      Text(
                        'as ${currentUser!.name}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 12),
                if (currentUser == null)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Please login to post a review',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your experience with this bus...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (isLoading || currentUser == null) ? null : _addReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          currentUser == null ? Colors.grey : Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      currentUser == null ? 'Login Required' : 'Post Review',
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
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : reviews.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.message_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No reviews yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Be the first to share your experience!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: reviews.length,
                        itemBuilder: (context, index) {
                          final review = reviews[index];
                          return ReviewCard(
                            review: review,
                            onLike: () => _likeReview(review.id),
                            onDislike: () => _dislikeReview(review.id),
                            onReply: () {
                              setState(() {
                                replyingToReviewId =
                                    replyingToReviewId == review.id
                                        ? null
                                        : review.id;
                              });
                            },
                            isReplying: replyingToReviewId == review.id,
                            replyController: replyController,
                            onAddReply: () => _addReply(review.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onReply;
  final bool isReplying;
  final TextEditingController replyController;
  final VoidCallback onAddReply;

  const ReviewCard({
    super.key,
    required this.review,
    required this.onLike,
    required this.onDislike,
    required this.onReply,
    required this.isReplying,
    required this.replyController,
    required this.onAddReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
                    review.userName.isNotEmpty
                        ? review.userName[0].toUpperCase()
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
                        review.userName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(review.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              review.comment,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                _ActionButton(
                  icon: Icons.thumb_up_outlined,
                  label: '${review.likes}',
                  onPressed: onLike,
                  color: Colors.green,
                ),
                SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.thumb_down_outlined,
                  label: '${review.dislikes}',
                  onPressed: onDislike,
                  color: Colors.red,
                ),
                SizedBox(width: 16),
                _ActionButton(
                  icon: Icons.reply,
                  label: '${review.replies}',
                  onPressed: onReply,
                  color: Colors.blue,
                ),
              ],
            ),
            if (isReplying) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: replyController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: onReply,
                          child: Text('Cancel'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: onAddReply,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: Text(
                            'Reply',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (review.repliesList.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Replies',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              ...review.repliesList.map((reply) => Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.orange[100],
                              child: Text(
                                reply.userName.isNotEmpty
                                    ? reply.userName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reply.userName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(reply.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          reply.comment,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            _ActionButton(
                              icon: Icons.thumb_up_outlined,
                              label: '${reply.likes}',
                              onPressed: () {},
                              color: Colors.green,
                              isSmall: true,
                            ),
                            SizedBox(width: 12),
                            _ActionButton(
                              icon: Icons.thumb_down_outlined,
                              label: '${reply.dislikes}',
                              onPressed: () {},
                              color: Colors.red,
                              isSmall: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
            ],
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final bool isSmall;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.color,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isSmall ? 16 : 18,
              color: color,
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: isSmall ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
