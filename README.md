# TabWatch

A tiny Apple Watch app for keeping a running tab when a bartender forgets how
many beers, AMFs, or Jacks you've ordered. Tap a drink to count it; the app
totals the bill as you go.

## What it does

- **Home screen** — today's date, running "Today: $X.XX" from closed tabs,
  list of open tabs, "Add Tab +" to start a new one, and a gear icon in the
  top-right for Settings.
- **Add Tab** — one tap. The app auto-numbers ("Tab 1", "Tab 2", ...) and
  jumps straight into the counter screen. Numbers get recycled as tabs
  close out, so a busy shift stays at "Tab 1"–"Tab 8" instead of climbing
  into the hundreds.
- **Rename** — pencil icon in the top-right of the tab detail. Opens a
  text entry for a name like "Heather B" or "Red shirt, seat 4". Optional —
  skip it if you don't care.
- **Tab detail** — a row of drink counters (Bottle / Beer / Wine). Each one is
  a big plus button when the count is 0, and expands to a `+ / number / icon /
  -` capsule once you start counting. Running total ($) shown at the top.
  Tap `+` / `-` for a haptic click.
- **Close Out** (green) — finishes the tab, records its total into today's
  sales, plays a success haptic, and pops back.
- **Delete** (orange outline) — throws the tab away without recording it.
  Use this for mistakes.
- **Settings** — per-drink price Stepper (digital crown), today's sales
  summary, and a "Reset Today" button. Prices otherwise persist across
  sessions.
- **Daily rollover** — the "Today" total resets automatically when the
  calendar day changes.

## Project layout

Source lives in `TabWatch Watch App/`. The Xcode project is generated from
`project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the
`.xcodeproj` doesn't need to be checked in.

```
TabWatch Watch App/
├── TabWatchApp.swift          # @main entry point
├── ContentView.swift          # Root NavigationStack
├── Haptics.swift              # WKInterfaceDevice wrapper
├── Models/
│   ├── DrinkKind.swift        # Bottle / Beer / Wine + default prices
│   ├── Tab.swift              # One customer tab
│   └── TabStore.swift         # Tabs, prices, today's-sales rollup
└── Views/
    ├── TabListView.swift      # Home screen + Route enum + NavigationStack
    ├── TabDetailView.swift    # Counters + Close Out + Delete + rename button
    ├── RenameTabView.swift    # Optional name entry for a tab
    ├── DrinkCounterView.swift # Single drink capsule
    └── SettingsView.swift     # Price editor + Today summary
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

Open **Settings** from the gear icon in the top-right of the home screen.
Each drink has a Stepper — turn the digital crown or tap `+` / `-` to change
the price in $0.25 increments. Defaults live in `Models/DrinkKind.swift`.

## Known gaps

- Only aggregate sales for today are tracked — there's no per-tab history of
  who bought what after Close Out.
- Drink kinds are hard-coded to Bottle / Beer / Wine. Adding Cocktail / Shot
  for AMFs and Jacks is straightforward (add cases to `DrinkKind`), but may
  need a layout rethink if more than ~4 drinks are visible at once on the
  smallest watch.
- App icon is an empty placeholder asset. Drop a 1024×1024 PNG into
  `Assets.xcassets/AppIcon.appiconset/` and reference it in `Contents.json`.
