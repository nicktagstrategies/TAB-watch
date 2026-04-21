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
  accent ring) for fast "buying a round" entry without tapping. Crown
  only acts within a 10 s window after a `+` / `-` tap so a wrist brush
  can't silently add drinks. Up to 4 drinks fit in a fixed row; 5–8 get
  a horizontal scroll.
- **Close Out** (green) — two-step confirm with optional tip presets
  (No tip / 15 / 18 / 20 / 25%). Adds the tax-inclusive total to Today's
  sales and the tip to Today's Tips bucket. Undoable for 30 s and
  reopenable from Recent for up to 2 hours.
- **Split** (white outline) and **Move** — Split peels drinks onto a new
  auto-numbered tab (inherits source's locked prices). Move transfers
  drinks to another already-open tab (charged at the destination's
  prices). Both only show when drinks are counted.
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
- **Settings — Today** — running sales + tabs-closed count, plus **Tips**
  (collected from Close Out) and **Walkers** (unpaid tabs) rows when
  non-zero. "Reset Today" has a confirmation so a pocket tap can't wipe
  the shift total.
- **Recent** — a small link on the home screen when any tab has been
  closed / deleted / walkered within the last 2 hours. Pushes to a list
  where she can reopen one if the customer returns. Reversing accounts
  is skipped if the reopen crosses a shift boundary.

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
    ├── TabDetailView.swift    # Counters + Close Out + Split + Move + Delete + crown
    ├── RenameTabView.swift    # Optional name entry for a tab
    ├── SplitTabView.swift     # Per-drink Stepper → new auto-numbered tab
    ├── MoveTabView.swift      # Per-drink Stepper → another existing tab
    ├── RecentClosuresView.swift # 2-hour reopen list
    ├── DrinkCounterView.swift # Single drink capsule + active ring
    ├── EditDrinkView.swift    # Name / icon / price editor for one drink
    └── SettingsView.swift     # Drinks list, Tax, Shift, Today, confirms
```

## Complication & Smart Stack widget

A bundled widget extension surfaces today's total, open-tab count, and
your top tab's running subtotal as a watch-face complication
(`accessoryCircular`, `accessoryRectangular`, `accessoryInline`,
`accessoryCorner`) and in the Smart Stack on wrist raise. The
rectangular layout has an inline `+` button that increments your first
configured drink on the most-recent open tab — zero-tap rounds from the
watch face.

The widget reads the same `TabStore` data the app writes through a
shared App Group (`group.com.tabwatch.shared`). Both targets have
entitlement files pre-populated; **you'll need to pick your Apple
Developer team in Xcode → Signing & Capabilities** for both targets so
the App Group capability gets provisioned.

## Building

Requires macOS with Xcode 26+ (watchOS 26 SDK).

```sh
./scripts/setup.sh     # installs xcodegen if missing, generates project, opens Xcode
```

Then in Xcode:

1. Signing & Capabilities → pick your Apple ID team for **both** the
   `TabWatch Watch App` and `TabWatch Widget` targets.
2. Pick your watch as the run destination and hit ⌘R.

Every push to this repo is compile-checked on GitHub's macOS runner via
`.github/workflows/build.yml`, so if CI is green the code at least
compiles; local failures are specific to your Mac's environment.

For a compile-only check on your Mac (matches CI exactly):

```sh
./scripts/build.sh
```

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
