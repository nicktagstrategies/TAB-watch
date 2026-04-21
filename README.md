# TabWatch

A tiny Apple Watch app for keeping a running tab when a bartender forgets how
many beers, AMFs, or Jacks you've ordered. Tap a drink to count it; the app
totals the bill as you go.

## What it does

- **Home screen** — today's date, running "Today: $X.XX" from closed tabs,
  list of open tabs, "Add Tab +" to start a new one, and a gear icon in the
  top-right for Settings. A transient "Undo" capsule shows up for 30 s
  after a Close Out or Delete in case the tap was a mistake.
- **Add Tab** — one tap. The app auto-numbers ("Tab 1", "Tab 2", ...) and
  jumps straight into the counter screen. Numbers get recycled as tabs
  close out, so a busy shift stays at "Tab 1"–"Tab 8" instead of climbing
  into the hundreds.
- **Rename** — pencil icon in the top-right of the tab detail. Opens a
  text entry for a name like "Heather B" or "Red shirt, seat 4". Optional —
  skip it if you don't care.
- **Tab detail** — a row of drink-counter capsules, one per configured
  drink. Each is a big plus button when count == 0, and expands to a `+ /
  number / icon / -` capsule once you start counting. Running total ($)
  sits at the top. Tap `+` / `-` for a haptic click. The **Digital Crown**
  increments/decrements the most-recently-tapped drink (shown with an
  accent ring) for fast "buying a round" entry without tapping.
- **Close Out** (green) — finishes the tab, adds the tax-inclusive total
  to Today's sales, plays a success haptic, and pops back. Undoable for
  30 s.
- **Split** (white outline, only when drinks are counted) — pushes into a
  Stepper-per-drink screen to move some of the counts onto a new
  auto-numbered tab. New tab inherits the source's locked prices.
- **Delete** (orange outline) — two-step confirm with two options:
  **Walker (unpaid)** logs the would-have-been amount to today's "Lost"
  bucket for shift reconciliation; **Discard** just throws the tab away.
  Both are undoable for 30 s.
- **Per-tab price lock** — each tab snapshots current drink prices at
  creation. Changing a price in Settings afterwards only affects new
  tabs — open tabs stay at the price their customer was quoted.
- **Settings — Drinks** — a list of drink kinds. Tap a row to edit the
  name, icon (from a fixed palette of 6 SF Symbols), and price. Swipe
  left to delete. "Add Drink" appends a new slot (capped at 4). Ships
  with **Beer / Shot / Cocktail** as defaults.
- **Settings — Tax** — Stepper in 0.125% steps (0–15%). When > 0, the
  tab detail shows a tax-inclusive total with a `$24.50 + $2.02 tax`
  caption; when 0%, prices are quoted as-entered.
- **Settings — Shift** — configurable "Day starts" hour (0–12, default
  **4 AM**). The "Today" total rolls over at this hour, not calendar
  midnight, so a close-out at 1:30 AM still counts toward the prior
  shift.
- **Settings — Today** — running sales + tabs-closed count, plus a
  "Walkers" row when any unpaid tabs were marked that day. "Reset Today"
  has a confirmation so a pocket tap can't wipe the shift total.

## Project layout

Source lives in `TabWatch Watch App/`. The Xcode project is generated from
`project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the
`.xcodeproj` doesn't need to be checked in.

```
TabWatch Watch App/
├── TabWatchApp.swift          # @main + scenePhase observer
├── ContentView.swift          # Hosts TabListView
├── Haptics.swift              # WKInterfaceDevice wrapper
├── Models/
│   ├── DrinkKind.swift        # struct { id, name, symbol, price } + SF Symbol palette
│   ├── Tab.swift              # One customer tab; counts keyed by drink UUID
│   └── TabStore.swift         # Tabs, drinks, sales, tax, shift, undo
└── Views/
    ├── TabListView.swift      # Home screen + Route enum + UndoBanner
    ├── TabDetailView.swift    # Counters + Close Out + Split + Delete + crown
    ├── RenameTabView.swift    # Optional name entry for a tab
    ├── SplitTabView.swift     # Per-drink Stepper to split off a new tab
    ├── DrinkCounterView.swift # Single drink capsule + active ring
    ├── EditDrinkView.swift    # Name / icon / price editor for one drink
    └── SettingsView.swift     # Drinks list, Tax, Shift, Today, confirms
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

## Customizing drinks

Open **Settings → Drinks**. Tap a drink to change its name, icon, and
price. Swipe left to delete. "Add Drink" appends a new one. Changes
auto-save — no Save button to miss. The counter row caps at 4 drinks to
stay readable on a 40mm watch.

## Known gaps

- Only aggregate sales for today are tracked — no per-tab history of who
  bought what after Close Out.
- Icon palette is fixed to 6 SF Symbols. Free-form symbol names would
  render as broken placeholders she can't diagnose on the watch.
- App icon is an empty placeholder asset. Drop a 1024×1024 PNG into
  `Assets.xcassets/AppIcon.appiconset/` and reference it in `Contents.json`.
- No iPhone companion for bulk setup — prices/tax/drinks are all edited on
  the watch.
