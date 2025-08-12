class Review {
  final String id;
  final String busId;
  final String userId;
  final String userName;
  final String comment;
  final DateTime createdAt;
  final int likes;
  final int dislikes;
  final int replies;
  final List<ReviewReply> repliesList;

  Review({
    required this.id,
    required this.busId,
    required this.userId,
    required this.userName,
    required this.comment,
    required this.createdAt,
    this.likes = 0,
    this.dislikes = 0,
    this.replies = 0,
    this.repliesList = const [],
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['_id'] ?? '',
      busId: json['busId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      comment: json['comment'] ?? '',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      likes: json['likes'] ?? 0,
      dislikes: json['dislikes'] ?? 0,
      replies: json['replies'] ?? 0,
      repliesList: (json['repliesList'] as List<dynamic>?)
              ?.map((reply) => ReviewReply.fromJson(reply))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'busId': busId,
      'userId': userId,
      'userName': userName,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
      'dislikes': dislikes,
      'replies': replies,
      'repliesList': repliesList.map((reply) => reply.toJson()).toList(),
    };
  }
}

class ReviewReply {
  final String id;
  final String userId;
  final String userName;
  final String comment;
  final DateTime createdAt;
  final int likes;
  final int dislikes;

  ReviewReply({
    required this.id,
    required this.userId,
    required this.userName,
    required this.comment,
    required this.createdAt,
    this.likes = 0,
    this.dislikes = 0,
  });

  factory ReviewReply.fromJson(Map<String, dynamic> json) {
    return ReviewReply(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      comment: json['comment'] ?? '',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      likes: json['likes'] ?? 0,
      dislikes: json['dislikes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'userName': userName,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
      'dislikes': dislikes,
    };
  }
}
