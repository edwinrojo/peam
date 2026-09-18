# peam

PEAM-Registry mobile app for provincial event attendance.

## Download the APK

After a successful GitHub Actions build on `main`, the release APK is published on the repository **Releases** page:

**[Download peam-release.apk](https://github.com/edwinrojo/peam/releases/latest/download/peam-release.apk)**

That link always points at the newest build. You can also open [Releases](https://github.com/edwinrojo/peam/releases/latest).

Branch and pull-request builds still attach an APK under the workflow run (**Actions → Build Android APK → Artifacts**). Those expire; the Release file does not.

Sign in shows **Demo** when the APK was built without real Supabase keys. GitHub cannot use your local `.env` (it is gitignored). Add repository secrets `SUPABASE_URL` and `SUPABASE_ANON_KEY` (same values as `.env`), then rebuild. Optional: `GOOGLE_MAPS_API_KEY`. Until those secrets exist, install a local build instead:

```sh
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Supabase employee login

HR creates employees with `create_employee` in `docs/schema.sql`. The mobile app signs in with **Employee ID + email OTP**, then binds one phone.

The phone never talks to the database with a service-role key. It only needs the **project URL** and **anon / publishable key**. Put those in a local `.env` (already gitignored):

```sh
cp .env.example .env
```

Then fill in the same values peam-web uses (`VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`). After that, `flutter run` is enough. Without a real `.env`, the app stays on the local prototype login (Employee ID `1234`, code `123456`).

The three files under `supabase/functions/` are **Edge Functions**. They run on Supabase, not in the Flutter app. Deploy them once per project; the app only *calls* them.

| Function | When it runs | What it does |
| --- | --- | --- |
| `request-login-otp` | Employee ID submitted | Looks up the HR email, sends a 6-digit code, returns a masked address |
| `verify-login-otp` | Code submitted | Checks the code, starts a session, binds this phone (or returns a device-change ticket) |
| `submit-device-change` | “Request new phone” | Files a `device_change_requests` row for HR |
| `send-push` | HR publishes/updates an event or reviews a device-change | Sends FCM to bound Android phones |

Those functions read `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and `FIREBASE_SERVICE_ACCOUNT` from the **Supabase project environment**. You do not put those in the mobile `.env`. After `supabase link`, deploy with:

```bash
supabase functions deploy request-login-otp
supabase functions deploy verify-login-otp
supabase functions deploy submit-device-change
supabase functions deploy send-push
```

On an existing database, also run `docs/alter_fcm_token.sql` so `devices.fcm_token` exists. Android FCM is configured; iOS is not yet.

Also run `docs/schema.sql` (includes `bind_employee_device`). Free-tier projects cannot edit Auth email templates until **custom SMTP** is on. Enable it under Authentication → Email → SMTP Settings, then change the **Magic Link** template so employees get a 6-digit code, not a “Sign in” link:

1. Open [Authentication → Email Templates](https://supabase.com/dashboard/project/budujsspftecjkfnuobh/auth/templates).
2. Select **Magic Link**.
3. Set the subject to `Your PEAM sign-in code`.
4. Replace the body with `supabase/templates/magic_link.html` (must include `{{ .Token }}` and must **not** include `{{ .ConfirmationURL }}`).
5. Save, then request a new code from the app.

## Maps and geofencing

Check-in uses **device GPS** and a local radius check against the event’s `latitude`, `longitude`, and `geofence_radius_meters`. That does **not** need a Google API key.

The map on the Check-in screen uses **Google Maps SDK**. Enable these APIs on a Google Cloud project, create an API key, and restrict it to the PEAM Android/iOS apps:

- Maps SDK for Android
- Maps SDK for iOS

Add the key to `.env`:

```
GOOGLE_MAPS_API_KEY=your-key
```

Android reads that value at build time. For iOS, copy `ios/Flutter/MapsSecrets.xcconfig.example` to `ios/Flutter/MapsSecrets.xcconfig` and set the same key.

Geocoding API and Places API are **not** required on the phone. HR already sets the venue pin in peam-web.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
