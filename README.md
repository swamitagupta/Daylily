<div align="center">

<img src="Daylily/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="96" alt="Daylily">

# Daylily

Log what you did, rate how you felt, and see which activities line up with which outcomes.

[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-blue?style=flat-square)](#build)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square)](#build)
[![MIT](https://img.shields.io/badge/license-MIT-4C9A72?style=flat-square)](#license)

</div>

A SwiftUI app. Everything stays on the device: no account, server, sync, or analytics.

## Screenshots

<table>
  <tr>
    <td align="center" width="33%"><img src="Screenshots/home.png" alt="Home"><br><sub><b>Home</b></sub></td>
    <td align="center" width="33%"><img src="Screenshots/calendar.png" alt="Calendar"><br><sub><b>Calendar</b></sub></td>
    <td align="center" width="33%"><img src="Screenshots/check-in.png" alt="Check in"><br><sub><b>Check in</b></sub></td>
  </tr>
  <tr>
    <td align="center" width="33%"><img src="Screenshots/patterns.png" alt="Patterns"><br><sub><b>Patterns</b></sub></td>
    <td align="center" width="33%"><img src="Screenshots/graph-details.png" alt="Graph details"><br><sub><b>Graph details</b></sub></td>
    <td align="center" width="33%"><img src="Screenshots/customize.png" alt="Customize"><br><sub><b>Customize</b></sub></td>
  </tr>
  <tr>
    <td align="center" width="33%"><img src="Screenshots/home-dark.png" alt="Home, dark"><br><sub><b>Home</b></sub></td>
    <td align="center" width="33%"><img src="Screenshots/patterns-dark.png" alt="Patterns, dark"><br><sub><b>Patterns</b></sub></td>
    <td align="center" width="33%"><img src="Screenshots/graph-details-dark.png" alt="Graph details, dark"><br><sub><b>Graph details</b></sub></td>
  </tr>
</table>

Follows the system appearance; on iPad the layout stays a centered column rather than stretching.

## Build

Open `Daylily.xcodeproj` in Xcode, pick a simulator, run. Requires iOS 17+ and Xcode 15+.

No signing team is configured, which keeps the project portable: simulator builds need none, and device builds need you to pick your own once under **Signing & Capabilities**.

The project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Tests

```
xcodebuild test -scheme Daylily -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2'
```

87 unit tests plus one UI test covering graph reordering.

## Sample data

Debug builds seed 21 sample days and two sample graphs so Patterns is not empty on first launch. One action on Home removes both. Release builds never generate them.

## Data

State is versioned JSON in `UserDefaults`, with the previous save kept as a fallback and a recovery screen that will not overwrite unreadable data. Export a backup from Customize before deleting the app or changing phones.

## License

MIT
