/// AI digest of a movie's reviews, produced by the `review-ai` function.
class AiReviewSummary {
  const AiReviewSummary({
    required this.summary,
    required this.strengths,
    required this.weaknesses,
    required this.reviewCount,
    required this.generatedAt,
    this.cached = false,
  });

  final String summary;
  final List<String> strengths;
  final List<String> weaknesses;

  /// Number of reviews the movie had when the summary was generated.
  final int reviewCount;
  final DateTime generatedAt;
  final bool cached;

  factory AiReviewSummary.fromJson(Map<String, dynamic> json) {
    List<String> list(Object? value) => (value as List<dynamic>? ?? const [])
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return AiReviewSummary(
      summary: (json['summary'] as String? ?? '').trim(),
      strengths: list(json['strengths']),
      weaknesses: list(json['weaknesses']),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      generatedAt:
          DateTime.tryParse(json['generated_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      cached: json['cached'] as bool? ?? false,
    );
  }
}
