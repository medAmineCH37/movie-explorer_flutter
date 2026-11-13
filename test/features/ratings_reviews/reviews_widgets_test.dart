import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movie_explorer/features/movie_management/data/models/movie.dart';
import 'package:movie_explorer/features/ratings_reviews/presentation/pages/my_ratings_page.dart';
import 'package:movie_explorer/features/ratings_reviews/presentation/widgets/movie_reviews_section.dart';
import 'package:movie_explorer/features/ratings_reviews/presentation/widgets/review_card.dart';
import 'package:movie_explorer/features/ratings_reviews/presentation/widgets/review_composer_sheet.dart';
import 'package:movie_explorer/features/ratings_reviews/presentation/widgets/star_rating.dart';

import 'fake_reviews_repository.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const movie = Movie(
  id: 1,
  title: 'Inception',
  overview: '',
  posterPath: null,
  backdropPath: null,
  voteAverage: 8.4,
  releaseDate: '2010-07-16',
);

void main() {
  group('ReviewCard', () {
    testWidgets('hides spoilers from others until revealed', (tester) async {
      await tester.pumpWidget(
        host(
          ReviewCard(
            review: review(
              1,
              spoiler: true,
              content: 'The top keeps spinning.',
            ),
            isSignedIn: true,
          ),
        ),
      );
      expect(find.text('The top keeps spinning.'), findsNothing);
      await tester.tap(find.text('Show review'));
      await tester.pump();
      expect(find.text('The top keeps spinning.'), findsOneWidget);

      await tester.tap(find.text('Hide spoiler'));
      await tester.pump();
      expect(find.text('The top keeps spinning.'), findsNothing);
      expect(find.text('Show review'), findsOneWidget);
    });

    testWidgets('never hides spoilers from their author', (tester) async {
      await tester.pumpWidget(
        host(
          ReviewCard(
            review: review(1, userId: me, spoiler: true, content: 'Twist!'),
            isSignedIn: true,
          ),
        ),
      );
      expect(find.text('Twist!'), findsOneWidget);
      expect(find.text('Contains spoilers'), findsOneWidget);
    });

    testWidgets('truncates long reviews behind Read more', (tester) async {
      final long = 'a' * 300;
      await tester.pumpWidget(
        host(ReviewCard(review: review(1, content: long), isSignedIn: false)),
      );
      expect(find.text('${'a' * 280}…'), findsOneWidget);
      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      expect(find.text(long), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('shows score label, edited mark and like count', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ReviewCard(
            review: review(1, score: 4, likes: 2, edited: true, author: 'zoé'),
            isSignedIn: true,
          ),
        ),
      );
      expect(find.text('Very good'), findsOneWidget);
      expect(find.textContaining('edited'), findsOneWidget);
      expect(find.text('2 likes'), findsOneWidget);
      expect(find.text('Z'), findsOneWidget);
    });

    testWidgets('menu depends on ownership and role', (tester) async {
      Future<List<String>> menuFor(ReviewCard card) async {
        await tester.pumpWidget(host(card));
        final button = find.byTooltip('Review actions');
        if (button.evaluate().isEmpty) return [];
        await tester.tap(button);
        await tester.pumpAndSettle();
        final items = [
          for (final label in ['Edit', 'Delete', 'Delete (admin)', 'Report'])
            if (find.text(label).evaluate().isNotEmpty) label,
        ];
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();
        return items;
      }

      void noop() {}
      ReviewCard card(
        String userId, {
        bool signedIn = true,
        bool admin = false,
      }) => ReviewCard(
        review: review(1, userId: userId),
        isSignedIn: signedIn,
        isAdmin: admin,
        onEdit: noop,
        onDelete: noop,
        onReport: noop,
      );

      expect(await menuFor(card(me)), ['Edit', 'Delete']);
      expect(await menuFor(card('other')), ['Report']);
      expect(await menuFor(card('other', admin: true)), [
        'Delete (admin)',
        'Report',
      ]);
      expect(await menuFor(card('other', signedIn: false)), isEmpty);
    });

    testWidgets('own review cannot be liked', (tester) async {
      var liked = false;
      await tester.pumpWidget(
        host(
          ReviewCard(
            review: review(1, userId: me),
            isSignedIn: true,
            onLike: () async => liked = true,
          ),
        ),
      );
      await tester.tap(find.text('0 likes'));
      expect(liked, isFalse);
    });
  });

  testWidgets('StarRatingInput reports taps and shows the label', (
    tester,
  ) async {
    int? value;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => StarRatingInput(
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel(RegExp(r'^5 stars')));
    await tester.pumpAndSettle();
    expect(value, 5);
    expect(find.text('Masterpiece'), findsOneWidget);
  });

  group('Report dialog', () {
    testWidgets('saves the selected reasons once per user', (tester) async {
      final repo = FakeReviewsRepository()
        ..reviews.add(review(1, userId: 'someone-else'));

      await tester.pumpWidget(
        host(
          MovieReviewsSection(
            movie: movie,
            repository: repo,
            authChanges: const Stream.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> openReport() async {
        await tester.tap(find.byTooltip('Review actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Report'));
        await tester.pumpAndSettle();
      }

      await openReport();
      expect(find.text('Report review'), findsOneWidget);
      FilledButton submit() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Report'),
      );
      expect(submit().onPressed, isNull, reason: 'needs a reason');

      await tester.tap(find.widgetWithText(FilterChip, 'Spam'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Same text everywhere');
      await tester.tap(find.widgetWithText(FilledButton, 'Report'));
      await tester.pumpAndSettle();

      expect(repo.lastReportReason, 'Spam: Same text everywhere');
      expect(find.text('Thanks, the review was reported.'), findsOneWidget);

      // A second report is refused by the backend and shown in the dialog.
      await openReport();
      await tester.tap(find.widgetWithText(FilterChip, 'Other'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Report'));
      await tester.pumpAndSettle();
      expect(find.text('You already reported this review.'), findsOneWidget);
      expect(repo.reports, hasLength(1));
    });
  });

  group('ReviewComposer', () {
    testWidgets('publishes only valid text and creates the review', (
      tester,
    ) async {
      final repo = FakeReviewsRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewComposer(
              repository: repo,
              movieId: 1,
              movieTitle: 'Inception',
              movieYear: '2010',
            ),
          ),
        ),
      );

      FilledButton publish() => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Publish review'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );

      await tester.enterText(find.byType(TextField).first, '  ab  ');
      await tester.pump();
      expect(publish().onPressed, isNull);
      expect(find.textContaining('2 / 1000'), findsOneWidget);

      expect(find.text('Help me write it'), findsNothing);

      await tester.enterText(
        find.byType(TextField).first,
        '  Great visuals, slow ending.  ',
      );
      await tester.tap(find.text('Contains spoilers'));
      await tester.pump();
      expect(publish().onPressed, isNotNull);

      await tester.tap(find.text('Publish review'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('create'));
      expect(repo.reviews.single.content, 'Great visuals, slow ending.');
      expect(repo.reviews.single.spoiler, isTrue);
    });
  });

  group('MovieReviewsSection', () {
    testWidgets('signed-out viewers see the community rating and a CTA', (
      tester,
    ) async {
      final repo = FakeReviewsRepository(userId: null)
        ..ratings[('a', 1)] = 4
        ..ratings[('b', 1)] = 3
        ..reviews.add(review(1, userId: 'a', likes: 2));

      await tester.pumpWidget(
        host(
          MovieReviewsSection(
            movie: movie,
            repository: repo,
            authChanges: const Stream.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3.5'), findsOneWidget);
      expect(find.text('2 votes'), findsOneWidget);
      expect(find.text('Sign in to review'), findsOneWidget);
      expect(find.text('Most liked'), findsOneWidget);
      expect(find.text('See the review'), findsOneWidget);
    });

    testWidgets('pins my review above the latest ones', (tester) async {
      final repo = FakeReviewsRepository()
        ..ratings[(me, 1)] = 5
        ..reviews.addAll([review(1, userId: me), review(2, userId: 'x')]);

      await tester.pumpWidget(
        host(
          MovieReviewsSection(
            movie: movie,
            repository: repo,
            authChanges: const Stream.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your review'), findsOneWidget);
      expect(find.text('Your rating'), findsOneWidget);
      expect(find.text('Write a review'), findsNothing);
      expect(find.textContaining('You reviewed this movie'), findsOneWidget);
      expect(find.text('Latest reviews'), findsOneWidget);
      expect(find.text('Summarize reviews with AI'), findsNothing);
    });

    testWidgets('empty state invites the first review', (tester) async {
      await tester.pumpWidget(
        host(
          MovieReviewsSection(
            movie: movie,
            repository: FakeReviewsRepository(),
            authChanges: const Stream.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No reviews yet'), findsOneWidget);
      expect(find.text('Write a review'), findsOneWidget);
      expect(find.text('Rate this movie'), findsOneWidget);
    });
  });

  testWidgets('MyRatingsPage shows stats and removed movies', (tester) async {
    final repo = FakeReviewsRepository()
      ..ratings[(me, 1)] = 4
      ..reviews.add(review(5, movieId: 2, userId: me, likes: 3, spoiler: true));

    await tester.pumpWidget(
      MaterialApp(
        home: MyRatingsPage(
          repository: repo,
          movieLookup: (ids) async => {if (ids.contains(1)) 1: movie},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Films rated'), findsOneWidget);
    expect(find.text('4.0 ★'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // likes received
    expect(find.text('Inception'), findsOneWidget);
    expect(find.text('Removed from the catalogue'), findsOneWidget);
    expect(find.text('Spoiler'), findsOneWidget);
    expect(find.text('Write a review'), findsOneWidget); // only for Inception
  });
}
