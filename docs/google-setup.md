# Google Cloud setup

The app stores its data in a Google Sheet ("Project Tracker DB") in the signed-in user's own Google Drive. It uses the `drive.file` scope, so it can only see files it created itself. You need a Google Cloud project once.

## 1. Create a project
1. Open <https://console.cloud.google.com/> and sign in with the Google account you will use.
2. Project picker (top bar) → **New project** → name it `Project Tracker` → **Create**. Make sure it is selected.

## 2. Enable the APIs
**APIs & Services → Library**, then search for and **Enable**:
- **Google Sheets API**
- **Google Drive API**

## 3. OAuth consent screen
1. **APIs & Services → OAuth consent screen** (shown as "Google Auth Platform" in newer consoles) → **Get started**.
2. App name `Project Tracker`, user support email = your email. Audience: **External**. Add your email as contact → **Create**.
3. **Data access / Scopes** → add `.../auth/drive.file`. (This is a non-sensitive scope, so no Google verification is needed.)
4. **Audience** → **Publish app** → confirm **In production**.
   - Important: apps left in *Testing* status have refresh tokens that expire after **7 days**, which would sign you out weekly. Publishing to production avoids that. With only the `drive.file` scope you will not need verification; an "unverified app" screen may not even appear.

## 4. Android OAuth client (debug SHA-1)
1. Get the debug SHA-1 (PowerShell):
   ```powershell
   keytool -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android
   ```
   (cmd.exe form: `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android`.) Copy the `SHA1:` line.
2. **APIs & Services → Credentials → Create credentials → OAuth client ID** → type **Android**.
3. Package name: `com.techtogrow.project_tracker` (the `applicationId` in `android/app/build.gradle.kts`; it must match exactly).
4. Paste the SHA-1 → **Create**.
5. For a release build you need a second Android client using the SHA-1 of your release keystore (or Play App Signing key).

## 5. Web client ID (`GOOGLE_SERVER_CLIENT_ID`)
google_sign_in v7 on Android needs a *Web* client ID as the server client ID.
1. **Credentials → Create credentials → OAuth client ID** → type **Web application** → name `Project Tracker web` → **Create**.
2. Copy the **Client ID** (`xxxx.apps.googleusercontent.com`). No redirect URIs are needed.

## 6. Run the app
```powershell
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
```
Release build:
```powershell
flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
```
On first launch tap **Sign in with Google**, accept the Drive access prompt; the app creates the "Project Tracker DB" sheet.

## Troubleshooting
- **Sign-in fails immediately / `DEVELOPER_ERROR` / code 10**: the package name or SHA-1 of the Android client does not match the build, or `GOOGLE_SERVER_CLIENT_ID` is missing or is not a *Web* client.
- **Works for a week, then asks to sign in again**: the consent screen is still in *Testing*; publish it (step 3.4).
- **403 / API not enabled**: enable both Sheets and Drive APIs in the same project that owns the OAuth clients.
- Changes to OAuth clients can take a few minutes to apply.
