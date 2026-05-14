# MedShelf — Project Context for AI Assistants

> Read this file FIRST when continuing development on this app.
> It captures every important architectural decision and recent change
> so a fresh Claude / new IDE / new machine can pick up where the last
> session left off.

---

## 🏥 What MedShelf Is

A personal **medical-study file organiser** for medical students and
doctors. Offline-first. No accounts, no cloud, no ads.

- **Created by**: Dr. Sunil Mulgund (`mulgundsunil@gmail.com`)
- **Bundle / Package ID**: `com.medshelf.medshelf`
- **Current version**: `1.2.0+17` (Android-policy compliant build)
- **Play Store URL**: <https://play.google.com/store/apps/details?id=com.medshelf.medshelf>
- **Landing page**: <https://mulgundsunil1918.github.io/medshelf/>
  ⚠️ Hosted from `docs/` via GitHub Pages — requires the repo to stay
  public OR move to Netlify/Cloudflare Pages/bridgr.co.in when the repo
  goes private.
- **Support / dev page**: <https://bridgr.co.in/> (developer site)
- **Support link from app**: `https://bridgr.co.in/support?from=medshelf`

---

## 🛠️ Tech Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Framework | Flutter 3.29+ / Dart 3.11+ | Material 3, `useMaterial3: true` |
| State | `provider` 6.x | TopicService, ThemeNotifier, FileNotifier — singletons via `ChangeNotifier` |
| Local DB | `sqflite` 2.x + `sqflite_common_ffi` | Tables: `files`, `custom_topics` |
| File storage | scoped external (`getExternalStorageDirectory()`) | NO MANAGE_EXTERNAL_STORAGE — see "Storage" section |
| File picker | `file_picker` ^8.1.7 | Uses SAF on Android |
| Share intent in | `receive_sharing_intent` ^1.8.0 | SEND + SEND_MULTIPLE |
| Share out | `share_plus` ^10.1.4 | `Share.shareXFiles` API |
| Open files | `open_filex` ^4.5.0 | System default app |
| PDF preview | `pdfx` ^2.5.0 | Renders first-page thumbnails, cached in memory |
| Video | `video_player` + `chewie` | Native iOS + Android |
| Document scanner | `cunning_document_scanner` ^1.2.5 | Google ML Kit Doc Scanner (Android) + VisionKit (iOS) |
| Multi-page → PDF | `pdf` ^3.11.1 | Used to stitch multi-page scans |
| Rich-text editor | `flutter_quill` ^11.0.0 | Notes saved as Delta JSON |
| Localizations | `flutter_localizations` | **Required** for `FlutterQuillLocalizations.delegate` |
| Notifications? | NOT INSTALLED | We removed firebase_local_notifications; not needed |
| Firebase? | **REMOVED** | Was unused. Removing fixed an iOS launch crash. |
| Permissions | `permission_handler` ^12.0.1 | Pulled transitively by cunning_document_scanner; nothing in our code calls it directly |
| Fonts | `google_fonts` (Nunito) | All headings + body |
| Animations | `flutter_animate` | Tutorial slides, FAB rotations |
| Onboarding flags | `shared_preferences` | See `OnboardingService` |
| Versioning | `package_info_plus` ^9.0.0 | Reads `buildNumber` to auto-reset tutorial on upgrade |

---

## 📁 Project Layout

```
lib/
├── main.dart                              # Entry. ThemeNotifier + TopicService loaded. SplashScreen as initial.
├── data/medical_specialties.dart          # 30+ pre-loaded specialty tree (defaultTopics)
├── models/
│   ├── med_file.dart                      # Document entity. .isNote distinguishes notes from files.
│   └── topic.dart                         # Category/specialty entity, supports nested children.
├── services/
│   ├── database_service.dart              # SQLite singleton. saveFile/updateFile/deleteFile/moveFile/getFilesForTopics
│   ├── file_storage_service.dart          # Disk I/O. _baseDir() iOS-aware. createNote + storeFile + moveFile.
│   ├── topic_service.dart                 # ChangeNotifier for the topic tree. addTopic auto-creates physical folder.
│   ├── camera_scan_service.dart           # cunning_document_scanner wrapper. Returns JPG (single) or stitched PDF (multi).
│   ├── file_notifier.dart                 # ChangeNotifier — broadcasts file-list refresh signals
│   ├── onboarding_service.dart            # SharedPrefs flags (has_seen_tutorial, has_completed_onboarding, has_seen_coach_marks)
│   └── (permission_service.dart REMOVED)  # We no longer request runtime storage perms; everything uses SAF/scoped
├── screens/
│   ├── splash_screen.dart                 # Animated logo → routes to Tutorial / Onboarding / MainShell
│   ├── tutorial_screen.dart               # 4-slide animated intro (problem → save → folders → find/share)
│   ├── specialty_onboarding_screen.dart   # User picks 1-N specialties to focus on
│   ├── main_shell.dart                    # Bottom-nav container (Home/Library/Search/Settings) + share-intent handler
│   ├── home_screen.dart                   # Action pills (Import / Find / Scan) + Quick Note + Browse by Specialty
│   ├── library_screen.dart                # Grid/list view of topic tree. _TopicCardsScreen for nested subfolders.
│   ├── file_list_screen.dart              # Files inside a topic. Subfolder strip + file rows + speed-dial FAB.
│   ├── file_properties_screen.dart        # "File Info" sheet — rename/move/share/delete
│   ├── note_viewer_screen.dart            # Quill editor for existing notes. Back-compat with old plain-text notes.
│   ├── batch_import_screen.dart           # Multi-file import. Accepts preloadedPaths from share intent.
│   ├── device_file_search_screen.dart     # ANDROID-ONLY — scans /Android/media/ paths for medical files. Hidden on iOS.
│   ├── all_files_screen.dart              # Flat searchable list of every file in DB
│   ├── search_screen.dart                 # Main search tab
│   ├── manage_specialties_screen.dart     # Add/remove specialties (settings → My Specialties)
│   ├── settings_screen.dart               # Theme toggle, tutorial replay, support link, storage size, about
│   └── about_screen.dart                  # Dev bio + social links (Instagram, YouTube, Bridgr)
├── widgets/
│   ├── add_note_sheet.dart                # Bottom sheet for creating a new note. Quill editor + 8 highlight chips.
│   ├── coach_mark_overlay.dart            # Interactive walkthrough — spotlight cutout + tooltip card
│   ├── edit_topic_sheet.dart              # Rename/emoji edit for a topic
│   ├── file_thumbnail.dart                # 56x56 PDF/image preview tile. Static memory cache by file.id.
│   ├── medical_emoji_picker.dart          # Picker for topic emoji
│   ├── save_file_sheet.dart               # After file picked/shared: name + topic + bookmark
│   ├── support_banner.dart                # Coral CTA banner on home (links to bridgr.co.in/support)
│   ├── support_popup.dart                 # Same CTA as modal dialog. Gated by 7-day SharedPrefs cooldown.
│   ├── topic_selector_widget.dart         # 3-level cascading specialty picker (used in save sheets)
│   └── topic_tree_widget.dart             # Nested tree of topics for the library list view
└── utils/
    ├── app_colors.dart                    # _kTeal #006B74 (primary), _kCoral #E8835A (accent)
    ├── app_theme.dart                     # ThemeData light + dark with Nunito font + ThemeNotifier
    ├── constants.dart                     # kSupportLink, kBridgrHomeLink, kSupportPopupCooldownDays = 7
    ├── file_type_icon.dart                # File extension → emoji + color
    ├── note_text.dart                     # Quill Delta JSON → plain text snippet (for file-list previews)
    └── share_helper.dart                  # ShareHelper.shareFile(file) — used by every Share button
```

---

## 🎨 Design Tokens

- **Primary**: Teal `#006B74` (AppBar bg, primary buttons, tab indicator)
- **Primary Dark**: `#004A52` (gradients)
- **Accent**: Coral `#E8835A` (FAB, CTAs, highlights)
- **Background**: surface (`#F0F7F8` light, `#0D1B1E` dark)
- **Font**: Nunito (via `google_fonts`)
  - Hero: 28-56pt, w900
  - Title: 18-22pt, w800
  - Body: 14-16pt, w400

Both light and dark mode are styled — toggle via Settings → Appearance.

---

## 💾 Storage Architecture (CRITICAL — read before touching paths)

### Android (post Google Play policy compliance)
```
/storage/emulated/0/Android/data/com.medshelf.medshelf/files/MedShelf/
  ├─ Pediatrics/
  │   ├─ Neonatology/
  │   │   └─ Resuscitation/foo.pdf
  │   └─ ECG_Guide.pdf
  └─ Internal Medicine/Cardiology/...
```

- **NO MANAGE_EXTERNAL_STORAGE permission** — Google rejects this for non-file-manager apps.
- **NO READ/WRITE_EXTERNAL_STORAGE** either — granular media perms only on A13+.
- File imports route through `file_picker` (SAF) — system grants per-file access.
- The scoped folder is still visible in the Files app under `Android > data > com.medshelf.medshelf > files`.
- Files **DELETE on app uninstall** — this is a user-facing behaviour change from pre-v1.2.0 but is Play-policy compliant.

### iOS
```
~/Library/Containers/com.medshelf.medshelf/Data/Documents/MedShelf/
  └─ ...same tree...
```
- Exposed to Apple Files app via `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` in `Info.plist`.
- Shows under **On My iPhone › MedShelf**.

### `_baseDir()` logic (in `file_storage_service.dart`)
- iOS / macOS → `getApplicationDocumentsDirectory()`
- Android → `getExternalStorageDirectory()` (scoped — auto-resolves to the Android/data path above)

---

## 📲 Permissions Matrix

| Permission | Android | iOS | Used by |
|-----------|---------|-----|---------|
| CAMERA | ✅ manifest | NSCameraUsageDescription | cunning_document_scanner (Scan button) |
| READ_MEDIA_IMAGES/VIDEO/AUDIO | ✅ A13+ manifest only | NSPhotoLibraryUsageDescription | file_picker (Import) |
| ~~MANAGE_EXTERNAL_STORAGE~~ | ❌ REMOVED in v1.2.0 | n/a | Was used pre-v1.2.0; Play rejected |
| ~~READ/WRITE_EXTERNAL_STORAGE~~ | ❌ REMOVED in v1.2.0 | n/a | Was legacy pre-A11 fallback |
| Microphone | not requested | NSMicrophoneUsageDescription (declared but not used) | Reserved for future voice notes |

There is no runtime "Permission needed" dialog in v1.2.0 — the app launches straight into the home screen.

---

## 📝 Note Format

Notes are saved as **Quill Delta JSON** in `.txt` files (legacy extension kept for backward compatibility).

```json
[
  {"insert": "Lecture notes\n", "attributes": {"bold": true}},
  {"insert": "Bullet 1\n", "attributes": {"list": "bullet"}},
  {"insert": "Highlighted ", "attributes": {"background": "#FFF59D"}},
  {"insert": "word"}
]
```

- `lib/utils/note_text.dart` decodes Delta → plain text snippet for file-list previews.
- `note_viewer_screen.dart` tries to parse as JSON first; falls back to plain-text rendering for ancient notes.
- `add_note_sheet.dart` always saves as Delta JSON.

---

## 🚀 Build / Release

### Local builds (Windows dev machine)
```bash
flutter pub get
flutter analyze lib              # MUST be 0 issues before any build
flutter build apk --release      # APK at build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release # AAB at build/app/outputs/bundle/release/app-release.aab
```

### Keystore (Android)
- Location: `android/app/medshelf-release.jks`
- Alias: `medshelf`
- Passwords stored in `android/key.properties` (gitignored)
- SHA1 `D2:D0:3B:1E:5D:06:DF:0E:9F:5A:4D:57:DE:C1:18:9B:C7:B1:EC:7A` — this is what Play Console has registered as the upload key
- ⚠️ If `key.properties` is missing on a fresh clone, the file is in `.gitignore` for security. Re-create with:
  ```
  storePassword=MedShelf@2026#Secure
  keyPassword=MedShelf@2026#Secure
  keyAlias=medshelf
  storeFile=../app/medshelf-release.jks
  ```
  (or whichever password was set — check the developer's secure storage)

### Versioning convention
- `pubspec.yaml` version: `MAJOR.MINOR.PATCH+BUILDCODE`
- `android/app/build.gradle.kts` mirrors this as `versionName` + `versionCode`
- **versionCode increments by 1 every Play Store upload (rejected uploads still consume the code!)**

### iOS / Codemagic
- `codemagic.yaml` workflow `ios-release` runs on `mac_mini_m2`
- See `IOS_RELEASE.md` for the step-by-step
- App Store Connect Apple ID placeholder `0000000000` needs to be replaced once the app is created in App Store Connect

---

## 📜 Version History (recent → old)

| Version | Build | Key change |
|---------|-------|-----------|
| **1.2.0** | 17 | **Removed MANAGE_EXTERNAL_STORAGE** — Play policy compliance. Scoped storage everywhere. No more permission dialog at launch. |
| 1.1.5 | 16 | Removed GitHub references from landing page (prep for private repo) |
| 1.1.4 | 15 | iOS readiness: Podfile, Info.plist, codemagic.yaml, Firebase removed, iOS-aware storage, Find-on-Device hidden on iOS |
| 1.1.3 | 14 | Fixed cold-start share (permission dialog was blocking save sheet). Multi-file share routes to BatchImportScreen with preloadedPaths. |
| 1.1.2 | 13 | File-list note previews decode Delta JSON instead of showing raw `[{"insert":"…"}]`. Removed duplicate color strips in editor. |
| 1.1.1 | 12 | Quill toolbar visibility bug fixed (FlutterQuillLocalizations.delegate added). Compact single-row layout. |
| 1.1.0 | 10/11 | Scan Documents + Rich-text notes + Share button on every row. Toolbar redesigned. |
| 1.0.3 | 7 | Integrated flutter_quill for rich notes |
| 1.0.2 | 6 | Strong delete confirmation (file count + permanent warning). Auto-create folder on topic add. |
| 1.0.1 | 5 | Interactive coach-mark tour on first home visit. Replay from Settings. |
| 1.0.0 | 1-4 | Initial Play Store release. Library, tutorial, batch import, device search, Quick Note (plain text). |

---

## 🐛 Known issues / known limitations

1. **Files deleted on uninstall (Android v1.2.0+)** — by design; scoped storage requirement.
2. **"Find on Device" partial coverage** — works for `/Android/media/com.whatsapp/...` (publicly readable) but NOT for arbitrary `/storage/emulated/0/Download` paths on Android 11+ without SAF. Acceptable tradeoff; documented in tutorial.
3. **GitHub Pages landing page** — requires public repo. If repo flips to private, page 404s and Play/App-Store listings will need a new privacy-policy URL. Migration target: bridgr.co.in or Netlify.
4. **iOS Share Extension not implemented** — receiving shared files from other iOS apps works but only when MedShelf is the chosen target via the share sheet. Full Share Extension target in Xcode is a future enhancement.

---

## 🎯 Pending / Future Work

- Move landing page off GitHub Pages → Cloudflare Pages or bridgr.co.in subdomain
- Make GitHub repo private (after landing page migrated)
- iOS first build via Codemagic (see IOS_RELEASE.md)
- iOS Share Extension target (for receiving files from Mail, Safari, etc.)
- App Store Connect listing setup (copy ready in earlier commits)
- iOS screenshots (5 hero shots — see prior plan)
- Optional v1.3+: voice notes, OCR search inside scans, family/profile switching

---

## 🤖 Working with this codebase (instructions for next Claude/AI)

1. **Always run `flutter analyze lib` after edits** — keep it 0 issues.
2. **Don't reintroduce `MANAGE_EXTERNAL_STORAGE`** — Play Store will reject.
3. **Don't add Firebase back** — was removed for valid reasons (iOS crash + unused).
4. **Don't use deprecated `withOpacity(x)`** — use `withValues(alpha: x)` (Flutter 3.27+).
5. **Never commit `android/key.properties` or `*.jks`** — gitignored, dev-secure.
6. **Bump version on every build that gets uploaded** — even rejected Play uploads burn the code.
7. **For note save flow**: write Delta JSON to file, NOT to `description` field. (See bug fixed in 1.1.2.)
8. **Quill toolbar requires `FlutterQuillLocalizations.delegate`** in `main.dart` MaterialApp.
9. **iOS-specific**: see `IOS_RELEASE.md` for Codemagic setup.

---

## 📞 Contact

- Developer: Dr. Sunil Mulgund
- Email: mulgundsunil@gmail.com
- Bridgr: <https://bridgr.co.in/>
- Repo: <https://github.com/mulgundsunil1918/medshelf> (currently public, may flip to private)
