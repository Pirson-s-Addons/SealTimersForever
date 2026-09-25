local ADDON_NAME, ns = ...

-- ==========================================
-- IDIOMA POR DEFECTO (enUS / enGB)
-- ==========================================
-- Este fichero define TODAS las claves. Los demas Locales/<idioma>.lua se
-- cargan despues y sobrescriben las suyas; lo que falte se queda en ingles.

local L = ns.L or {}
ns.L = L

L["TITLE"] = "Seal Timers"
L["DRAG_HINT"] = "Drag to move"
L["LOCK"] = "Lock position"
L["LOCK_TOOLTIP"] = "Unlock to drag the seal icons anywhere on the screen."
L["SIZE"] = "Size"
L["SIZE_TOOLTIP"] = "Size of the seal icons."
L["GENERAL_HEADER"] = "General"
L["TWIST_HEADER"] = "Seal twisting"
L["TWIST_ENABLED"] = "Enable seal twisting"
L["TWIST_ENABLED_TOOLTIP"] = "Swing timer, seal glow and twist sound. Turn it off to keep only the seal timer."
L["TWIST_GLOW"] = "Seal glow"
L["TWIST_GLOW_TOOLTIP"] = "The seal icon pulses inside the twist window when the seal leaves an Echo."
L["SWING_BAR"] = "Swing timer"
L["SWING_BAR_TOOLTIP"] = "Main-hand swing bar above the seal with the time left to the next swing. Red line: last moment for a global-cooldown ability. Green line: the twist window starts."
L["TWIST_WINDOW"] = "Twist window"
L["TWIST_WINDOW_TOOLTIP"] = "Seconds before each swing in which the seal glows (green line): switch seals then to twist (only seals that leave an Echo: Command, Righteousness, Fury, Justice)."
L["TWIST_SOUND"] = "Twist sound"
L["TWIST_SOUND_TOOLTIP"] = "Plays a sound when a swing lands after switching from a seal that leaves an Echo."
L["HIT_ICON"] = "Icon on every hit"
L["HIT_ICON_TOOLTIP"] = "Shows the active seal above the target for 1.5 s on every melee swing, and also the previous seal (its Echo) when the swing twists. Unlock the position to move it."
L["CHECK_HEADER"] = "Your seals in combat:"
L["CHECK_OPEN"] = "%s: readable, exact time"
L["CHECK_SECRET"] = "%s: secret aura, tracked by its cast with the last duration seen (%s)"
L["CHECK_CAST_SECRET"] = "%s: even its cast is secret, it cannot be tracked in combat"
L["NOT_SEEN"] = "30 s by default"
L["CHECK_NONE"] = "No seals in your spellbook yet."
L["DEBUG_ON"] = "debug on: every seal cast and aura change is written to the chat."
L["DEBUG_OFF"] = "debug off."
L["RESET_DONE"] = "learned durations cleared."
L["VERSION"] = "Version:"
L["AUTHOR"] = "Author:"
L["LINKS"] = "Links"
L["COMMANDS"] = "Commands"
L["SELECT"] = "Select"
L["SELECT_TOOLTIP"] = "Selects the whole link so you can copy it with Ctrl+C. WoW does not let addons write to the clipboard, so the last step is yours."
L["ABOUT_DESC"] = "Your active paladin seal with its remaining time, and a swing timer for seal twisting. Movable and resizable. The settings are in General."
L["CMD_OPEN"] = "Opens the settings."
L["CMD_CHECK"] = "Lists your seals and whether they can be tracked in combat."
L["CMD_RESET"] = "Clears the learned seal durations."
L["CMD_DEBUG"] = "Writes every seal cast and aura change to the chat."
L["OPTIONS_TITLE"] = "Seal Timers Forever Options"
L["DEFAULTS"] = "Default Values"
