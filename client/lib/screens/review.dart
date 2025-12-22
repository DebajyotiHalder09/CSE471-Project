import 'package:flutter/material.dart';
import '../models/bus.dart';
import '../models/review.dart';
import '../models/user.dart';
import '../services/review_service.dart';
import '../services/auth_service.dart';
import '../services/rating_service.dart';
import '../utils/app_theme.dart';
import '../utils/error_widgets.dart';
import '../utils/loading_widgets.dart';

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
  final TextEditingController editController = TextEditingController();
  String? replyingToReviewId;
  String? editingReviewId;
  int selectedRating = 0; // 0 means no rating selected, 1-5 for stars
  double? busAverageRating;
  int busTotalRatings = 0;
  bool isSubmittingRating = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadReviews();
    _loadBusRating();
  }

  @override
  void dispose() {
    commentController.dispose();
    replyController.dispose();
    editController.dispose();
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

  Future<void> _loadBusRating() async {
    try {
      final response = await RatingService.getBusRating(widget.bus.id);
      if (response['success'] && response['data'] != null) {
        setState(() {
          busAverageRating = (response['data']['averageRating'] as num?)?.toDouble();
          busTotalRatings = response['data']['totalRatings'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading bus rating: $e');
    }
  }

  Future<void> _submitRating(int rating) async {
    if (currentUser == null || isSubmittingRating) return;

    setState(() {
      isSubmittingRating = true;
    });

    try {
      final response = await RatingService.submitRating(
        busId: widget.bus.id,
        userId: currentUser!.id,
        rating: rating.toDouble(),
      );

      if (response['success']) {
        // Reload the bus rating to get updated average
        await _loadBusRating();
        SuccessSnackbar.show(context, 'Rating submitted successfully!');
      } else {
        ErrorSnackbar.show(context, response['message'] ?? 'Failed to submit rating');
      }
    } catch (e) {
      ErrorSnackbar.show(context, 'Error submitting rating: $e');
    } finally {
      setState(() {
        isSubmittingRating = false;
      });
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
      ErrorSnackbar.show(context, 'Please enter a comment');
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
        final newReview = Review.fromJson(response['data']);
        setState(() {
          reviews.insert(0, newReview);
          isLoading = false;
        });
        commentController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review added successfully!'),
            backgroundColor: AppTheme.accentGreen,
          ),
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
        final newReply = ReviewReply.fromJson(response['data']);
        setState(() {
          final reviewIndex = reviews.indexWhere((r) => r.id == reviewId);
          if (reviewIndex != -1) {
            final review = reviews[reviewIndex];
            final updatedReplies = List<ReviewReply>.from(review.repliesList)
              ..add(newReply);
            final updatedReview = review.copyWith(
              replies: updatedReplies.length,
              repliesList: updatedReplies,
            );
            reviews[reviewIndex] = updatedReview;
          }
          replyingToReviewId = null;
          isLoading = false;
        });
        replyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reply added successfully!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _likeReview(String reviewId) async {
    if (currentUser == null) {
      ErrorSnackbar.show(context, 'Please login to like reviews');
      return;
    }

    try {
      final response = await ReviewService.likeReview(
        reviewId: reviewId,
        userId: currentUser!.id,
      );

      if (response['success']) {
        setState(() {
          final reviewIndex = reviews.indexWhere((r) => r.id == reviewId);
          if (reviewIndex != -1) {
            final review = reviews[reviewIndex];
            final updatedReview = review.copyWith(
              likes: response['likes'] ?? review.likes,
              dislikes: response['dislikes'] ?? review.dislikes,
            );
            reviews[reviewIndex] = updatedReview;
          }
        });
      } else {
        ErrorSnackbar.show(context, response['message'] ?? 'Failed to like review');
      }
    } catch (e) {
      ErrorSnackbar.show(context, e.toString());
    }
  }

  Future<void> _dislikeReview(String reviewId) async {
    if (currentUser == null) {
      ErrorSnackbar.show(context, 'Please login to dislike reviews');
      return;
    }

    try {
      final response = await ReviewService.dislikeReview(
        reviewId: reviewId,
        userId: currentUser!.id,
      );

      if (response['success']) {
        setState(() {
          final reviewIndex = reviews.indexWhere((r) => r.id == reviewId);
          if (reviewIndex != -1) {
            final review = reviews[reviewIndex];
            final updatedReview = review.copyWith(
              likes: response['likes'] ?? review.likes,
              dislikes: response['dislikes'] ?? review.dislikes,
            );
            reviews[reviewIndex] = updatedReview;
          }
        });
      } else {
        ErrorSnackbar.show(context, response['message'] ?? 'Failed to dislike review');
      }
    } catch (e) {
      ErrorSnackbar.show(context, e.toString());
    }
  }

  Future<void> _editReview(String reviewId, String newComment) async {
    if (newComment.trim().isEmpty) {
      ErrorSnackbar.show(context, 'Please enter a comment');
      return;
    }

    final originalComment = editController.text.trim();

    setState(() {
      editingReviewId = null;
      final reviewIndex = reviews.indexWhere((r) => r.id == reviewId);
      if (reviewIndex != -1) {
        final review = reviews[reviewIndex];
        final updatedReview = review.copyWith(
          comment: newComment.trim(),
        );
        reviews[reviewIndex] = updatedReview;
      }
    });
    editController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Review updated successfully!'),
        backgroundColor: AppTheme.accentGreen,
      ),
    );

    try {
      final response = await ReviewService.updateReview(
        reviewId: reviewId,
        comment: newComment.trim(),
      );

      if (!response['success']) {
        setState(() {
          final reviewIndex = reviews.indexWhere((r) => r.id == reviewId);
          if (reviewIndex != -1) {
            final review = reviews[reviewIndex];
            final originalReview = review.copyWith(
              comment: originalComment,
            );
            reviews[reviewIndex] = originalReview;
          }
        });

        ErrorSnackbar.show(context, response['message'] ?? 'Failed to update review');
      }
    } catch (e) {
      setState(() {
        final reviewIndex = reviews.indexWhere((r) => r.id == reviewId);
        if (reviewIndex != -1) {
          final review = reviews[reviewIndex];
          final originalReview = review.copyWith(
            comment: originalComment,
          );
          reviews[reviewIndex] = originalReview;
        }
      });

      ErrorSnackbar.show(context, 'Failed to update review: ${e.toString()}');
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await ReviewService.deleteReview(
        reviewId: reviewId,
      );

      if (response['success']) {
        setState(() {
          reviews.removeWhere((r) => r.id == reviewId);
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review deleted successfully!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to delete review';
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

  void _startEditing(String reviewId, String currentComment) {
    setState(() {
      editingReviewId = reviewId;
      editController.text = currentComment;
    });
  }

  void _cancelEditing() {
    setState(() {
      editingReviewId = null;
      editController.clear();
    });
  }

  Future<void> _showDeleteConfirmation(String reviewId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Delete Review',
            style: AppTheme.heading4Dark(context).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this review? This action cannot be undone.',
            style: AppTheme.bodyMediumDark(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppTheme.labelMedium.copyWith(
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentRed,
                    AppTheme.accentRed.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _deleteReview(reviewId);
                },
                child: Text(
                  'Delete',
                  style: AppTheme.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.reviews_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.bus.busName,
                style: AppTheme.heading3Dark(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.modernCardDecorationDark(
              context,
              color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Add a Review',
                      style: AppTheme.heading4Dark(context).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Display current bus rating
                    if (busAverageRating != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: AppTheme.accentOrange,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            busAverageRating!.toStringAsFixed(1),
                            style: AppTheme.heading4Dark(context).copyWith(
                              color: AppTheme.accentOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (busTotalRatings > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '($busTotalRatings)',
                              style: AppTheme.bodySmallDark(context).copyWith(
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // Star Rating Widget
                if (currentUser != null) ...[
                  Text(
                    'Rate this bus:',
                    style: AppTheme.bodyMediumDark(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      final starNumber = index + 1;
                      final isSelected = selectedRating >= starNumber;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedRating = starNumber;
                          });
                          _submitRating(starNumber);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                            color: isSelected ? AppTheme.accentOrange : AppTheme.textTertiary,
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 16),
                if (currentUser == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.accentOrange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppTheme.accentOrange,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Please login to post a review',
                            style: AppTheme.bodyMediumDark(context).copyWith(
                              color: AppTheme.accentOrange,
                              fontWeight: FontWeight.w600,
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
                    style: AppTheme.bodyLargeDark(context),
                    decoration: InputDecoration(
                      hintText: 'Share your experience with this bus...',
                      hintStyle: AppTheme.bodyMediumDark(context).copyWith(
                        color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                      ),
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
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: (isLoading || currentUser == null)
                              ? LinearGradient(
                                  colors: [
                                    Colors.grey[400]!,
                                    Colors.grey[500]!,
                                  ],
                                )
                              : AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: (isLoading || currentUser == null)
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (isLoading || currentUser == null) ? null : _addReview,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              alignment: Alignment.center,
                              child: Text(
                                currentUser == null ? 'Login Required' : 'Post Review',
                                style: AppTheme.labelLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: (isLoading || currentUser == null)
                            ? LinearGradient(
                                colors: [
                                  Colors.grey[400]!,
                                  Colors.grey[500]!,
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  AppTheme.accentOrange,
                                  AppTheme.accentOrange.withOpacity(0.8),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: (isLoading || currentUser == null)
                            ? null
                            : [
                                BoxShadow(
                                  color: AppTheme.accentOrange.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: null, // Dummy button - non-functional
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.accentRed.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.accentRed,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: AppTheme.bodyMediumDark(context).copyWith(
                        color: AppTheme.accentRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isLoading
                ? Center(
                    child: LoadingWidget(
                      message: 'Loading reviews...',
                    ),
                  )
                : reviews.isEmpty
                    ? EmptyStateWidget(
                        title: 'No reviews yet',
                        message: 'Be the first to share your experience!',
                        icon: Icons.reviews_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReviews,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
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
                              onEdit: () =>
                                  _startEditing(review.id, review.comment),
                              onDelete: () => _showDeleteConfirmation(review.id),
                              canEdit: currentUser?.id == review.userId,
                              isEditing: editingReviewId == review.id,
                              editController: editController,
                              onSaveEdit: () => _editReview(
                                  editingReviewId!, editController.text.trim()),
                              onCancelEdit: _cancelEditing,
                            );
                          },
                        ),
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
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool canEdit;
  final bool isEditing;
  final TextEditingController? editController;
  final VoidCallback? onSaveEdit;
  final VoidCallback? onCancelEdit;

  const ReviewCard({
    super.key,
    required this.review,
    required this.onLike,
    required this.onDislike,
    required this.onReply,
    required this.isReplying,
    required this.replyController,
    required this.onAddReply,
    this.onEdit,
    this.onDelete,
    this.canEdit = false,
    this.isEditing = false,
    this.editController,
    this.onSaveEdit,
    this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.modernCardDecorationDark(
        context,
        color: isDark ? AppTheme.darkSurface : AppTheme.backgroundWhite,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      review.userName.isNotEmpty
                          ? review.userName[0].toUpperCase()
                          : 'U',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
                        style: AppTheme.bodyMediumDark(context).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(review.createdAt),
                        style: AppTheme.bodySmallDark(context).copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canEdit)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit?.call();
                      } else if (value == 'delete') {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 20, color: AppTheme.primaryBlue),
                            const SizedBox(width: 12),
                            Text(
                              'Edit',
                              style: AppTheme.bodyMediumDark(context),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 20, color: AppTheme.accentRed),
                            const SizedBox(width: 12),
                            Text(
                              'Delete',
                              style: AppTheme.bodyMediumDark(context).copyWith(
                                color: AppTheme.accentRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (isEditing && editController != null) ...[
              TextField(
                controller: editController!,
                maxLines: 3,
                style: AppTheme.bodyLargeDark(context),
                decoration: InputDecoration(
                  hintText: 'Edit your review...',
                  hintStyle: AppTheme.bodyMediumDark(context).copyWith(
                    color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                  ),
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
                  fillColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onCancelEdit,
                    child: Text(
                      'Cancel',
                      style: AppTheme.labelMedium.copyWith(
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onSaveEdit,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Text(
                            'Save',
                            style: AppTheme.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                review.comment,
                style: AppTheme.heading4Dark(context).copyWith(
                  fontSize: 18,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                _ActionButton(
                  icon: Icons.thumb_up_rounded,
                  label: '${review.likes}',
                  onPressed: onLike,
                  color: AppTheme.accentGreen,
                ),
                const SizedBox(width: 12),
                _ActionButton(
                  icon: Icons.thumb_down_rounded,
                  label: '${review.dislikes}',
                  onPressed: onDislike,
                  color: AppTheme.accentRed,
                ),
                const SizedBox(width: 12),
                _ActionButton(
                  icon: Icons.reply_rounded,
                  label: '${review.replies}',
                  onPressed: onReply,
                  color: AppTheme.primaryBlue,
                ),
              ],
            ),
            if (isReplying) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: replyController,
                      maxLines: 2,
                      style: AppTheme.bodyLargeDark(context),
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        hintStyle: AppTheme.bodyMediumDark(context).copyWith(
                          color: isDark ? AppTheme.darkTextTertiary : AppTheme.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: onReply,
                          child: Text(
                            'Cancel',
                            style: AppTheme.labelMedium.copyWith(
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onAddReply,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Text(
                                  'Reply',
                                  style: AppTheme.labelLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
            if (review.repliesList.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Replies',
                style: AppTheme.heading4Dark(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...review.repliesList.map((reply) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.accentOrange,
                                    AppTheme.accentOrange.withOpacity(0.8),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  reply.userName.isNotEmpty
                                      ? reply.userName[0].toUpperCase()
                                      : 'U',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reply.userName,
                                    style: AppTheme.bodySmallDark(context).copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(reply.createdAt),
                                    style: AppTheme.bodySmallDark(context).copyWith(
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          reply.comment,
                          style: AppTheme.bodyLargeDark(context).copyWith(
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _ActionButton(
                              icon: Icons.thumb_up_rounded,
                              label: '${reply.likes}',
                              onPressed: () {},
                              color: AppTheme.accentGreen,
                              isSmall: true,
                            ),
                            const SizedBox(width: 12),
                            _ActionButton(
                              icon: Icons.thumb_down_rounded,
                              label: '${reply.dislikes}',
                              onPressed: () {},
                              color: AppTheme.accentRed,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: isSmall ? 8 : 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isSmall ? 18 : 20,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTheme.bodyMediumDark(context).copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmall ? 14 : 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
