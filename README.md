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
<a href="#-español">🇪🇸 Español</a>
</p>

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

## 🇪🇸 Español

**Seal Timers Forever** muestra tu sello de paladín activo como un icono con cuenta atrás, para que sepas siempre cuánto le queda, en combate y fuera de él.

Funciona con **todos los sellos de WoW Forever**: Sello de Furia, de Orden, de Rectitud, del Cruzado, de Sabiduría, de Luz, de Justicia... y cualquier sello nuevo que aprendas, en cualquier idioma del cliente.

### Funciones

- Icono del sello activo con su **tiempo restante**, actualizado en combate y fuera de él.
- **Relanzar** un sello reinicia su tiempo; **cambiar** de sello sustituye el icono (en Forever solo hay un sello activo).
- Detecta todos los sellos de tu libro de hechizos, incluidos los nuevos de Forever como el **Sello de Furia**.
- Se puede **mover** a cualquier parte de la pantalla y **cambiar de tamaño** del 50 % al 300 %.
- Solo se activa en paladines. Ligero, sin librerías. Los ajustes están en el panel del propio juego: **Opciones → AddOns**.

### Instalación

1. Descarga el zip de la [última release](https://github.com/Pirson-s-Addons/SealTimersForever/releases/latest).
2. Extrae la carpeta `SealTimersForever` en `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Reinicia el juego y activa el addon.

Solo se carga en WoW Forever: su único `.toc` es `SealTimersForever_Camelot.toc` (`Camelot` es el game type de Forever), así que ningún otro cliente lo muestra.

### Uso

- `/stf` abre los ajustes: **Bloquear posición** (desmárcalo para arrastrar los iconos) y **Tamaño**.
- `/stf check` lista los sellos de tu libro de hechizos y cómo se sigue cada uno en combate.
- `/stf debug` escribe en el chat cada lanzamiento de sello y cambio de auras (para reportar fallos).
- `/stf reset` borra las duraciones de sellos aprendidas.

### Notas

En WoW Forever los datos de las auras son **secretos** para los addons en combate, así que el addon no puede leer sin más el bufo del sello. En su lugar sigue **tus propios lanzamientos de sello**, que nunca son secretos, y cuenta la duración del sello (30 s en Forever) desde que lo lanzas. Cuando el juego deja leer la duración real del aura, se usa esa.

---

**Author**: Pirson · [GitHub](https://github.com/Pirson-s-Addons) · [CurseForge](https://www.curseforge.com/members/pirson/projects) · MIT License
