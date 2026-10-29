# Movie Explorer

A Flutter application for discovering movies, exploring movie details, searching a movie catalogue, and managing personalized movie experiences.

Developed as a team project using Flutter, TMDB, and Supabase.

## Features

- Browse popular movies from TMDB.
- Search movies and view their details.
- Register, sign in, and sign out using Supabase Authentication.
- Store application data in Supabase.
- Planned modules for ratings and reviews, personal collections, discovery, and custom lists.

## Technology Stack

- **Frontend:** Flutter and Dart
- **Movie catalogue:** TMDB API
- **Backend services and database:** Supabase
- **Navigation:** GoRouter
- **State management:** Riverpod (available for feature development)
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

Shared files such as routing, themes, database configuration, and common widgets should be coordinated before modification.

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

### Environment configuration

The project uses local environment variables for TMDB and Supabase credentials.

1. Copy the example configuration file:

   ```powershell
   Copy-Item env.example.json env.json
   ```

2. Open `env.json` and replace the placeholder values with your own credentials:
   - `TMDB_API_KEY`: Your TMDB API key.
   - `SUPABASE_URL`: Your Supabase project URL.
   - `SUPABASE_ANON_KEY`: Your Supabase publishable or anon key, as expected by the project.

3. **Never commit `env.json`**. It is excluded by `.gitignore`. Commit only `env.example.json`, which contains placeholders.

Each team member must configure their own local `env.json` before running the application.

### 4. Configure the Supabase database

1. Create or access your Supabase project.
2. Open the SQL Editor in the Supabase dashboard.
3. Review and execute the SQL in `supabase/schema.sql`.
4. Confirm that the required tables, trigger, and row-level security policies exist.

The project must use a compatible schema before features that store user data can work.

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

To start work on a module, create a branch from the latest `main`:

```bash
git switch main
git pull origin main
git switch -c feat/your-module-name
```

Commit focused changes with descriptive messages:

```bash
git add .
git commit -m "feat: describe your change"
git push