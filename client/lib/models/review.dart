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
  final bool isEditing;

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
    this.isEditing = false,
  });

  Review copyWith({
    String? id,
    String? busId,
    String? userId,
    String? userName,
    String? comment,
    DateTime? createdAt,
    int? likes,
    int? dislikes,
    int? replies,
    List<ReviewReply>? repliesList,
    bool? isEditing,
  }) {
    return Review(
      id: id ?? this.id,
      busId: busId ?? this.busId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      replies: replies ?? this.replies,
      repliesList: repliesList ?? this.repliesList,
      isEditing: isEditing ?? this.isEditing,
    );
  }

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
      isEditing: false,
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
