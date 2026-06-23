# Simple Diary

A private, local-first diary for macOS, built with SwiftUI as a single-window app.
There is a companion iOS app and a landing site. English is the project's primary
language (UI strings aside); see [Conventions](#conventions).

```
┌────────────┬──────────────────┐
│  calendar   │                  │
├────────────┤   editor (today)  │
│  recent     │                  │
│  (locked)   │                  │
└────────────┴──────────────────┘
```

## Features

- **Write instantly** — launching the app opens today's entry in the right-hand editor
  (auto-focused). Typing autosaves on a 0.6s debounce. One entry per day. From any other
  day, return to today with ⌘N or the "Today" button.
- **Grass calendar** — the month calendar (top-left) marks days you wrote, GitHub-grass
  style, in four shades by length (100 / 300 / 700 char thresholds). ◀ ▶ change month,
  click the month title to jump back to the current month. Click a day to open it in the
  editor (past entries require Touch ID).
- **Locked past entries** — the recent-entries list (bottom-left) is locked by default.
  "Show" requires **Touch ID** (falls back to the Mac login password if fingerprint is
  unavailable). The unlocked state is never persisted, so it re-locks on every launch.
- **Todos** — jot todos in the right-hand column (macOS) or the checklist button (iOS).
  Edit inline (macOS: double-click; iOS: tap the row). Unfinished items **carry over to today**
  when the day changes (shown with a ↳ badge); items completed on a past day are cleared.
  Stored as `todos.json` in the diary folder, so it **syncs across devices via iCloud** and is
  shared between the Mac and iOS apps. (Earlier builds kept it local in Application Support;
  that file is migrated into the diary folder on first launch.)
- **Export** — export all entries to a single Markdown / plain-text / JSON file via the
  toolbar share button or File menu (⌘E = Markdown).
- **Color themes** — Settings (⌘,) offers 7 themes: **Claude (default, terracotta
  #D97757)**, Leaf, Tangerine, Ocean, Lavender, Sakura, Graphite. Grass, highlights,
  buttons and the caret all follow. On iOS, change it at the bottom of the calendar sheet.
- **Daily auto-open** — enable it in Settings (⌘,) to have the app open at a set time each
  day. It runs as a launchd login agent (`~/Library/LaunchAgents/com.hanbin.ilgi.autoopen.plist`),
  survives reboots, and a missed time (Mac asleep) fires on wake. Disabling removes the agent.
- **Day One import** — File menu → "Import from Day One…" converts a Day One JSON export
  (or a ZIP containing one) into entries.
  - Buckets each entry by its time-zone-local date (entries written past midnight land on
    the right day).
  - Merges multiple entries on one day into a single file with `[21:09]` time labels.
  - Restores Day One's Markdown escaping (`\.` etc.); photo/video attachments become a
    `(사진)`-style placeholder.
  - Skips days that already have an entry, so it's safe to run repeatedly. Backs up existing
    entries to `Simple Diary/backup/` before running.

## Build & run

```sh
./build.sh
open "build/Simple Diary.app"
```

Builds with Command Line Tools only — no Xcode required. To install into Applications:

```sh
cp -R "build/Simple Diary.app" /Applications/
```

A desktop shortcut (symlink) that survives rebuilds:

```sh
ln -sfn "$(pwd)/build/Simple Diary.app" "$HOME/Desktop/Simple Diary.app"
```

The app icon (terracotta leaf) is drawn by `scripts/make_icon.swift` during the build.
After changing the design, delete `build/AppIcon.icns` and rebuild to pick it up.

## Shortcuts

| Key | Action |
|---|---|
| ⌘N | Jump to today's entry |
| ⌘E | Export as Markdown |
| ⌘Q | Quit (closing the window also quits) |

## Data

By default, entries are stored in the `Simple Diary` folder on iCloud Drive
(Finder → iCloud Drive → Simple Diary):

```
~/Library/Mobile Documents/com~apple~CloudDocs/Simple Diary/entries/2026-06-12.md
```

They are dated plain-Markdown files — readable without the app and synced across your
devices by iCloud Drive.

- **Change the folder** — Settings (⌘,) → Storage location → "Change folder…" lets you pick
  any folder (`.md` files are written directly there). "Reset to default (iCloud)" restores
  it. Changing folders moves existing entries along.
- **Default / fallback** — unset means iCloud Drive's `Simple Diary/entries`. On a Mac with
  iCloud Drive off it falls back to `~/Library/Application Support/Simple Diary/entries/`.
- **Auto-migration** — entries found in the old `Ilgi` folder (iCloud or local) are moved to
  the new `Simple Diary` folder on first launch.

- The Touch ID lock guards **viewing inside the app**. The files themselves are visible in
  Finder / iCloud Drive, so the real perimeter is your Mac's lock and iCloud account security.
- Editing the same day on two devices at once can make iCloud create a conflict copy like
  "2026-06-12 2.md"; the app ignores filenames that aren't the date format (read them in Finder).
- Clearing an entry and leaving the day (or quitting) deletes that day's file. Right-click →
  Delete in the list also works.

For dev/testing, override the storage location with the `ILGI_DATA_DIR` env var:

```sh
ILGI_DATA_DIR=/tmp/ilgi-test ./build/Simple\ Diary.app/Contents/MacOS/Ilgi
```

## Layout

```
Sources/Ilgi/
  IlgiApp.swift        App entry point, menu commands, Settings scene, save-flush on quit
  DiaryStore.swift     File store (load / debounced save / delete / export / import / folder)
  DayOneImporter.swift Day One JSON/ZIP → dated .md conversion (pure logic)
  BiometricGate.swift  Touch ID / Face ID authentication gate
  AutoOpenAgent.swift  launchd login-agent management for daily auto-open
  ContentView.swift    Left/right split container + toolbar
  SidebarView.swift    Left: calendar + locked recent-entries list
  CalendarView.swift   Grass-style month calendar
  EditorView.swift     Right: always-on editor (autosave, char count)
  SettingsView.swift   Settings (⌘,): theme, storage location, auto-open
  TodoStore.swift      Rolling todo list (todos.json in the diary folder)
  TodoColumn.swift     Right-hand todo column UI
  TodoModel.swift      TodoItem + carry-over logic (shared with iOS)
  Formatters.swift     Date formatters (shared with iOS)
  Theme.swift          Color themes + swatch picker (shared with iOS)
scripts/
  make_icon.swift      App icon renderer (run automatically by build.sh)
  make_dmg_bg.swift    DMG install-window background renderer
  dmg_settings.py      dmgbuild layout config
packaging/Info.plist   App bundle metadata
build.sh               swift build → .app bundle → icon → sign
make_dmg.sh            Build the distributable DMG (site/SimpleDiary.dmg)
site/                  Landing page (static, deployed to Vercel)
ios/                   iOS companion app (XcodeGen)
```

## iOS app (ios/)

An iPhone app that reads and writes the **same iCloud Drive folder** as the Mac app, with
the same grass calendar, a Face ID lock, and the same carrying-over todos (checklist button →
todo sheet, backed by the shared `todos.json`). Because of the iOS sandbox, on first launch you
connect the folder once in-app via "Connect iCloud folder" by picking `iCloud Drive → Simple Diary`
(remembered as a security-scoped bookmark; an `entries` subfolder is auto-detected). File
access uses NSFileCoordinator.

Build (full Xcode required; project generated with XcodeGen):

```sh
cd ios
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project IlgiMobile.xcodeproj -scheme IlgiMobile \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Install on an iPhone:

1. Connect the iPhone (USB) → "Trust This Computer" → Settings → Privacy & Security →
   enable **Developer Mode** and reboot.
2. `open ios/IlgiMobile.xcodeproj` → Xcode Settings → Accounts → add your Apple ID.
3. Target IlgiMobile → Signing & Capabilities → set Team to your Personal Team.
4. Pick your iPhone in the device menu → ▶ Run.
5. On the iPhone: Settings → General → VPN & Device Management → **Trust** the developer app.
6. A free Apple ID signature **expires after 7 days** — just Run again from Xcode to
   reinstall (entries live in iCloud, so data is safe).

Simulator testing: launch with `SIMCTL_CHILD_ILGI_USE_LOCAL=1` to use the local Documents
folder instead of iCloud.

## Landing site

**https://ilgi-diary.vercel.app** — the static landing page in `site/` is deployed to the
Vercel project `ilgi-diary`. The download DMG and icons are copied from build artifacts:

```sh
# rebuild the app, then regenerate the distributable DMG (site/SimpleDiary.dmg)
./build.sh && ./make_dmg.sh

# local preview
python3 -m http.server 4173 --directory site

# deploy to Vercel (vercel login required once)
cd site && vercel deploy --prod --yes
```

> The distributable is a `.dmg` (drag-to-Applications). It is not Apple-notarized, so Chrome's
> "uncommon file" warning and the macOS Gatekeeper warning may appear — removing them entirely
> requires Apple Developer ($99/yr) notarization. Until then, recipients click Keep in Chrome
> and right-click → Open on first launch.
>
> `site/SimpleDiary.dmg` is a build artifact and is git-ignored; deploys upload the local file
> via the Vercel CLI. If you switch to Vercel's GitHub auto-deploy, host the DMG via GitHub
> Releases instead.

## Conventions

- **English first.** All repository artifacts — README, code comments, commit messages, PR
  descriptions — are written in English. (User-facing app UI strings are Korean by product
  choice; that is the one exception.)

## Repository

https://github.com/hanbin8269/simple-diary

The project code name and data folder / bundle ID stay as `ilgi` / `com.hanbin.ilgi`; the
product name is **Simple Diary** (English only, no Korean name).
