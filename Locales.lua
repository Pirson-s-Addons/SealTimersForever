local _, ns = ...

-- Ingles por defecto: cualquier clave sin traducir cae aqui.
local L = {
    TITLE = "Seal Timers",
    DRAG_HINT = "Drag to move",
    LOCK = "Lock position",
    LOCK_TOOLTIP = "Unlock to drag the seal icons anywhere on the screen.",
    SIZE = "Size",
    SIZE_TOOLTIP = "Size of the seal icons.",
    SWING_BAR = "Swing timer",
    SWING_BAR_TOOLTIP = "Main-hand swing bar under the seal, with the twist zone in gold at the end.",
    TWIST_WINDOW = "Twist zone",
    TWIST_WINDOW_TOOLTIP = "Last seconds of each swing in which the seal glows: switch seals then to twist (only seals with an Echo: Command, Righteousness, Fury, Justice).",
    TWIST_SOUND = "Twist sound",
    TWIST_SOUND_TOOLTIP = "Plays a sound when a swing lands after switching from a seal with an Echo.",
    CHECK_HEADER = "Your seals in combat:",
    CHECK_OPEN = "%s: readable, exact time",
    CHECK_SECRET = "%s: secret aura, tracked by its cast with the last duration seen (%s)",
    CHECK_CAST_SECRET = "%s: even its cast is secret, it cannot be tracked in combat",
    NOT_SEEN = "not seen yet: cast it once out of combat",
    CHECK_NONE = "No seals in your spellbook yet.",
    DEBUG_ON = "debug on: every seal cast and aura change is written to the chat.",
    DEBUG_OFF = "debug off.",
    RESET_DONE = "learned durations cleared: cast each seal once out of combat.",
}

local locale = GetLocale()
if locale == "esES" or locale == "esMX" then
    L.TITLE = "Temporizador de sellos"
    L.DRAG_HINT = "Arrastra para mover"
    L.LOCK = "Bloquear posición"
    L.LOCK_TOOLTIP = "Desbloquéalo para arrastrar los iconos de los sellos a cualquier parte de la pantalla."
    L.SIZE = "Tamaño"
    L.SIZE_TOOLTIP = "Tamaño de los iconos de los sellos."
    L.SWING_BAR = "Temporizador de golpe"
    L.SWING_BAR_TOOLTIP = "Barra del golpe de la mano derecha bajo el sello, con la zona de twist en dorado al final."
    L.TWIST_WINDOW = "Zona de twist"
    L.TWIST_WINDOW_TOOLTIP = "Últimos segundos de cada golpe en los que el sello brilla: cambia de sello entonces para hacer twist (solo sellos con Eco: Orden, Rectitud, Furia, Justicia)."
    L.TWIST_SOUND = "Sonido de twist"
    L.TWIST_SOUND_TOOLTIP = "Suena cuando un golpe cae después de cambiar desde un sello con Eco."
    L.CHECK_HEADER = "Tus sellos en combate:"
    L.CHECK_OPEN = "%s: se lee, tiempo exacto"
    L.CHECK_SECRET = "%s: aura secreta, se sigue por su lanzamiento con la última duración vista (%s)"
    L.CHECK_CAST_SECRET = "%s: hasta su lanzamiento es secreto, no se puede seguir en combate"
    L.NOT_SEEN = "aún no vista: lánzalo una vez fuera de combate"
    L.CHECK_NONE = "Todavía no tienes sellos en el libro de hechizos."
    L.DEBUG_ON = "depuración activada: cada lanzamiento de sello y cambio de auras se escribe en el chat."
    L.DEBUG_OFF = "depuración desactivada."
    L.RESET_DONE = "duraciones aprendidas borradas: lanza cada sello una vez fuera de combate."
end

ns.L = L
