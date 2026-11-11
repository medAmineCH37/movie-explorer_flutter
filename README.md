# Movie Explorer

A Flutter application for discovering movies, exploring movie details, searching a movie catalogue, and managing personalized movie experiences.

Developed as a team project using Flutter, the TMDB API, and Supabase.

## Project Status

The application is being developed collaboratively in separate feature modules. The Personal Collection Management module is implemented and integrated into `main`. Other modules are being developed by their assigned team members.

## Features

### Implemented

- Browse popular movies from TMDB.
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
  - Popular, top-rated, now-playing and upcoming lists from TMDB, with a featured movie on the home screen.
  - Catalogue screen with one tab per list and infinite scrolling.
  - Movie details with cast, directors, trailer, runtime, language and TMDB rating.
- **Ratings & Reviews**
  - 1–5 star ratings (Mauvais to Chef-d'œuvre) with a community average, vote count and distribution.
  - One review per user and movie, with a spoiler flag, likes, reports and an edited indicator.
  - Full review list with four sorts and 10 reviews per page.
  - My ratings & reviews screen with personal statistics.
  - AI review drafting and AI review summaries (Gemini, through a Supabase Edge Function).

### Planned / In Development

- Movie Discovery Management.
- Recommendations and Custom Lists Management.

## Technology Stack

- **Frontend:** Flutter and Dart
- **Movie catalogue:** TMDB API
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
- A TMDB API key
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

The project uses a local environment file for TMDB and Supabase credentials.

1. Copy the example configuration file:

   ```powershell
   Copy-Item env.example.json env.json
   ```

2. Open `env.json` and replace the placeholder values with your credentials:

   - `TMDB_API_KEY`: Your TMDB API key.
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

Then run the migrations in `supabase/migrations/` in date order. `20261111_ratings_reviews.sql` creates the Ratings & Reviews tables (`ratings`, `review_likes`, `review_reports`, `review_summaries`), their policies and read functions, and migrates the old `reviews` table: each 1–10 rating becomes a 1–5 rating, rounded up. It can safely be run more than once.

### 4b. Deploy the AI review assistant (optional)

AI review drafts and AI review summaries run in the `review-ai` Supabase Edge Function. The Gemini key stays on the server and never ships in the app.

```bash
supabase secrets set GEMINI_API_KEY=your-gemini-key TMDB_API_KEY=your-tmdb-key
supabase functions deploy review-ai --no-verify-jwt
```

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
