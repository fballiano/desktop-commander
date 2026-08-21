# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

`desktop-commander` is a macOS menu bar application. It does two things:

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

**The permission breaks at every update.** The application is signed ad hoc, so
its signature changes with every build. macOS ties an Accessibility grant to that
signature, so after an update the user must remove the application from the list
in System Settings and add it again. There is no way around this without an Apple
Developer ID. Say so in the README and in the Settings window; do not pretend it
does not happen.

## Icons

The application icon and the menu bar icon are the same Tabler `adjustments`
outline at stroke width 2: three sliders. The path exists twice, because the icon
script runs outside the application and cannot import its code: in
`Sources/DesktopCommander/Views/CommanderGlyph.swift` and in
`Tools/make-icon.swift`. Change the two together.

The menu bar has two images. `menuBar` is the plain outline. `menuBarActive`
fills the three knobs and appears while any switch is on, so a Mac that never
sleeps or a desktop with no icons is never a surprise.

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

## Releases

`.github/workflows/release.yml` publishes a release. A tag that starts with `v`
starts it:

```bash
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

The workflow runs the tests, calls `make dmg`, and attaches the disk image to a
new GitHub release. The last step then writes the version into `project.yml` and
into `DesktopCommander.xcodeproj/project.pbxproj`. Do not edit the
`MARKETING_VERSION` lines by hand.

## Homebrew

This repository is also the Homebrew tap. The cask is
`Casks/desktop-commander.rb`. The name of the repository has no `homebrew-`
prefix, so the tap command needs the URL:

```bash
brew tap fballiano/desktop-commander https://github.com/fballiano/desktop-commander
brew trust --cask fballiano/desktop-commander/desktop-commander
brew install --cask desktop-commander
```

The release workflow writes the new `version` and `sha256` into the cask and
pushes the change to the default branch. Do not edit the two lines by hand.

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
| Menu | `Views/MenuContent.swift` |
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
- `Notifier` does not ask for notification permission.
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
- The bundle identifier is `com.fabrizioballiano.desktop-commander`. The product
  name is `desktop-commander`. The module name is `DesktopCommander`.
