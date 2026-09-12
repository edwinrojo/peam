# peam

PEAM-Registry mobile app for provincial event attendance.

## Download the APK

After a successful GitHub Actions build on `main`, the release APK is published on the repository **Releases** page:

**[Download peam-release.apk](https://github.com/edwinrojo/peam/releases/latest/download/peam-release.apk)**

That link always points at the newest build. You can also open [Releases](https://github.com/edwinrojo/peam/releases/latest).

Branch and pull-request builds still attach an APK under the workflow run (**Actions → Build Android APK → Artifacts**). Those expire; the Release file does not.

## Supabase employee login

HR creates employees with `create_employee` in `docs/schema.sql`. The mobile app signs in with **Employee ID + email OTP**, then binds one phone.

The phone never talks to the database with a service-role key. It only needs the **project URL** and **anon / publishable key**. Put those in a local `.env` (already gitignored):

```sh
cp .env.example .env
```

Then fill in the same values peam-web uses (`VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`). After that, `flutter run` is enough. Without a real `.env`, the app stays on the local prototype login (Employee ID `1234`, code `123456`).

The three files under `supabase/functions/` are **Edge Functions**. They run on Supabase, not in the Flutter app. Deploy them once per project; the app only *calls* them.

| Function | When the app calls it | What it does |
| --- | --- | --- |
| `request-login-otp` | Employee ID submitted | Looks up the HR email, sends a 6-digit code, returns a masked address |
| `verify-login-otp` | Code submitted | Checks the code, starts a session, binds this phone (or returns a device-change ticket) |
| `submit-device-change` | “Request new phone” | Files a `device_change_requests` row for HR |

Those functions read `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` from the **Supabase project environment**. You do not put those in the mobile `.env`. After `supabase link`, deploy with:

```bash
supabase functions deploy request-login-otp
supabase functions deploy verify-login-otp
supabase functions deploy submit-device-change
```

Also run `docs/schema.sql` (includes `bind_employee_device`). Free-tier projects cannot edit Auth email templates until **custom SMTP** is on. Enable it under Authentication → Email → SMTP Settings, then change the **Magic Link** template so employees get a 6-digit code, not a “Sign in” link:

1. Open [Authentication → Email Templates](https://supabase.com/dashboard/project/budujsspftecjkfnuobh/auth/templates).
2. Select **Magic Link**.
3. Set the subject to `Your PEAM sign-in code`.
4. Replace the body with `supabase/templates/magic_link.html` (must include `{{ .Token }}` and must **not** include `{{ .ConfirmationURL }}`).
5. Save, then request a new code from the app.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
