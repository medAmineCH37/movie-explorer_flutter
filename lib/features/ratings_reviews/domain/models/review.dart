/// A published review, as returned by the `get_reviews` database function.
class Review {
  const Review({
    required this.id,
    required this.movieId,
    required this.userId,
    required this.content,
    required this.spoiler,
    required this.score,
    required this.likeCount,
    required this.likedByMe,
    required this.edited,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isMine = false,
  });

  final int id;
  final int movieId;
  final String userId;
  final String content;
  final bool spoiler;

  /// The author's rating of the movie (1–5), or `null` if unrated.
  final int? score;
  final int likeCount;
  final bool likedByMe;
  final bool edited;
  final String authorName;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether the signed-in user wrote this review.
  final bool isMine;

  factory Review.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final userId = json['user_id'] as String;
    return Review(
      id: (json['id'] as num).toInt(),
      movieId: (json['tmdb_movie_id'] as num).toInt(),
      userId: userId,
      content: json['content'] as String? ?? '',
      spoiler: json['spoiler'] as bool? ?? false,
      score: (json['score'] as num?)?.toInt(),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      edited: json['edited'] as bool? ?? false,
      authorName: json['author_name'] as String? ?? 'Movie fan',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      isMine: currentUserId != null && currentUserId == userId,
    );
  }

  /// First letter of the author's name, used when there is no avatar.
  String get authorInitial {
    final runes = authorName.trim().runes;
    return runes.isEmpty ? '?' : String.fromCharCode(runes.first).toUpperCase();
  }

  bool get hasAvatar {
    final url = authorAvatarUrl;
    return url != null &&
        (url.startsWith('https://') || url.startsWith('http://'));
  }

  Review copyWith({
    String? content,
    bool? spoiler,
    int? likeCount,
    bool? likedByMe,
    bool? edited,
    int? Function()? score,
  }) {
    return Review(
      id: id,
      movieId: movieId,
      userId: userId,
      content: content ?? this.content,
      spoiler: spoiler ?? this.spoiler,
      score: score != null ? score() : this.score,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      edited: edited ?? this.edited,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isMine: isMine,
    );
  }
}
