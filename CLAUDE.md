# Project Tracker (Flutter, Android-first)

Standalone app, unrelated to the TTG customer database. One user, no own server, no Firebase. Data lives in the user's Google Drive as a Google Sheet ("Project Tracker DB"). Monthly report is built on the phone as .xlsx, shared via the share sheet, never kept.

## Layout
- `lib/models.dart` – Project, Member, WorkEntry (`toRow`/`fromRow` map to sheet columns)
- `lib/data/repository.dart` – `TrackerRepository` interface. Screens use only this. A REST repository can replace `SheetsRepository` by changing `repoProvider` in `lib/providers.dart`.
- `lib/data/sheets_repository.dart` – Sheets/Drive implementation (soft-delete flag column)
- `lib/data/google_auth.dart` – google_sign_in v7, scope `drive.file`
- `lib/screens/` – home (bottom nav), projects (+detail with member checklist), members, entries, reports
- `lib/report/report_service.dart` – .xlsx builder and share; `lib/util.dart` – hours calc, error messages
- `docs/google-setup.md` – Google Cloud setup (manual, cannot be automated)

## Commands
- Run: `flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>`
- Check: `flutter analyze` and `flutter test` (keep both clean)

## Rules
- No offline mode in v1; network errors show a "No internet" message (`friendlyError`).
- Hours: `hoursBetween` treats end < start as crossing midnight.
- Do not commit or push unless asked.
