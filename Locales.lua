local _, ns = ...

-- Ingles por defecto: cualquier clave sin traducir cae aqui.
local L = {
    TITLE = "Seal Timers",
    DRAG_HINT = "Drag to move",
    LOCK = "Lock position",
    LOCK_TOOLTIP = "Unlock to drag the seal icons anywhere on the screen.",
    SIZE = "Size",
    SIZE_TOOLTIP = "Size of the seal icons.",
    CHECK_HEADER = "Your seals in combat:",
    CHECK_OPEN = "%s: readable, exact time",
    CHECK_SECRET = "%s: secret aura, tracked by its cast with the last duration seen (%s)",
    CHECK_CAST_SECRET = "%s: even its cast is secret, it cannot be tracked in combat",
    NOT_SEEN = "not seen yet: cast it once out of combat",
    CHECK_NONE = "No seals in your spellbook yet.",
}

local locale = GetLocale()
if locale == "esES" or locale == "esMX" then
    L.TITLE = "Temporizador de sellos"
    L.DRAG_HINT = "Arrastra para mover"
    L.LOCK = "Bloquear posición"
    L.LOCK_TOOLTIP = "Desbloquéalo para arrastrar los iconos de los sellos a cualquier parte de la pantalla."
    L.SIZE = "Tamaño"
    L.SIZE_TOOLTIP = "Tamaño de los iconos de los sellos."
    L.CHECK_HEADER = "Tus sellos en combate:"
    L.CHECK_OPEN = "%s: se lee, tiempo exacto"
    L.CHECK_SECRET = "%s: aura secreta, se sigue por su lanzamiento con la última duración vista (%s)"
    L.CHECK_CAST_SECRET = "%s: hasta su lanzamiento es secreto, no se puede seguir en combate"
    L.NOT_SEEN = "aún no vista: lánzalo una vez fuera de combate"
    L.CHECK_NONE = "Todavía no tienes sellos en el libro de hechizos."
end

ns.L = L
