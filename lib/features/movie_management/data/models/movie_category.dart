import 'package:flutter/material.dart';

/// TMDB movie lists exposed by the catalogue.
enum MovieCategory {
  popular('popular', 'Popular', Icons.local_fire_department_outlined),
  topRated('top_rated', 'Top rated', Icons.emoji_events_outlined),
  nowPlaying('now_playing', 'Now playing', Icons.theaters_outlined),
  upcoming('upcoming', 'Upcoming', Icons.event_outlined);

  const MovieCategory(this.slug, this.label, this.icon);

  /// TMDB path segment (`/movie/<slug>`), also used in app URLs.
  final String slug;
  final String label;
  final IconData icon;

  static MovieCategory fromSlug(String? slug) => MovieCategory.values
      .firstWhere((c) => c.slug == slug, orElse: () => MovieCategory.popular);
}
