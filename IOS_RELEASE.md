# MedShelf — iOS Release Playbook

This file is the runbook for shipping MedShelf to the Apple App Store
via Codemagic. Follow it top-to-bottom; everything described below is
already wired up in the repo.

## ✅ What's already done in the repo

| Area | Status |
|------|--------|
| Bundle ID consistent (`com.medshelf.medshelf`) | ✅ |
| iOS deployment target `13.0` | ✅ |
| `ios/Podfile` with permission_handler macros | ✅ |
| `ios/Runner/Info.plist` with all 6 privacy strings + document types | ✅ |
| Firebase removed from app (was crashing iOS at launch) | ✅ |
| `_baseDir()` iOS branch (uses Documents folder, not external storage) | ✅ |
| Android-only "Find on Device" hidden on iOS | ✅ |
| Coach mark tour skips Android-only step on iOS | ✅ |
| `codemagic.yaml` workflow ready | ✅ |
| `flutter analyze lib` — 0 issues | ✅ |

## 🚀 First-time Codemagic setup (~30 min, one-time)

1. **Sign in at <https://codemagic.io>** with your GitHub account.
2. **Add repository**: pick `mulgundsunil1918/medshelf`.
3. **App Store Connect API key**:
   - Go to App Store Connect → Users and Access → Integrations → App Store
     Connect API → Generate New Key (Admin role)
   - Download the `.p8` file
   - In Codemagic: Teams → Integrations → App Store Connect →
     Add new integration → Name it `codemagic` (must match `codemagic.yaml`).
     Upload the `.p8`, paste Issuer ID + Key ID.
4. **Provisioning**: Codemagic auto-creates the iOS distribution certificate
   and App Store provisioning profile via the API key — no manual cert export.
5. **Trigger build**: push to `main` (or run "Start new build" in the
   Codemagic UI). The `ios-release` workflow runs.
6. **First build will fail** if the app entry doesn't exist yet in App
   Store Connect. Codemagic logs will tell you to "create the app first".
7. **Create the app** in App Store Connect:
   - My Apps → "+" → New App
   - Platform: iOS
   - Bundle ID: `com.medshelf.medshelf`
   - SKU: `medshelf-ios`
   - Default language: English
   - Save. Copy the numeric **Apple ID** shown (e.g. `1234567890`).
8. **Update `codemagic.yaml`** — replace `APP_STORE_APPLE_ID: "0000000000"`
   with the Apple ID from step 7. Commit + push.
9. **Re-run the build**. IPA uploads to TestFlight automatically.

## 📝 App Store listing — copy/paste ready

Stored in this repo's commit message of the iOS-readiness landing —
see the conversation log or the `docs/index.html` landing page for the
canonical strings.

**Reviewer notes** (paste into App Store Connect → App Review Information):

```
MedShelf does not require an account to use. On first launch the user
sees a 4-slide tutorial, picks specialties, then lands on the home
screen. All features (Import, Scan, Quick Note, Library, Search) are
accessible from the home screen with no sign-up.

The Scan button uses Apple's VisionKit on-device document scanner.
The camera is active only while the scanner UI is open.

No data is collected or transmitted. All files stay on the device.
The MedShelf folder is visible in the Files app under
"On My iPhone › MedShelf".
```

## 🐛 If a build fails

| Error class | Likely cause | Fix |
|-------------|--------------|-----|
| `pod install` fails | Stale lockfile | Delete `ios/Podfile.lock` and `ios/Pods/`, re-run |
| `Code signing failed` | API key not linked | Re-check the Codemagic integration name matches `codemagic.yaml` |
| `Bundle ID not registered` | App not created in App Store Connect | See step 7 above |
| `flutter analyze` failure | New lint rule | Run `flutter analyze lib` locally and fix |
| `xcode-project use-profiles` errors | Profile name mismatch | Codemagic regenerates these — re-run the workflow |

## 🔄 Subsequent releases

```bash
# Bump version in pubspec.yaml AND android/app/build.gradle.kts
# (versionName + versionCode for Android, build name + number for iOS)
git add .
git commit -m "Release v1.x.y"
git push origin main
# Codemagic triggers automatically; IPA goes to TestFlight in ~25 min.
```
