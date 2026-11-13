import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/genre.dart';
import '../../data/models/languages.dart';
import '../../data/models/movie_details.dart';
import '../../data/models/movie_draft.dart';
import '../../data/repositories/supabase_movies_repository.dart';
import '../../domain/repositories/movies_repository.dart';
import '../movie_formatters.dart';
import '../widgets/movie_poster_image.dart';
import '../widgets/movie_state_views.dart';
import '../../../../core/navigation/app_shell.dart';

/// Create (movieId == null) or edit a catalogue movie.
///
/// After creating, the page is replaced by the new movie's details page;
/// after editing, it pops with `true`.
class MovieFormPage extends StatefulWidget {
  const MovieFormPage({super.key, this.movieId, this.repository});

  final int? movieId;
  final MoviesRepository? repository;

  @override
  State<MovieFormPage> createState() => _MovieFormPageState();
}

class _MovieFormPageState extends State<MovieFormPage> {
  late final MoviesRepository _repository;
  final _formKey = GlobalKey<FormState>();
  MovieDraft _draft = MovieDraft();
  List<Genre> _genres = const [];

  late final TextEditingController _title;
  late final TextEditingController _originalTitle;
  late final TextEditingController _tagline;
  late final TextEditingController _overview;
  late final TextEditingController _runtime;
  late final TextEditingController _rating;
  late final TextEditingController _poster;
  late final TextEditingController _backdrop;
  late final TextEditingController _trailer;
  late final TextEditingController _directors;
  final List<(TextEditingController, TextEditingController)> _cast = [];

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  String? _castError;

  bool get _isEdit => widget.movieId != null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseMoviesRepository();
    _title = TextEditingController();
    _originalTitle = TextEditingController();
    _tagline = TextEditingController();
    _overview = TextEditingController();
    _runtime = TextEditingController();
    _rating = TextEditingController();
    _poster = TextEditingController();
    _backdrop = TextEditingController();
    _trailer = TextEditingController();
    _directors = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _originalTitle,
      _tagline,
      _overview,
      _runtime,
      _rating,
      _poster,
      _backdrop,
      _trailer,
      _directors,
    ]) {
      c.dispose();
    }
    for (final (name, character) in _cast) {
      name.dispose();
      character.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final genres = await _repository.getGenres();
      MovieDetails? details;
      if (_isEdit) {
        details = await _repository.getMovie(widget.movieId!);
        if (details == null) {
          throw const MovieException('This movie no longer exists.');
        }
      }
      if (!mounted) return;
      _genres = genres;
      _fill(details == null ? MovieDraft() : MovieDraft.fromDetails(details));
    } on MovieException catch (e) {
      _loadError = e.message;
    } catch (_) {
      _loadError = 'Could not load the form.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(MovieDraft draft) {
    _draft = draft;
    _title.text = draft.title;
    _originalTitle.text = draft.originalTitle;
    _tagline.text = draft.tagline;
    _overview.text = draft.overview;
    _runtime.text = draft.runtime;
    _rating.text = draft.rating;
    _poster.text = draft.posterUrl;
    _backdrop.text = draft.backdropUrl;
    _trailer.text = draft.trailer;
    _directors.text = draft.directors;
    for (final c in draft.cast) {
      _addCastRow(c.name, c.character);
    }
  }

  void _addCastRow([String name = '', String character = '']) {
    _cast.add((
      TextEditingController(text: name),
      TextEditingController(text: character),
    ));
  }

  MovieDraft _collect() {
    return _draft
      ..title = _title.text
      ..originalTitle = _originalTitle.text
      ..tagline = _tagline.text
      ..overview = _overview.text
      ..runtime = _runtime.text
      ..rating = _rating.text
      ..posterUrl = _poster.text
      ..backdropUrl = _backdrop.text
      ..trailer = _trailer.text
      ..directors = _directors.text
      ..cast = [
        for (final (name, character) in _cast)
          CastDraft(name: name.text, character: character.text),
      ];
  }

  Future<void> _save() async {
    final draft = _collect();
    final valid = _formKey.currentState?.validate() ?? false;
    final errors = draft.validate();
    setState(() => _castError = errors['cast']);
    if (!valid || errors.isNotEmpty) {
      _showMessage('Fix the highlighted fields first.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _repository.updateMovie(widget.movieId!, draft);
        _dirty = false;
        // Navigator.pop is not blocked by the unsaved-changes PopScope.
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final id = await _repository.createMovie(draft);
        _dirty = false;
        if (!mounted) return;
        _showMessage('"${draft.title.trim()}" added to the catalogue.');
        context.pushReplacement('/movie/$id');
      }
    } on MovieException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not save the movie. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.releaseDate ?? now,
      firstDate: DateTime(1888),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: 'Release date',
    );
    if (picked != null) {
      setState(() {
        _draft.releaseDate = picked;
        _dirty = true;
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty || _saving) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes to this movie will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const ShellLeading(),
          leadingWidth: shellLeadingWidth(context),
          title: Text(_isEdit ? 'Edit movie' : 'Add a movie'),
          actions: [
            if (!_loading && _loadError == null)
              TextButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save'),
              ),
          ],
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: MovieLoadError(message: _loadError!, onRetry: _load),
      );
    }

    return Form(
      key: _formKey,
      onChanged: () {
        if (!_dirty) setState(() => _dirty = true);
      },
      // Not a lazy ListView: every field stays built so Form.validate checks
      // all of them and their error messages survive scrolling.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section('Essentials'),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              maxLength: MovieDraft.maxTitle,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) => MovieDraft.validateTitle(v ?? ''),
            ),
            TextFormField(
              controller: _originalTitle,
              maxLength: MovieDraft.maxTitle,
              decoration: const InputDecoration(
                labelText: 'Original title',
                helperText: 'If different from the title',
              ),
              validator: (v) =>
                  MovieDraft.validateMaxLength(v ?? '', MovieDraft.maxTitle),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _draft.releaseDate == null
                          ? 'Release date'
                          : MovieFormatters.date(
                              _draft.releaseDate!.toIso8601String(),
                            ),
                    ),
                  ),
                ),
                if (_draft.releaseDate != null)
                  IconButton(
                    tooltip: 'Clear release date',
                    onPressed: () => setState(() {
                      _draft.releaseDate = null;
                      _dirty = true;
                    }),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _runtime,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Runtime',
                      suffixText: 'min',
                    ),
                    validator: (v) => MovieDraft.validateRuntime(v ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _rating,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Rating',
                      suffixText: '/ 10',
                    ),
                    validator: (v) => MovieDraft.validateRating(v ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _draft.language,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Language'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Unknown'),
                      ),
                      for (final entry
                          in (Languages.names.entries.toList()
                            ..sort((a, b) => a.value.compareTo(b.value))))
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      if (_draft.language != null &&
                          !Languages.names.containsKey(_draft.language))
                        DropdownMenuItem(
                          value: _draft.language,
                          child: Text(_draft.language!.toUpperCase()),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _draft.language = v;
                      _dirty = true;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _draft.status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final status in MovieDraft.statuses)
                        DropdownMenuItem(value: status, child: Text(status)),
                    ],
                    onChanged: (v) => setState(() {
                      _draft.status = v ?? 'Released';
                      _dirty = true;
                    }),
                  ),
                ),
              ],
            ),
            _section('Genres'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in _genres)
                  FilterChip(
                    label: Text(genre.name),
                    selected: _draft.genreIds.contains(genre.id),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _draft.genreIds.add(genre.id)
                          : _draft.genreIds.remove(genre.id);
                      _dirty = true;
                    }),
                  ),
              ],
            ),
            _section('Story'),
            TextFormField(
              controller: _tagline,
              maxLength: MovieDraft.maxTagline,
              decoration: const InputDecoration(labelText: 'Tagline'),
              validator: (v) =>
                  MovieDraft.validateMaxLength(v ?? '', MovieDraft.maxTagline),
            ),
            TextFormField(
              controller: _overview,
              minLines: 4,
              maxLines: 10,
              maxLength: MovieDraft.maxOverview,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Synopsis',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  MovieDraft.validateMaxLength(v ?? '', MovieDraft.maxOverview),
            ),
            _section('Media'),
            _ImageField(
              controller: _poster,
              label: 'Poster image URL',
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            _ImageField(
              controller: _backdrop,
              label: 'Backdrop image URL',
              onChanged: () => setState(() {}),
              wide: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _trailer,
              decoration: const InputDecoration(
                labelText: 'Trailer',
                hintText: 'https://www.youtube.com/watch?v=…',
                prefixIcon: Icon(Icons.play_circle_outline),
              ),
              validator: (v) => MovieDraft.validateTrailer(v ?? ''),
            ),
            _section('People'),
            TextFormField(
              controller: _directors,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Directors',
                helperText: 'Separate names with commas',
              ),
              validator: (v) => MovieDraft.validateDirectors(v ?? ''),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cast (${_cast.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: _cast.length >= MovieDraft.maxCast
                      ? null
                      : () => setState(() {
                          _addCastRow();
                          _dirty = true;
                        }),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add actor'),
                ),
              ],
            ),
            if (_castError != null)
              Text(
                _castError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (var i = 0; i < _cast.length; i++)
              Padding(
                key: ObjectKey(_cast[i]),
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cast[i].$1,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Actor'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _cast[i].$2,
                        decoration: const InputDecoration(labelText: 'Role'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove actor',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() {
                        final (name, character) = _cast.removeAt(i);
                        name.dispose();
                        character.dispose();
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isEdit ? 'Save changes' : 'Add to catalogue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// URL field with a live image preview.
class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.wide = false,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final url = controller.text.trim();
    final showPreview =
        url.isNotEmpty && MovieDraft.validateImageUrl(url) == null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'https://…',
            ),
            onChanged: (_) => onChanged(),
            validator: (v) => MovieDraft.validateImageUrl(v ?? ''),
          ),
        ),
        const SizedBox(width: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: wide ? 96 : 40,
            height: 56,
            child: showPreview
                ? MoviePosterImage(url: url, iconSize: 18)
                : const MoviePosterImage(url: null, iconSize: 18),
          ),
        ),
      ],
    );
  }
}
