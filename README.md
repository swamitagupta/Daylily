# Daylily

An iOS app for tracking which activities line up with how you feel. 

Each day you log what you did and rate the outcomes. Patterns plots those ratings over time with the activity days
marked underneath. Everything's stored locally.

[![iOS 17+](https://img.shields.io/badge/iOS-17.0%2B-blue?style=flat-square)](#building)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square)](#building)
[![MIT](https://img.shields.io/badge/license-MIT-4C9A72?style=flat-square)](#license)

## Screenshots

<table>
  <tr>
    <td width="33%" align="center" valign="top">
      <img src="Screenshots/home.png" alt="Home"><br><br>
      <b>Home</b><br>
      <sub>Today's check-in and the month below, with icons on days you logged.</sub>
    </td>
    <td width="33%" align="center" valign="top">
      <img src="Screenshots/check-in.png" alt="Check in"><br><br>
      <b>Check in</b><br>
      <sub>Tap what you did, rate how you felt 1–5.</sub>
    </td>
    <td width="33%" align="center" valign="top">
      <img src="Screenshots/graph-details.png" alt="Graph detail"><br><br>
      <b>Graph detail</b><br>
      <sub>One line per outcome. Unrated days leave a gap.</sub>
    </td>
  </tr>
</table>

## Building

Xcode 16+. Open `Daylily.xcodeproj` and run. The project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

## License

MIT

