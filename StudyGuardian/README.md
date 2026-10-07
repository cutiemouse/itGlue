# Study Guardian

A visible, local SwiftUI macOS application for household study-time agreements. The original HTML assessment in the repository is unchanged. All native application code is in this directory.

## Open and run on a Mac

Requires **macOS 14 or later and Xcode 16 or later**. There are no third-party app dependencies, backend services, accounts, or API keys.

1. Open `StudyGuardian.xcodeproj` in Xcode.
2. Select the shared **StudyGuardian** scheme and **My Mac** destination.
3. Press **Run** (⌘R). The app opens its dashboard and adds a shield to the menu bar.
4. Select **Create parent PIN** before giving the Mac to the child. Use 6–12 digits.
5. In **Settings**, select **Allow macOS notifications…** and approve the macOS prompt.
6. Review **Apps** and **Schedule**. The initial schedule is Monday–Friday, 4–9 PM in this Mac's time zone. Strict Mode is off.

Local development uses ad hoc signing without a developer account. For a distributed build, set your own unique bundle identifier, signing team, and Developer ID in Xcode, then sign/notarize it with Apple's normal tools. No signing credentials are included here. Install a signed release at a stable location (typically `/Applications`) before enabling launch at login. macOS may also require Login Items approval.

From a Terminal in this directory:

```sh
./scripts/verify-macos.sh
./scripts/run-macos.sh
```

The first script builds and runs XCTest; the second builds and launches the actual app. Each checks for Xcode and exits with an explanation on Linux. Neither uploads data or changes the source tree.

## Behavior

- **Dashboard:** today's total foreground usage, five category totals, Study Focus Score, and timeline.
- **Activity:** daily per-app totals (app name and bundle identifier, total foreground time, share of daily usage, and time during study hours), with date selection, longest-first/name sorting, local CSV export, and a separate timeline. Repeated sessions are combined by bundle ID and clipped at midnight. The dashboard shows today’s same table; text reports also include app totals. CSV export requires parent unlock and opens in Numbers or Excel.
- **Apps:** bundle-ID based defaults and parent overrides, including manually entered identifiers. Unknown apps never trigger a quit. Game/browser app variants not in the defaults can be categorized here.
- **Schedule:** multiple weekday periods, overnight periods, enable/disable, and removal. Overlapping periods are treated as a union. Start is inclusive; end is exclusive.
- **Reports:** daily summaries, entertainment during study hours, and parent-authorized local text export.
- **Settings:** parent PIN unlock, notifications, Strict Mode, supported launch-at-login registration, retention, and activity deletion.

Safari and Chrome default to **Browser Activity**, alongside STUDY, ENTERTAINMENT, COMMUNICATION, and UNKNOWN. Browser duration is recorded without inspecting tabs or pages. A browser does **not** count as confirmed study unless a parent explicitly overrides its category. The Focus Score is:

`confirmed Study seconds during study hours / all recorded foreground seconds during study hours × 100`

No study-hour usage produces **N/A**, rather than an invented percentage. The score measures app categories, not attention, learning, or actual website use. YouTube and other websites are explicitly unclassified in this MVP.

An entertainment app entering the foreground during study hours triggers the requested warning, then one reminder after **more than five continuous minutes**. Leaving the app or the study period resets the timer. Reminders require macOS notification authorization and can be suppressed by system Focus settings; current warnings also appear in the app and menu. Detection/checkpoint timers run every 15 seconds, so the five-minute reminder can arrive up to roughly 15 seconds later under normal conditions.

Strict Mode requests `NSRunningApplication.terminate()` once per occurrence. This is a normal quit: an app may refuse or present Save/Cancel. There is no force quit, escalation, relaunch suppression, or guarantee of blocking. Unknown, communication, browser, and study apps are never terminated unless explicitly reclassified as entertainment by the parent.

## Local storage and privacy

SwiftData stores usage in `~/Library/Application Support/StudyGuardian/Activity.store`; preferences are in `Preferences.json` in the same private, mode-0700 directory. CloudKit is explicitly disabled. Nothing is uploaded, and the application contains no network client.

Sessions are checkpointed every 15 seconds, on foreground switches, schedule boundaries, and orderly exit. After a crash, the saved endpoint is retained: downtime is not attributed to the last app, and up to one checkpoint interval of usage can be lost. Local retention defaults to 30 days, with 7/30/90/365-day choices. Shortening retention removes old closed sessions on the next monitoring tick. Deleting history clears all sessions and begins a new current session.

Monitoring pauses on workspace sleep/user-session events and observed screen-lock notifications, and resumes when the relevant conditions clear. Wake alone does not resume a still-locked session. macOS screen-lock notification behavior needs testing on the target macOS release. Awake foreground time can include idle time: this MVP does not inspect input events or infer whether a person is paying attention. Time zone or clock changes affect local wall-clock reporting.

The parent PIN is never stored as plaintext. Keychain holds a random 32-byte salt, a PBKDF2-HMAC-SHA256 verifier (210,000 rounds), and failed-attempt backoff metadata. Five failed attempts begin increasing retry delays, up to one hour. An unlock lasts five minutes and is cleared on sleep, screen lock, session resignation, or manual lock. Service methods recheck authorization, including after a report Save dialog. Schedule/category edits are prospective and do not rewrite historical labels.

No Accessibility, Screen Recording, Full Disk Access, Automation, camera, or microphone permissions are requested. No keystrokes, passwords, messages, document contents, screenshots, or browsing content are read. Only ordinary notification authorization and the user's login-item approval are relevant. Export uses a standard local Save panel.

This is **not tamper-proof parental device management**. Closing the window leaves the visible menu-bar app running, but quitting stops tracking. The PIN protects app controls; someone with the same macOS account can quit the app, alter local files, or reset its Keychain item. A separate parent administrator account and child standard account are recommended for OS-level restrictions. Setup must be performed by the parent initially. There is no hidden agent, reinstall mechanism, or remote monitoring.

## Architecture

- `Models`: categories, SwiftData sessions, schedule/preferences.
- `Services`: `ActivityMonitorService`, `AppClassificationService`, `ScheduleService`, `NotificationService`, `ReportService`, `SettingsService`, `PersistenceService`, and `ParentPINService`.
- `ViewModels`: observable application coordinator.
- `Views`: six native screens and parent PIN sheet.
- `Utilities`: pure summary calculations, timing policy, and presentation helpers.

`BrowserDomainClassifying` is a future, explicitly consented domain-classification extension point. No implementation or browser integration is enabled. A future implementation must explain and obtain any new permissions before collecting domains, prefer a consensual browser integration, and continue to avoid page/document contents.

## Validation status

Validated in the Linux cloud environment using the official, signature-verified Swift 6.0.3 toolchain:

- 21 XCTest cases pass: schedule edges, overlapping/overnight schedules, daylight saving, exact delayed boundaries, category overrides, browser exclusion from study, report clipping/score calculation, and initial/reminder/Strict Mode timing policy.
- All application and test Swift files pass syntax parsing in Swift 5 language mode.
- The Xcode project parses, every source reference exists, shared scheme targets resolve, and property lists are valid.

**Native app compilation and launch have not been verified here:** Linux has no Xcode, macOS SDK, AppKit, SwiftUI, or SwiftData runtime. The two additional SwiftData persistence tests are included for macOS and were not run here. Native checks can be run with `scripts/verify-macos.sh`; the GitHub Actions workflow performs them on a macOS runner when pushed or manually dispatched. That workflow has not been run from this cloud task.

Portable tests also run with `swift test` from this directory, independently of the Xcode app. They deliberately do not pretend to validate macOS UI, permissions, tracking notifications, persistence, login items, or process termination.

## Mac acceptance checks

1. Run the app, switch between Preview, Safari, and a communication app, and wait one checkpoint per app. Confirm identifiers, durations, Browser Activity, timeline, and category totals; relaunch and confirm persistence.
2. Create a study period covering the current time. Temporarily override **Calculator** as Entertainment. Enable notifications, open Calculator, and verify the first warning and the reminder after more than five minutes. Switch away and return to verify a fresh occurrence.
3. Enable Strict Mode with Calculator as Entertainment and confirm a normal quit request. Disable it afterward. Do not use unsaved documents as test targets.
4. Lock/unlock, sleep/wake, and fast-user-switch. Confirm suspended time is not recorded and parent controls relock. Check that waking while locked stays paused.
5. Check midnight and study-start/end boundaries. Change a category/schedule and verify only subsequent sessions use the new labels.
6. Confirm incorrect PIN attempts, retry backoff, five-minute expiry, protected settings and export, report output, and retention. Test deletion only with disposable history.
7. Install the app in Applications, enable login launch, approve it if macOS requests, and log out/in. Confirm the shield and tracking resume. Disable the setting and verify removal.
8. Deny notification permission and confirm the visible warning still appears without a crash. Confirm the app never asks for sensitive permissions.
