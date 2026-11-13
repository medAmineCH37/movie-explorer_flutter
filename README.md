# Movie Explorer

A Flutter application for discovering movies, exploring movie details, searching a movie catalogue, and managing personalized movie experiences.

Developed as a team project using Flutter and Supabase. The movie catalogue is stored in Supabase and seeded with 100 movies from TMDB.

## Project Status

The application is being developed collaboratively in separate feature modules. The Personal Collection Management module is implemented and integrated into `main`. Other modules are being developed by their assigned team members.

## Features

### Implemented

- Browse the movie catalogue stored in Supabase.
- Search movies and view movie details.
- Register, sign in, and sign out using Supabase Authentication.
- Store application data in Supabase.
- **Personal Collection Management**
  - Add and remove movies from Favorites.
  - Add and remove movies from the Watchlist.
  - Persist personal collections in Supabase.
  - Manage Favorites and Watchlist from dedicated collection tabs.
  - Add or remove movies directly from the Movie Details page.
  - Refresh collection data when navigating back from movie details.

- **Movie Management**
  - Movie catalogue stored in Supabase (`movies`, `genres`, `movie_genres`, `movie_credits`), seeded with 100 movies from TMDB.
  - Add, edit and delete movies (any signed-in user): title, dates, runtime, language, status, rating, genres, synopsis, poster/backdrop, trailer, directors and cast.
  - Popular, top-rated, now-playing and upcoming lists, with a featured movie on the home screen.
  - Catalogue screen with one tab per list and infinite scrolling.
  - Movie details with cast, directors, trailer, runtime, language and catalogue rating.
- **Movie Discovery**
  - Search by title, filter by genres, release years, minimum rating and language, sort by popularity, rating, date or title.
  - Edit or delete movies straight from the results, and add new ones.
- **Ratings & Reviews**
  - 1–5 star ratings (Poor to Masterpiece) with a community average, vote count and distribution.
  - One review per user and movie, with a spoiler flag, likes, reports and an edited indicator.
  - Full review list with four sorts and 10 reviews per page.
  - My ratings & reviews screen with personal statistics.
  - AI review drafting ("Help me write it") and AI review summaries (Gemini, through the `review-ai` Supabase Edge Function).
- **Recommendations & Custom Lists** (Module 6)
  - "For You" page: hero carousel, personal picks with % match, Top 10, genre rows.
  - Custom lists: 2–50 character name unique per user (case-insensitive), 20 lists and 100 movies max, no duplicates, private or public, owner-only edits.
  - Community lists (public lists, read-only) and recommendations per list.
  - Score = 2 × seed movies recommending it + 1 × shared favorite genres + TMDB rating / 10, shown as 55–99 % match. Falls back to trending without signals.
  - Requires `supabase/migrations/20261107_recommendations_custom_lists.sql`.


## Technology Stack

- **Frontend:** Flutter and Dart
- **Movie catalogue:** Supabase (sample data from TMDB)
- **Backend services and database:** Supabase
- **Navigation:** GoRouter
- **State management:** Riverpod
- **Image loading:** Cached Network Image

## Team and Module Ownership

| Module | Responsible teammate |
|---|---|
| User Management | Khadija |
| Movie Management | Baha |
| Ratings & Reviews | Zina |
| Personal Collection | Amine |
| Movie Discovery | Olfa |
| Recommendations & Custom Lists | Yasmine |

Shared files such as routing, themes, database configuration, and common widgets should be coordinated with the team before modification.

## Prerequisites

Install the following before running the project:

- Flutter SDK and Dart SDK
- Android Studio or another supported Flutter development environment
- Git
- A TMDB API key (only to regenerate the sample movies)
- A Supabase project with the required database schema

Verify your Flutter installation:

```bash
flutter doctor
```

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/medAmineCH37/movie-explorer_flutter.git
cd movie-explorer_flutter
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure environment variables

The project uses a local environment file for Supabase credentials (and the TMDB key used by the seed tool).

1. Copy the example configuration file:

   ```powershell
   Copy-Item env.example.json env.json
   ```

2. Open `env.json` and replace the placeholder values with your credentials:

   - `TMDB_API_KEY`: Your TMDB API key. Only `tool/generate_movie_seed.dart` uses it; the app does not call TMDB.
   - `SUPABASE_URL`: Your Supabase project URL.
   - `SUPABASE_ANON_KEY`: Your Supabase publishable or anon key, as expected by the project.

3. **Never commit `env.json`.** It is excluded by `.gitignore`. Commit only `env.example.json`, which contains placeholders.

Each team member must configure their own local `env.json` before running the application.

### 4. Configure the Supabase database

1. Create or access your Supabase project.
2. Open the SQL Editor in the Supabase dashboard.
3. Review and execute the SQL in `supabase/schema.sql`.
4. Confirm that the required tables, trigger, and Row Level Security policies exist.

The project must use a compatible schema before features that store user data can work.

Then run the migrations in `supabase/migrations/` in date order. `20261111_ratings_reviews.sql` creates the Ratings & Reviews tables (`ratings`, `review_likes`, `review_reports`), their policies and read functions, and migrates the old `reviews` table: each 1–10 rating becomes a 1–5 rating, rounded up. It can safely be run more than once.

`20261112_movies_catalogue.sql` creates the movie catalogue tables. After all migrations, load the sample catalogue with `supabase/seed/movies_seed.sql` (100 movies, their genres, directors and cast). Both are safe to run again. To refresh the sample data from TMDB:

```bash
dart run tool/generate_movie_seed.dart
```

### 4b. Deploy the AI review assistant (optional)

AI review drafts and AI review summaries run in the `review-ai` Supabase Edge Function. The Gemini key stays on the server and never ships in the app.

```bash
supabase secrets set GEMINI_API_KEY=your-gemini-key
supabase functions deploy review-ai --no-verify-jwt
```

Run `supabase/migrations/20261114_restore_review_ai.sql` to (re)create the `review_summaries` cache table.

`--no-verify-jwt` is required because the app's publishable key is not a JWT. The function checks the user itself for drafts, and summaries are public. `GEMINI_MODELS` (comma-separated) optionally overrides the model fallback chain. Without the function, everything else in Ratings & Reviews still works, and the AI buttons show an "unavailable" message.

### 5. Run the application

```bash
flutter run --dart-define-from-file=env.json
```

The environment file is local to each developer's machine and is not shared through Git.

## Quality Checks

Run these commands before submitting changes:

```bash
flutter analyze
flutter test
git diff --check
```

All checks should pass before a change is merged.

## Git Collaboration Workflow

Each module should be developed on its own feature branch. Do not work directly on `main`.

### 1. Start from the latest main branch

```bash
git switch main
git pull origin main
git switch -c feat/your-module-name
```

### 2. Commit and push your changes

```bash
git add .
git commit -m "feat: describe your change"
git push -u origin feat/your-module-name
```

### 3. Open a Pull Request

- Open a Pull Request from your feature branch into `main`.
- Describe the implemented changes and include the checks you ran.
- Ask the team to review the changes.
- Merge only after the changes have been reviewed and the quality checks pass.

### 4. Keep your local main branch up to date

Before starting another task, switch back to `main` and pull the latest changes:

```bash
git switch main
git pull origin main
```

If you need to continue working on an existing feature branch, bring the latest `main` changes into it before continuing.

### Supabase Auth email testing (Mailtrap)

For development, configure Supabase Auth to use a Mailtrap **Email Sandbox** SMTP inbox. Supabase sends its confirmation and password-reset messages to that sandbox so the team can inspect the emails without delivering them to real recipients. Configure the SMTP host, port, username, and password in the Supabase Dashboard under **Authentication → SMTP Settings**; keep credentials in the dashboard and never in `env.json`, Flutter code, or Git. Each developer should use the shared development inbox or a team-approved sandbox. Production needs a real transactional email provider and verified sender domain.

Before integrating User Management against an existing Supabase project, apply `supabase/migrations/20261113_user_management_profiles.sql` after reviewing it. It adds the profile fields required by the admin UI and protects role/account privilege fields with RLS and a trigger. It does not configure SMTP.

### Subscription Management

Apply `supabase/migrations/20261106_subscriptions.sql` after the base schema has created `public.profiles`. User Management owns profile identity and account roles; the separate `public.subscriptions` table is the source for plan history. The current subscription flow is a project demo: it does not charge payments or verify purchases. Its authenticated-user RLS allows a user to create and manage their own subscription rows, so do not use it as a real paid entitlement system without moving subscription writes behind a trusted backend and payment-provider verification.
