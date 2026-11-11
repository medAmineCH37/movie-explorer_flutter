import 'package:flutter/material.dart';

import '../../../movie_management/data/models/genre.dart';
import '../../../movie_management/data/models/languages.dart';
import '../../../movie_management/data/models/movie_search_query.dart';

/// Bottom sheet editing genres, release years, minimum rating and
/// language. Returns the new query, or `null` when dismissed.
Future<MovieSearchQuery?> showDiscoveryFilters(
  BuildContext context, {
  required MovieSearchQuery query,
  required List<Genre> genres,
  required List<String> languages,
}) {
  return showModalBottomSheet<MovieSearchQuery>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DiscoveryFiltersSheet(
      query: query,
      genres: genres,
      languages: languages,
    ),
  );
}

class DiscoveryFiltersSheet extends StatefulWidget {
  const DiscoveryFiltersSheet({
    super.key,
    required this.query,
    required this.genres,
    required this.languages,
  });

  final MovieSearchQuery query;
  final List<Genre> genres;
  final List<String> languages;

  static const int minYear = 1920;
  static int get maxYear => DateTime.now().year + 3;

  @override
  State<DiscoveryFiltersSheet> createState() => _DiscoveryFiltersSheetState();
}

class _DiscoveryFiltersSheetState extends State<DiscoveryFiltersSheet> {
  late Set<int> _genreIds;
  late RangeValues _years;
  late double _minRating;
  String? _language;

  int get _minYear => DiscoveryFiltersSheet.minYear;
  int get _maxYear => DiscoveryFiltersSheet.maxYear;

  @override
  void initState() {
    super.initState();
    final q = widget.query;
    _genreIds = {...q.genreIds};
    _years = RangeValues(
      (q.yearFrom ?? _minYear).clamp(_minYear, _maxYear).toDouble(),
      (q.yearTo ?? _maxYear).clamp(_minYear, _maxYear).toDouble(),
    );
    _minRating = q.minRating ?? 0;
    _language = q.language;
  }

  MovieSearchQuery _result() {
    final from = _years.start.round();
    final to = _years.end.round();
    return widget.query.copyWith(
      genreIds: _genreIds,
      yearFrom: () => from <= _minYear ? null : from,
      yearTo: () => to >= _maxYear ? null : to,
      minRating: () => _minRating <= 0 ? null : _minRating,
      language: () => _language,
    );
  }

  void _reset() => setState(() {
    _genreIds = {};
    _years = RangeValues(_minYear.toDouble(), _maxYear.toDouble());
    _minRating = 0;
    _language = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final yearsLabel =
        _years.start.round() <= _minYear && _years.end.round() >= _maxYear
        ? 'Any year'
        : '${_years.start.round()} – ${_years.end.round()}';
    final languages = {...widget.languages, ?_language}.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            children: [
              Text('Filters', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Genres', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (widget.genres.isEmpty)
                const Text('Genres could not be loaded.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final genre in widget.genres)
                      FilterChip(
                        label: Text(genre.name),
                        selected: _genreIds.contains(genre.id),
                        onSelected: (selected) => setState(() {
                          selected
                              ? _genreIds.add(genre.id)
                              : _genreIds.remove(genre.id);
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                'Movies with any of the selected genres are shown.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Release year',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(yearsLabel),
                ],
              ),
              RangeSlider(
                values: _years,
                min: _minYear.toDouble(),
                max: _maxYear.toDouble(),
                divisions: _maxYear - _minYear,
                labels: RangeLabels(
                  '${_years.start.round()}',
                  '${_years.end.round()}',
                ),
                onChanged: (v) => setState(() => _years = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Minimum rating',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    _minRating <= 0
                        ? 'Any'
                        : '${_minRating.toStringAsFixed(1)} / 10',
                  ),
                ],
              ),
              Slider(
                value: _minRating,
                max: 9,
                divisions: 18,
                label: _minRating.toStringAsFixed(1),
                onChanged: (v) => setState(() => _minRating = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _language,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Language'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Any language'),
                  ),
                  for (final code in languages)
                    DropdownMenuItem(
                      value: code,
                      child: Text(Languages.nameOf(code)),
                    ),
                ],
                onChanged: (v) => setState(() => _language = v),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_result()),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Show movies'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
