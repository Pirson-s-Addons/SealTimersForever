<h1 align="center">Seal Timers Forever</h1>

<p align="center">
  <b>Tu sello de paladín activo en pantalla con su tiempo restante, movible y redimensionable, para World of Warcraft: Forever</b>
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
<a href="README.md">🇬🇧 English</a>
</p>

---

## 📸 Capturas

<table>
<tr>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/669/screenshot_1-png.png" alt="Seal timer bar"><br><sub>Barra del sello</sub></td>
<td align="center" width="50%"><img src="https://media.forgecdn.net/attachments/1975/670/opcions-menu-seal-timers-forever-png.png" alt="Options"><br><sub>Opciones</sub></td>
</tr>
</table>

---

## Qué hace

**Seal Timers Forever** muestra tu sello de paladín activo como un icono con cuenta atrás, para que sepas siempre cuánto le queda, en combate y fuera de él.

Funciona con **todos los sellos de WoW Forever**: Sello de Furia, de Orden, de Rectitud, del Cruzado, de Sabiduría, de Luz, de Justicia... y cualquier sello nuevo que aprendas, en cualquier idioma del cliente.

## Funciones

- Icono del sello activo con su **tiempo restante**, actualizado en combate y fuera de él.
- **Relanzar** un sello reinicia su tiempo; **cambiar** de sello sustituye el icono (en Forever solo hay un sello activo).
- Detecta todos los sellos de tu libro de hechizos, incluidos los nuevos de Forever como el **Sello de Furia**.
- Se puede **mover** a cualquier parte de la pantalla y **cambiar de tamaño** del 50 % al 300 %.
- Solo se activa en paladines. Ligero, sin librerías. Los ajustes están en el panel del propio juego: **Opciones → AddOns**.

## Instalación

1. Descarga el zip de la [última release](https://github.com/Pirson-s-Addons/SealTimersForever/releases/latest).
2. Extrae la carpeta `SealTimersForever` en `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Reinicia el juego y activa el addon.

Solo se carga en WoW Forever: su único `.toc` es `SealTimersForever_Camelot.toc` (`Camelot` es el game type de Forever), así que ningún otro cliente lo muestra.

## Uso

- `/stf` abre los ajustes: **Bloquear posición** (desmárcalo para arrastrar los iconos) y **Tamaño**.
- `/stf check` lista los sellos de tu libro de hechizos y cómo se sigue cada uno en combate.
- `/stf debug` escribe en el chat cada lanzamiento de sello y cambio de auras (para reportar fallos).
- `/stf reset` borra las duraciones de sellos aprendidas.

## Notas

En WoW Forever los datos de las auras son **secretos** para los addons en combate, así que el addon no puede leer sin más el bufo del sello. En su lugar sigue **tus propios lanzamientos de sello**, que nunca son secretos, y cuenta la duración del sello (30 s en Forever) desde que lo lanzas. Cuando el juego deja leer la duración real del aura, se usa esa.

---

**Autor**: Pirson · [GitHub](https://github.com/Pirson-s-Addons) · [CurseForge](https://www.curseforge.com/members/pirson/projects) · Licencia MIT
