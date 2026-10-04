# Life Brief — native iOS app

A true native iOS briefing app built with SwiftUI, SwiftData, and Apple's
Liquid Glass design language (iOS 26+). One app holds all of your briefings
as topics: Portland Weekly, AI & Tech Daily, Politics, and anything you add
later. New topics are data, not screens, so the structure never needs to change.

## Requirements

- A Mac with **Xcode 26** or later
- iPhone running **iOS 26** or later (deployment target is iOS 26)
- Your Apple ID signed in to Xcode (free tier works for your own device)

## Build and run

1. Copy this folder to the Mac and open `LifeBrief.xcodeproj` in Xcode.
2. Select the **LifeBrief** target, go to **Signing & Capabilities**, choose
   your Team, and change the Bundle Identifier from `com.example.lifebrief`
   to something unique (e.g. `com.yourname.lifebrief`).
3. Connect your iPhone, select it as the run destination, and press **Run**.
4. On the iPhone, enable Developer Mode (Settings > Privacy & Security >
   Developer Mode) and trust your Apple ID (Settings > General > VPN &
   Device Management).

With the free Apple ID tier the app must be reinstalled every 7 days
(press Run again). The paid Apple Developer Program ($99/year) removes this
limit and enables TestFlight.

## What's inside

| Area | Notes |
|---|---|
| `LifeBriefApp.swift` | App entry, SwiftData container, System/Light/Dark appearance |
| `Models/` | SwiftData models: `Topic`, `Edition`, `BriefSection`, `StoryItem` |
| `Services/BriefStore.swift` | First-launch seeding, feed import (upsert by feed ID) |
| `Services/BriefStore.swift` (`FeedService`) | Async `URLSession` fetch of the JSON feed |
| `Views/FloatingTabBar.swift` | Music-style floating glass tab bar: horizontally scrollable topics, selection pill glides via `matchedGeometryEffect` inside `GlassEffectContainer`, haptic feedback |
| `Views/RootView.swift` | Topic routing, bottom `safeAreaBar`, Dynamic Type override |
| `Views/TopicHomeView.swift` | Latest edition per topic, search, empty-topic placeholder |
| `Views/Sections.swift` | Stories, OHSU (news + campus events), community buzz, summary |
| `Views/StoryDetailView.swift` | Full story, source link (glass prominent button), ShareLink |
| `Views/OrganizerView.swift` | Add/reorder/hide topics, reorder sections (e.g. OHSU above overview) |
| `Views/SettingsView.swift` | Standard iOS controls only: segmented pickers, toggles, text field |
| `Resources/SeedData/` | Bundled first editions (Portland 2026-10-02, AI & Tech 2026-10-03) |
| `generate_project.py` | Regenerates `project.pbxproj` if files are added/removed |

## Design notes (Apple HIG)

- **Liquid Glass is used only for chrome**: the floating tab bar, the
  selection pill, and buttons. Content cards use solid materials, per Apple's
  guidance ("never apply glass to content itself").
- **Standard components adopt the look automatically**: `NavigationStack`,
  sheets, search, and toolbars pick up Liquid Glass from the SDK.
- **Navigation**: one `NavigationStack` per topic tab, never around the tab bar.
- **Controls**: toggles, segmented pickers, and text fields from SwiftUI;
  no custom control imitations.
- **Feedback**: `sensoryFeedback` on selection and bookmark, with a Settings
  toggle; respects Reduce Motion automatically.
- **Typography**: Dynamic Type throughout, plus an app-level text-size
  override that maps to real `ContentSizeCategory` values.

## Live editions (feed)

New briefings publish as JSON; the app fetches and imports them with no code
changes. Set the feed URL in Settings > Content Updates.

```json
[
  {
    "id": "portland",
    "name": "Portland",
    "systemImage": "building.2",
    "summary": "Weekly briefing on Portland, Oregon.",
    "editions": [
      {
        "id": "portland-2026-10-05",
        "date": "2026-10-05",
        "dateLabel": "Week of October 5 - 11, 2026",
        "theme": "Two to four sentence overview.",
        "sections": [
          {
            "kind": "stories",
            "title": "Top Stories",
            "items": [
              {
                "headline": "...",
                "body": "...",
                "sourceName": "The Oregonian",
                "sourceURL": "https://...",
                "tag": "r/Portland"
              }
            ]
          }
        ]
      }
    ]
  }
]
```

Section `kind` is one of: `overview`, `stories`, `ohsu`, `community`,
`summary`, `custom`. Items tagged `"event"` inside an `ohsu` section render
as campus event rows (put `Date · Location · Format` in `body`).

## Regenerating the Xcode project

If you add or remove source files, rerun:

```
python3 generate_project.py
```
