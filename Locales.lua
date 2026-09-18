local _, ns = ...

-- Ingles por defecto: cualquier clave sin traducir cae aqui.
local L = {
    TITLE = "Seal Timers",
    DRAG_HINT = "Drag to move",
    LOCK = "Lock position",
    LOCK_TOOLTIP = "Unlock to drag the seal icons anywhere on the screen.",
    SIZE = "Size",
    SIZE_TOOLTIP = "Size of the seal icons.",
    CHECK_HEADER = "Seals in combat (secret values):",
    CHECK_OPEN = "%s: readable in combat",
    CHECK_SECRET = "%s: secret in combat, only shown if cast out of combat",
    CHECK_MISSING = "Spell %d does not exist in this client",
}

local locale = GetLocale()
if locale == "esES" or locale == "esMX" then
    L.TITLE = "Temporizador de sellos"
    L.DRAG_HINT = "Arrastra para mover"
    L.LOCK = "Bloquear posición"
    L.LOCK_TOOLTIP = "Desbloquéalo para arrastrar los iconos de los sellos a cualquier parte de la pantalla."
    L.SIZE = "Tamaño"
    L.SIZE_TOOLTIP = "Tamaño de los iconos de los sellos."
    L.CHECK_HEADER = "Sellos en combate (valores secretos):"
    L.CHECK_OPEN = "%s: se puede leer en combate"
    L.CHECK_SECRET = "%s: secreto en combate, solo se muestra si lo lanzas fuera de combate"
    L.CHECK_MISSING = "El hechizo %d no existe en este cliente"
end

ns.L = L
