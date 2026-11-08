# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

Deskyard is a macOS menu bar application. It does two things:

1. **Switches** that change the state of the Mac: keep awake, hide the desktop
   widgets, hide the desktop icons, show the hidden files, hide the windows, lock
   the keyboard, start the screen saver, clean the screen.
2. **Window management**: fifteen places for the front window, a move to the next
   display, and an undo.

The application is an agent application (`LSUIElement: true`). It has no dock
icon and no ordinary windows. It is not sandboxed, because it writes the settings
of other applications and drives the windows of other applications.

## Commands

```bash
make build       # build the Release app into ./build
make debug       # build the Debug app into ./build
make test        # run the unit tests
make run         # build, then launch the app
make install     # copy the app into /Applications
make dmg         # build the Release app and pack it into ./dist/*.dmg
make package     # pack the Release app that is already built into ./dist/*.dmg
make generate    # rebuild DesktopCommander.xcodeproj from project.yml (needs xcodegen)
make clean       # remove ./build and ./dist
```

To run one test suite or one test:

```bash
xcodebuild -project DesktopCommander.xcodeproj -scheme DesktopCommander \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -parallel-testing-enabled NO \
  -only-testing:DesktopCommanderTests/WindowSlot test
```

Parallel testing must stay off. The test bundle loads into the real application,
so a parallel run launches one copy of the application for each test worker.

## The two permissions

**Accessibility.** Two features need it: every window command, and the keyboard
lock. Nothing else does.

Never ask for it at launch. `AppModel.requestAccessibility()` asks at the first
window command, and `KeyboardLock.lock()` asks when the lock starts. A user who
only wants the switches must never see a permission sheet.

**The permission survives an update.** Releases are signed with a Developer ID
(see Releases), and macOS ties an Accessibility grant to the team and the bundle
identifier, not to one build. The update from 1.3.0 or earlier, which were signed
ad hoc, needs the grant once more: the README and the Settings window say how.
A local build is still signed ad hoc, so a grant to a local build breaks at every
build.

**Two copies with one bundle identifier is the trap.** Every copy of this
application carries `com.fabrizioballiano.desktop-commander`, so:

- `open /Applications/Deskyard.app` does **not** launch that copy while
  another one is running. macOS only brings the running one forward. Use
  `open -n`, which is what `make run` does.
- `make test` used to leave the Debug test host running for the rest of the day.
  A user then clicked the menu bar icon of the Debug build, granted the
  permission to that binary, and the installed copy stayed untrusted. `make test`
  now stops the copies under `./build`, and only those.
- `brew install --cask` refuses to move its app into `/Applications` when
  something is already there. It leaves the app in the Caskroom and says so in a
  line that is easy to miss. `make install` and the cask must never both own that
  path.
- A copy from 1.3.1 or earlier has the name `desktop-commander.app` and the same
  bundle identifier. `make install` and `make uninstall` remove it too.

To put it right: `pkill -f Deskyard`, then
`tccutil reset Accessibility com.fabrizioballiano.desktop-commander`, then launch
one copy and grant the permission again.

## Icons

The application icon and the menu bar icon are the same Tabler `adjustments`
outline: three sliders. The path exists twice, because the icon script runs
outside the application and cannot import its code: in
`Sources/DesktopCommander/Views/CommanderGlyph.swift` and in
`Tools/make-icon.swift`. Change the two together.

The menu bar has one image, and the state of the switches does not change it.
A second image with the three knobs filled used to say "a switch is on". A knob
is 9 Retina pixels wide with a hole of 3, so filling it makes a solid disc, and
a Mac that keeps its widgets hidden then carried three blobs all day beside two
outline icons. Do not bring it back in that form. The menu says which switch is
on, and it says which one.

**The menu bar does not use Tabler's own measurements, and it must not.**
thyme-ng and clipboard-controller draw their Tabler outline into a box of 20
points and take the stroke of 1.67 points that comes out. That works for them
and not for this glyph. A stroke of 1.67 points is 3.3 Retina pixels, so where
the line falls decides everything:

| Glyph | The line sits at grid | In Retina pixels | The stroke covers |
| --- | --- | --- | --- |
| The two sides of the clipboard | 5 and 19 | 8.3 and 31.7 | three whole, one grey |
| The three rails of this glyph | 6, 12 and 18 | 10, 20 and 30 | two whole, two grey |

A rail lands on a whole pixel, which is the worst place for a stroke of 3.3
pixels: it straddles the middle and spreads both ways. Six thin rails, each one
two pixels of ink between two grey, and three rings whose hole of two pixels
washes out into a blob. The icon then reads as thinner and dirtier than the
icons beside it, and the knobs look filled when they are not.

`MenuBarLayout` in `CommanderGlyph.swift` therefore holds its own measurements,
in points: a rail every 5.5 points, a stroke of 1.5 points, a knob radius of 1.5
points. `menuBarOrigin()` then moves the glyph by up to a quarter of a point, so
each rail sits in the middle of a Retina pixel and fills three whole pixels: the
weight of the neighbours, with 16% grey ink instead of 37%. Keep this separate
from the application icon, which is large and needs none of it.

The application icon is an Icon Composer document, `Resources/AppIcon.icon`:

| File | What it is |
| --- | --- |
| `icon.json` | Written by hand. It holds the colours of the two appearances. |
| `Assets/adjustments.svg` | Written by `Tools/make-icon.swift`. |
| `Docs/icon-light.png`, `Docs/icon-dark.png` | The previews for the README. |

Run `swift Tools/make-icon.swift` after any change of the path. The script turns
the stroke into a filled outline, because a layer of a `.icon` is filled and Icon
Composer colours it per appearance.

`project.yml` needs `options.fileTypes.icon.file: true`. Without it XcodeGen adds
the files inside the document one by one and the icon never reaches `actool`.

## The languages

`Resources/Localizable.xcstrings` is a String Catalog. It holds every string of
the interface in six languages: English, which is the source, then French,
German, Italian, Portuguese (Brazil) and Spanish. The build turns it into one
`Localizable.strings` for each language inside the application.

The key is the English text, so a string that needs no explanation reads as
itself in the code. Five long paragraphs and one alert message carry a key of
their own instead, such as `settings.windows.permissionFooter`, because a key of
two hundred words is not a key.

Three rules:

- A SwiftUI `Text("…")`, `Toggle("…")`, `Section("…")` or `Label("…")` with a
  literal is translated by SwiftUI itself. Nothing else is. Every other string
  needs `String(localized:)`: an `NSMenuItem` title, an `NSAlert`, a window
  title, a string a type gives back.
- A `String` that is already translated must never go back through
  `LocalizedStringKey`. `Text(duration.title)` takes the `String` overload and
  shows the text as it is, which is right. `Text("\(duration.title)")` would look
  the translated text up again and find nothing.
- A list of titles is a computed property, never a stored one. A stored property
  reads the language once and keeps it. `WindowSlot.groups` and
  `KeyboardShortcuts.Name.switchNames` were stored before and are not now.

`LocalizationTests` reads the built application, not the catalogue. It checks
that the six languages are there, that each one holds every key, and that no
translation is still the English text. A new string that reaches only the
English side fails the third test. A word that is the same in every language,
such as "Layout", goes into `sameInEveryLanguage`.

The catalogue is written by hand. `SWIFT_EMIT_LOC_STRINGS` is off, so no build
adds an entry to it and no build changes the file.

Two things stay in English, and both on purpose:

- `Resources/desktop-commander.sdef`. The words of an AppleScript command are
  the command, so `arrange window "leftHalf"` must read the same on every Mac.
- The Siri phrases of `DesktopCommanderShortcuts`. A phrase holds
  `\(.applicationName)`, and the name of the application does not change.

## Releases

`.github/workflows/release.yml` publishes a release. A tag that starts with `v`
starts it:

```bash
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

The workflow runs the tests, calls `make dmg`, and attaches the disk image
`Deskyard-<version>.dmg` to a new GitHub release. Then it writes the version into
`project.yml` and into `DesktopCommander.xcodeproj/project.pbxproj`, and updates
the cask in the tap (see Homebrew). Do not edit the `MARKETING_VERSION` lines by
hand.

A release is signed with the Developer ID certificate and notarized by Apple.
The workflow passes the signing settings to `make build` through `XCODE_FLAGS`,
notarizes the app with `Tools/notarize.sh`, packs the stapled app with
`make package`, and then signs and notarizes the disk image too. `make dmg`
would build again, and a second build can sign the app again and drop its
ticket. Local builds stay signed ad hoc and need no certificate.

The variable and the six secrets that the workflow needs are listed at the top
of `release.yml`. A manual run with "dry run" on (the default) signs and
notarizes, keeps the disk image as an artifact, and publishes nothing.

## Homebrew

The cask lives in the shared tap `fballiano/homebrew-tap`, as
`Casks/deskyard.rb`:

```bash
brew tap fballiano/tap
brew trust --tap fballiano/tap
brew install --cask deskyard
```

The release workflow writes the new `version` and `sha256` into that cask and
pushes the change to the tap. It uses the deploy key in the secret
`TAP_DEPLOY_KEY`, which can write to the tap only. Do not edit the two lines by
hand.

Until 1.3.1, this repository was its own tap, `fballiano/desktop-commander`.
It has no cask now. A user of the old tap moves with the commands in the README.

A local tap clone made before a release still holds the old checksum, so
`brew update` comes before `brew upgrade`.

## Project file

`DesktopCommander.xcodeproj` is generated from `project.yml` by XcodeGen, but it
is committed. Change `project.yml` and run `make generate` for any change of the
project layout. Do not edit `project.pbxproj` by hand.

## Architecture

`AppModel` is the one controller, a `@MainActor @Observable` singleton
(`AppModel.shared`). Every way into the application calls the same method on it:

| Entry point | File |
| --- | --- |
| Menu | `Views/CommanderMenu.swift` |
| Global hot key | `HotKeys.swift`, wired in `AppModel.registerHotKeys()` |
| AppleScript | `Scripting/ScriptCommands.swift` with `Resources/desktop-commander.sdef` |
| Shortcuts and Spotlight | `Scripting/CommanderIntents.swift` |

Keep this rule. A new command needs one method on `AppModel`, then a call from
each entry point. Do not put logic in a view, a script command or an intent.

### The window management, in three parts

The three know nothing about each other, which is why each one is tested on its
own:

| Part | What it does | Touches the system |
| --- | --- | --- |
| `Windows/WindowSlot.swift` | Where a window goes, as maths on a rectangle. | no |
| `Windows/ScreenGeometry.swift` | AppKit coordinates to Accessibility coordinates, and which screen holds a window. | no |
| `Windows/FocusedWindow.swift` | Reads and writes the front window, through the Accessibility API. | yes |

`Windows/WindowMover.swift` joins them.

**The y axis is the trap.** AppKit puts the origin at the bottom left of the
primary screen with y going up. The Accessibility API puts it at the top left of
the primary screen with y going down. The flip needs the top edge of the
**primary** screen, not of the screen the window is on. A sign error here throws
a window off the display, so the conversion is a function with its own tests.

`WindowMover` rounds the frame with `.integral` before it writes. A third of a
screen is not a whole number of points.

### The menu is AppKit, not SwiftUI

`Views/CommanderMenu.swift` builds an `NSMenu`, and `AppDelegate` in
`DesktopCommanderApp.swift` puts it on an `NSStatusItem`. `MenuBarExtra` and
`MenuContent` did this before. One row is the reason.

"Keep awake" needs two things at once: the checkmark in the same column as the
switches under it, and a submenu of lengths. A SwiftUI row that opens a submenu
has no state gutter, so the image of a `Label` lands inside the title and draws
a second column of checkmarks beside the `Toggle` rows. An `NSMenuItem` holds a
state and a submenu together.

Two things follow from AppKit:

- A click on a row that has a submenu opens the submenu. AppKit runs no action
  for it, so the submenu of "Keep awake" carries an "Off" row. `primaryAction`
  of a SwiftUI `Menu` did nothing here either.
- The menu is built again from nothing each time it opens, and a timer of one
  second updates the countdown while it stays open. The timer goes into the
  common run loop modes, because a menu tracks the mouse in its own mode.

The menu bar image is still `CommanderGlyph.menuBar`, unchanged.

### The switches

Each switch is a small type that `AppModel` owns. Each one takes the system call
it needs as a closure or behind a protocol, so a test drives it without changing
the Mac:

| Switch | How it is testable |
| --- | --- |
| `KeepAwake` | The two IOKit calls come in as closures. |
| `DefaultsSwitch` | An injected `UserDefaults` and an injected restart. |
| `HiddenWindows` | A list of `HideableApplication`, which the tests fake. |
| `KeyboardLock` | The key matching is `nonisolated static` and pure. The tap itself is not unit tested. |

`DefaultsSwitch` writes the settings of the system, not a copy of its own. Two
copies of one truth always fall out of step: the user can change the same thing
in System Settings or in Finder. `AppModel.refreshSwitches()` reads the truth
again each time the menu opens.

`DefaultsSwitch.isInverted` holds the one place where the menu and the key
disagree: "Hide the desktop icons" is on when `CreateDesktop` is `false`.

### The keyboard lock

A `CGEventTap` is the only way to swallow a key before an application sees it.
Three rules that must not be lost:

1. The callback is a C function pointer. A `CGEvent` is not `Sendable`, so only
   plain numbers cross into the main actor: the kind of the event, the key and
   the modifiers.
2. Command, Option and Escape are **never** swallowed, so Force Quit always
   works. It is the way out that does not need this application to be working.
3. A timer ends the lock whatever happens.

### No notifications

The application posts none, so it never asks for the notification permission.
Do not add one. Three of the four it used to post said what the user could
already see, and the two that carried real information now live somewhere better:

- The keys that end the keyboard lock are in the menu row itself, so the user
  reads them at the moment they turn the lock on.
- The missing Accessibility permission is an `NSAlert` with a button that opens
  the pane. A banner carries no button, and macOS shows its own permission sheet
  at most once for each launch, so without the alert a second hot key would do
  nothing at all and look broken.

### Write a default once

Two settings are written at the first launch and never again:
`appliedDefaultLoginItem` and `appliedDefaultShortcuts`. Never write a default
without its flag: the application would set the value back at every launch, and a
user who changed it could never keep the change.

### Test host

The tests load into the real application, so the application launches during a
test run. `RuntimeEnvironment.isRunningTests` guards the side effects:

- `AppModel.bootstrap()` does nothing, so no hot keys and no login item.
- `KeepAwake.systemTake` takes no assertion.
- `DefaultsSwitch.restartFinder` does not end Finder.
- `KeyboardLock` never creates a tap, and `Accessibility.request()` never asks.
- `ScreenSaver` and `ScreenCleaning` do nothing.
- `Accessibility.showAlert()` shows nothing.
- `LoginItem` does not call `SMAppService`.

Add the same guard to any new code that touches the system.

## Conventions

- Swift 6 with `SWIFT_STRICT_CONCURRENCY: complete`. Almost every type is
  `@MainActor`. Callbacks from AppKit, from CoreGraphics and from
  `KeyboardShortcuts` use `MainActor.assumeIsolated`.
- A pure helper inside a `@MainActor` type is `nonisolated`, so a test and a C
  callback can both reach it.
- Tests use Swift Testing (`@Suite`, `@Test`, `#expect`), not XCTest. Compare a
  third of a screen with a tolerance, never with `==`.
- `WindowSlot.caseDisplayRepresentations` in `Scripting/CommanderIntents.swift`
  is written out case by case, because the App Intents metadata tool reads it at
  build time and refuses a loop. A test checks that it holds every case.
- The product name is `Deskyard`, so the application is `Deskyard.app`. The
  bundle identifier is `com.fabrizioballiano.desktop-commander`, and the module
  name is `DesktopCommander`.
- The application had the name desktop-commander up to 1.3.1. The bundle
  identifier keeps the old name on purpose: macOS keys the Accessibility
  permission and the settings by it, so a change would lose both. The module
  name, the project, the scheme, the source folders, the `.sdef` file and the
  type names keep the old name too. They are internal, and the tests and the
  App Intents depend on the module name.
