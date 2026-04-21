# TabWatch

A tiny Apple Watch app for keeping a running tab when a bartender forgets how
many beers, AMFs, or Jacks you've ordered. Tap a drink to count it; the app
totals the bill as you go.

## What it does

- **Home screen** — today's date, list of open tabs, "Add Tab +" to start a
  new one.
- **New Tab** — type a name, tap Add.
- **Tab detail** — a row of drink counters (Bottle / Beer / Wine). Each one is
  a big plus button when the count is 0, and expands to a `+ / number / icon /
  -` capsule once you start counting. Running total ($) shown at the top.
- **Close Out** — finishes the tab and removes it from the list. **Delete**
  throws it away without closing.

## Project layout

Source lives in `TabWatch Watch App/`. The Xcode project is generated from
`project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the
`.xcodeproj` doesn't need to be checked in.

```
TabWatch Watch App/
├── TabWatchApp.swift          # @main entry point
├── ContentView.swift          # Root navigation
├── Models/
│   ├── DrinkKind.swift        # Bottle / Beer / Wine + prices
│   ├── Tab.swift              # One customer tab
│   └── TabStore.swift         # Persistence via UserDefaults (JSON)
└── Views/
    ├── TabListView.swift      # Home screen
    ├── NewTabView.swift       # Name entry
    ├── TabDetailView.swift    # Counters + Close Out + Delete
    └── DrinkCounterView.swift # Single drink capsule
```

## Building

You need macOS with Xcode 15+ (for watchOS 10 SDK). Then:

```sh
brew install xcodegen          # one-time
xcodegen generate              # produces TabWatch.xcodeproj
open TabWatch.xcodeproj
```

In Xcode, select the **TabWatch Watch App** scheme and run it on a watchOS
simulator or a paired Apple Watch.

## Customizing prices

Drink prices live in `Models/DrinkKind.swift` as defaults. The store persists
any edits made at runtime (see `TabStore.prices`), so you can extend the UI to
edit them later without touching the model.
