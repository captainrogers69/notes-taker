# Weave

A local-first task and list app (Flutter) with Supabase sync, for macOS, Windows, iOS and Android.

## Run

1. Copy `config/dev.example.json` to `config/dev.json` and fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` (the publishable key; never the service-role key). `WEAVE_PROFILE` names the local DB folder, so two copies can run on one machine. `config/*.json` is git-ignored.
2. Run a flavor:

```sh
flutter run -t lib/main_dev.dart --flavor dev --dart-define-from-file=config/dev.json
```

Use `lib/main_prod.dart`, `--flavor prod` and `config/prod.json` for prod. On Windows omit `--flavor` (flavors apply to Android, iOS and macOS).

App IDs: `com.rogers.weave` (prod) and `com.rogers.weave.dev` (dev).

## Generated code

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Supabase

The schema lives in `supabase/migrations/`. It deploys through the Supabase GitHub integration when merged to the production branch (working directory `.`).
