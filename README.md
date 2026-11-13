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

### Planned / In Development

- Ratings and Reviews Management.
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
