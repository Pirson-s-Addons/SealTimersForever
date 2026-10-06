<h1 align="center">Seal Timers Forever</h1>

<p align="center">
  <b>Your active paladin seal on screen with its remaining time, movable and resizable, for World of Warcraft: Forever</b>
</p>

<p align="center">
<a href="https://github.com/Pirson-s-Addons/SealTimersForever/releases/latest">
<img src="https://img.shields.io/github/v/release/Pirson-s-Addons/SealTimersForever?style=for-the-badge&color=A78BFA">
</a>
<img src="https://img.shields.io/badge/WoW_Forever-1.60.1-C4B5FD?style=for-the-badge">
<a href="LICENSE">
<img src="https://img.shields.io/badge/License-MIT-E9D5FF?style=for-the-badge">
</a>
</p>

<p align="center">
<a href="README.es.md">🇪🇸 Español</a>
</p>

---

## 📸 Screenshots

<table>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/669/screenshot_1-png.png" alt="Seal timer bar"><br><sub>Seal timer bar</sub></td>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/670/opcions-menu-seal-timers-forever-png.png" alt="Options"><br><sub>Options</sub></td>
</tr>
</table>

---

## What it does

**Seal Timers Forever** shows your active paladin seal as an icon with a countdown, so you always know how long it has left, in and out of combat.

It works with **every seal in WoW Forever**: Seal of Fury, Command, Righteousness, the Crusader, Wisdom, Light, Justice... and any new seal you learn, in any client language.

## Features

- Active seal icon with its **remaining time**, updated in and out of combat.
- **Recasting** a seal restarts its timer; **switching** seals replaces the icon (only one seal is active in Forever).
- Detects every seal in your spellbook, including new Forever seals like **Seal of Fury**.
- **Movable** anywhere on the screen and **resizable** from 50% to 300%.
- Only runs for paladins. Lightweight, no libraries. Settings live in the game's own **Options → AddOns** panel.

## Installation

1. Download the zip from the [latest release](https://github.com/Pirson-s-Addons/SealTimersForever/releases/latest).
2. Extract the `SealTimersForever` folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Restart WoW and enable the addon.

It only loads on WoW Forever: the only TOC is `SealTimersForever_Camelot.toc` (`Camelot` is Forever's game type), so no other client lists it.

## Usage

- `/stf` opens the settings: **Lock position** (untick it to drag the icons) and **Size**.
- `/stf check` lists the seals in your spellbook and how each one is tracked in combat.
- `/stf debug` writes every seal cast and aura change to the chat (for bug reports).
- `/stf reset` clears the learned seal durations.

## Notes

In WoW Forever, aura data is **secret** to addons during combat, so the addon cannot simply read the seal's buff. Instead it tracks **your own seal casts**, which are never secret, and counts the seal's duration (30 s in Forever) from the moment you cast it. When the game lets the addon read the real aura duration, that one is used.

---

**Author**: Pirson · [GitHub](https://github.com/Pirson-s-Addons) · [CurseForge](https://www.curseforge.com/members/pirson/projects) · MIT License
