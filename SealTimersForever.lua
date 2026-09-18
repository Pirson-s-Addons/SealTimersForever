-- Seal Timers Forever: los sellos de paladin activos en pantalla con su tiempo
-- restante, en un bloque que se mueve y cambia de tamano. Solo WoW Forever.
--
-- Valores secretos: en Forever, con restricciones activas (combate, encuentro,
-- PvP...), los datos de las auras son secretos para los addons, incluido todo
-- el contenido de UNIT_AURA. Con un secreto no se puede ni comparar (tampoco
-- con nil) ni preguntar si es verdadero: da un error de Lua, que el juego no
-- muestra por defecto. Regla de todo el fichero: mirar IsSecret ANTES de tocar
-- un valor que venga de un aura.
--
-- El tiempo:
--   * Sello lanzado por el jugador (via principal): se detecta por su
--     LANZAMIENTO. UNIT_SPELLCAST_* solo es secreto si la unidad no es el
--     jugador ni su mascota, asi que siempre se lee. Cuenta desde el
--     lanzamiento con la duracion aprendida o 30 s (la de todo sello en
--     Forever). En la beta las auras de los sellos no se leen ni fuera de combate.
--   * Sello ya activo sin lanzamiento visto (tras /reload): el tiempo del aura.
--     GetAuraDuration da un objeto de duracion que va tal cual a un Cooldown.
-- El evento del lanzamiento llega antes de que el juego renueve el aura, asi
-- que el tiempo se relee un instante despues. Al salir de combate se relee todo.
--
-- En Forever solo hay un sello activo: al lanzar otro, el anterior se sustituye
-- y deja un "Eco". Si el eco lleva el nombre del sello viejo no debe pasar por
-- el sello activo ni ensenar su duracion corta: el activo es el ultimo lanzado,
-- y la duracion aprendida solo puede crecer. El Juicio ya no consume el sello.
-- Contrastado con Gethe/wow-ui-source, rama "forever".

local _, ns = ...
local L = ns.L

-- Rango 1 de cada sello clasico (Rectitud, Cruzado, Luz, Sabiduria, Justicia y
-- Orden): sirven para pedir al cliente sus nombres en el idioma del jugador y
-- sacar el prefijo comun ("Sello de", "Seal of"...). Los sellos nuevos de
-- Forever (p. ej. Sello de Furia) entran por ese prefijo y por el libro de
-- hechizos, sin saber su ID.
local SEAL_SPELLS = { 21084, 21082, 20165, 20166, 20164, 20375 }

local ICON_SIZE = 40
local SPACING = 4
-- Margen para que un sello recien lanzado no se de por perdido cuando su aura
-- vieja desaparece justo despues de relanzarlo.
local RECAST_GRACE = 1
-- Cuanto esperar tras el lanzamiento para releer el aura ya renovada
local RECAST_REFRESH = 0.2
-- En Forever todos los sellos duran 30 s (datos de habilidades del paladin). Si
-- el aura de un sello se llega a leer, manda su duracion real.
local DEFAULT_DURATION = 30
-- Morado de la marca, el mismo del titulo en todos los addons de Pirson
local BRAND = "|cffd597ff"
local DEFAULTS = { locked = true, scale = 1, point = "CENTER", x = 0, y = -150 }
-- Sube cuando cambia como se aprenden las duraciones: las viejas se descartan
-- (la 1: las antiguas podian ser la de un eco, mucho mas corta).
local DURATIONS_VERSION = 1
local EMPTY = {}

local db
local sealNames, sealPrefix = {}, nil
local knownSeals = {}          -- spellID del libro de hechizos -> nombre del sello
local icons, order, pool = {}, {}, {}  -- nombre del sello -> icono
local activeSeal               -- nombre del ultimo sello lanzado (o elegido al releer)
local debugMode = false
local anchor

--------------------------------------------------
-- VALORES SECRETOS
--------------------------------------------------
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

-- Se puede usar: ni secreto ni nil. IsSecret va primero: comparar un secreto
-- con nil ya es un error.
local function Readable(value)
    if IsSecret(value) then return false end
    return value ~= nil
end

-- Una lista del evento, o vacia si es secreta o no hay
local function List(value)
    if not Readable(value) then return EMPTY end
    return value
end

local function Debug(msg)
    if debugMode then print(BRAND .. "STF|r " .. msg) end
end

--------------------------------------------------
-- QUE ES UN SELLO
--------------------------------------------------
local function CommonPrefix(a, b)
    local i = 0
    while i < #a and i < #b and a:byte(i + 1) == b:byte(i + 1) do i = i + 1 end
    return a:sub(1, i)
end

local function BuildSealNames()
    local count = 0
    for _, spellID in ipairs(SEAL_SPELLS) do
        local name = C_Spell.GetSpellName(spellID)
        if name then
            sealNames[name] = true
            sealPrefix = sealPrefix and CommonPrefix(sealPrefix, name) or name
            count = count + 1
        end
    end
    -- Con un solo nombre, o un prefijo tan corto que casaria con cualquier cosa,
    -- solo valen los nombres exactos.
    if count < 2 or #sealPrefix < 4 then sealPrefix = nil end
end

local function IsSeal(name)
    if not Readable(name) then return false end
    return sealNames[name] or (sealPrefix ~= nil and name:sub(1, #sealPrefix) == sealPrefix)
end

-- Todos los sellos que conoce el jugador, tambien los nuevos de Forever
local function ScanSpellBook()
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
            local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
            if item and item.spellID and IsSeal(item.name) then
                knownSeals[item.spellID] = item.name
                sealNames[item.name] = true
            end
        end
    end
end

local function SealNameForSpell(spellID)
    if not Readable(spellID) then return nil end
    if knownSeals[spellID] then return knownSeals[spellID] end
    local name = C_Spell.GetSpellName(spellID)
    return IsSeal(name) and name or nil
end

--------------------------------------------------
-- ICONOS (uno por sello, por nombre)
--------------------------------------------------
local HideSeal

local function AcquireIcon()
    local icon = table.remove(pool)
    if not icon then
        icon = CreateFrame("Frame", nil, anchor)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cooldown:SetAllPoints()
        icon.cooldown:SetReverse(true)
        icon.cooldown:SetDrawEdge(false)
        icon.cooldown:SetHideCountdownNumbers(false)
        -- Se acabo el tiempo: el sello expiro (tambien cubre retiradas que
        -- llegaron secretas y no se pudieron leer).
        icon.cooldown:SetScript("OnCooldownDone", function(self)
            local parent = self:GetParent()
            if parent.hasTimer and parent.sealName then HideSeal(parent.sealName) end
        end)
    end
    icon:Show()
    return icon
end

local function Layout()
    for i, name in ipairs(order) do
        local icon = icons[name]
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", anchor, "LEFT", (i - 1) * (ICON_SIZE + SPACING), 0)
    end
end

local function ShowSeal(name, texture)
    local icon = icons[name]
    if not icon then
        icon = AcquireIcon()
        icon.sealName = name
        icons[name] = icon
        order[#order + 1] = name
    end
    if Readable(texture) then icon.texture:SetTexture(texture) end
    return icon
end

HideSeal = function(name)
    local icon = icons[name]
    if not icon then return end
    icon:Hide()
    -- El temporizador se para antes de volver al pool: un OnCooldownDone tardio
    -- no debe quitar el sello que reutilice este icono.
    icon.hasTimer = false
    icon.cooldown:Clear()
    icon.sealName, icon.auraInstanceID, icon.castAt = nil, nil, nil
    if activeSeal == name then activeSeal = nil end
    pool[#pool + 1] = icon
    icons[name] = nil
    for i = #order, 1, -1 do
        if order[i] == name then table.remove(order, i) end
    end
end

-- Solo un sello activo a la vez
local function HideOtherSeals(name)
    for i = #order, 1, -1 do
        if order[i] ~= name then HideSeal(order[i]) end
    end
end

local function AuraExists(id)
    local data = C_UnitAuras.GetAuraDataByAuraInstanceID("player", id)
    if IsSecret(data) then return true end
    return data ~= nil
end

-- La duracion de un sello es fija: solo crece. Asi un eco corto con el mismo
-- nombre, o un aura a medias, no la estropea.
local function Learn(name, total)
    if Readable(total) and total > (db.durations[name] or 0) then
        db.durations[name] = total
        Debug(("aprendido %s = %.1f s"):format(name, total))
    end
end

local function SealDuration(name)
    return db.durations[name] or DEFAULT_DURATION
end

-- Si el aura es legible, aprende de paso su duracion real
local function LearnFromAura(name, id)
    local duration = C_UnitAuras.GetAuraDuration("player", id)
    if duration:HasSecretValues() or duration:IsZero() then return end
    Learn(name, duration:GetTotalDuration())
end

local function StartTimer(name)
    local icon = icons[name]
    if not icon then return end
    local cooldown = icon.cooldown
    if icon.castAt then
        -- Lanzado por el jugador: su duracion desde el lanzamiento. Relanzar un
        -- sello lo renueva entero, asi que es exacto y no depende de nada secreto.
        if icon.auraInstanceID then LearnFromAura(name, icon.auraInstanceID) end
        cooldown:SetCooldown(icon.castAt, SealDuration(name))
        icon.hasTimer = true
        Debug(("%s: %.1f s desde el lanzamiento"):format(name, SealDuration(name)))
    elseif icon.auraInstanceID then
        -- Sin lanzamiento visto (p. ej. tras /reload): el tiempo del aura
        local duration = C_UnitAuras.GetAuraDuration("player", icon.auraInstanceID)
        -- HasSecretValues nunca es secreto (ReturnsNeverSecret). Con valores
        -- secretos el objeto solo se le pasa al Cooldown, sin preguntarle nada.
        if duration:HasSecretValues() then
            cooldown:SetCooldownFromDurationObject(duration)
            icon.hasTimer = true
            Debug(name .. ": tiempo del aura (secreto)")
            return
        end
        local isZero = duration:IsZero()
        if isZero then
            -- Sello permanente: sin temporizador (uno de 0 s acabaria al momento)
            icon.hasTimer = false
            cooldown:Clear()
            Debug(name .. ": sin duracion")
            return
        end
        cooldown:SetCooldownFromDurationObject(duration)
        icon.hasTimer = true
        Learn(name, duration:GetTotalDuration())
        Debug(name .. ": tiempo del aura")
    else
        icon.hasTimer = false
        cooldown:Clear()
        Debug(name .. ": sin tiempo")
    end
end

-- El aura que seguiamos ya no esta. Si el sello se acaba de relanzar, sigue con
-- el tiempo del lanzamiento; si no, se fue (expiro o se sustituyo).
local function LoseAura(name)
    local icon = icons[name]
    if icon.castAt and GetTime() - icon.castAt < RECAST_GRACE then
        icon.auraInstanceID = nil
        StartTimer(name)
    else
        Debug(name .. ": su aura ya no esta")
        HideSeal(name)
    end
end

-- Un aura con nombre de sello. Si no es el sello activo (el ultimo lanzado) es
-- un eco o un resto del cambio: se ignora.
local function TrackAura(aura)
    local name = aura.name
    if not IsSeal(name) then return end
    if activeSeal and name ~= activeSeal then
        Debug(name .. ": ignorada (el sello activo es " .. activeSeal .. ")")
        return
    end
    activeSeal = name
    local icon = ShowSeal(name, aura.icon)
    local id = aura.auraInstanceID
    if Readable(id) then icon.auraInstanceID = id end
    HideOtherSeals(name)
    StartTimer(name)
end

--------------------------------------------------
-- EVENTOS
--------------------------------------------------
-- Relee las auras (fuera de combate son legibles). Si hay varias con nombre de
-- sello, gana el activo; si no se sabe cual es, la de mas duracion (un eco dura
-- menos que el sello).
local function FullScan()
    -- HideSeal borra el sello activo y cuando se lanzo: se guardan antes
    local wanted = activeSeal
    local wantedCastAt = wanted and icons[wanted] and icons[wanted].castAt
    for i = #order, 1, -1 do HideSeal(order[i]) end
    local best, bestTotal
    for _, aura in ipairs(List(C_UnitAuras.GetUnitAuras("player", "HELPFUL"))) do
        local name, id = aura.name, aura.auraInstanceID
        if IsSeal(name) and Readable(id) then
            if name == wanted then
                best = aura
                break
            end
            local total = C_UnitAuras.GetAuraDuration("player", id):GetTotalDuration()
            total = Readable(total) and total or 0
            if not best or total > bestTotal then best, bestTotal = aura, total end
        end
    end
    activeSeal = nil
    if best then
        TrackAura(best)
        local icon = icons[best.name]
        if icon and best.name == wanted and wantedCastAt then
            icon.castAt = wantedCastAt
            StartTimer(best.name)
        end
    end
    Layout()
end

-- Repasa los sellos seguidos por su aura: sigue ahi -> tiempo al dia; no -> fuera
local function RefreshTracked()
    for i = #order, 1, -1 do
        local name = order[i]
        local icon = icons[name]
        if icon.auraInstanceID then
            if AuraExists(icon.auraInstanceID) then StartTimer(name) else LoseAura(name) end
        end
    end
end

local function OnUnitAura(info)
    if not Readable(info) then
        Debug("UNIT_AURA sin datos legibles")
        RefreshTracked()
        Layout()
        return
    end
    local full = info.isFullUpdate
    if IsSecret(full) then
        Debug("UNIT_AURA con datos secretos")
    elseif full then
        -- En combate, con las auras secretas, releer todo borraria los sellos
        -- que no se pueden reconocer: solo se refresca lo que ya se sigue.
        if C_Secrets.ShouldAurasBeSecret() then RefreshTracked() else FullScan() end
        Layout()
        return
    end
    for _, aura in ipairs(List(info.addedAuras)) do TrackAura(aura) end
    for _, id in ipairs(List(info.removedAuraInstanceIDs)) do
        if Readable(id) then
            for _, name in ipairs(order) do
                if icons[name].auraInstanceID == id then LoseAura(name) break end
            end
        end
    end
    RefreshTracked()
    Layout()
end

local function OnSealCast(spellID)
    local name = SealNameForSpell(spellID)
    if not name then return end
    Debug(("lanzado %s (%s)"):format(name, tostring(spellID)))
    activeSeal = name
    local icon = ShowSeal(name, C_Spell.GetSpellTexture(spellID))
    icon.castAt = GetTime()
    HideOtherSeals(name)
    -- En combate no devuelve nada (el aura es secreta). Ojo: nada de "x and y"
    -- aqui, que con x = nil deja un false que pasaria por un ID valido.
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    local id
    if Readable(aura) then id = aura.auraInstanceID end
    if Readable(id) then
        icon.auraInstanceID = id
    elseif icon.auraInstanceID and not AuraExists(icon.auraInstanceID) then
        icon.auraInstanceID = nil
    end
    StartTimer(name)
    Layout()
    -- El aura se renueva justo despues del lanzamiento: se relee entonces
    C_Timer.After(RECAST_REFRESH, function()
        if icons[name] then
            RefreshTracked()
            Layout()
        end
    end)
end

--------------------------------------------------
-- BLOQUE MOVIL
--------------------------------------------------
local function ApplyLock()
    anchor:EnableMouse(not db.locked)
    anchor.bg:SetShown(not db.locked)
    anchor.label:SetShown(not db.locked)
end

local function ApplyScale()
    anchor:SetScale(db.scale)
end

local function CreateAnchor()
    anchor = CreateFrame("Frame", "SealTimersForeverAnchor", UIParent)
    anchor:SetSize(ICON_SIZE, ICON_SIZE)
    anchor:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", anchor.StartMoving)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.point, db.x, db.y = point, x, y
    end)

    -- Solo se ven desbloqueado: marcan donde va el bloque aunque no haya sellos
    anchor.bg = anchor:CreateTexture(nil, "BACKGROUND")
    anchor.bg:SetAllPoints()
    anchor.bg:SetColorTexture(0.84, 0.59, 1, 0.35)
    anchor.label = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    anchor.label:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
    anchor.label:SetText(BRAND .. L.TITLE .. "|r - " .. L.DRAG_HINT)

    ApplyLock()
    ApplyScale()
end

--------------------------------------------------
-- OPCIONES
--------------------------------------------------
local function Check()
    print(BRAND .. "Seal Timers Forever|r: " .. L.CHECK_HEADER)
    local any = false
    for spellID, name in pairs(knownSeals) do
        any = true
        if C_Secrets.ShouldUnitSpellCastBeSecret("player", spellID) then
            print("  " .. L.CHECK_CAST_SECRET:format(name))
        elseif C_Secrets.ShouldSpellAuraBeSecret(spellID) then
            local seen = db.durations[name]
            print("  " .. L.CHECK_SECRET:format(name, seen and (seen .. " s") or L.NOT_SEEN))
        else
            print("  " .. L.CHECK_OPEN:format(name))
        end
    end
    if not any then print("  " .. L.CHECK_NONE) end
end

local function CreateOptions()
    -- En morado tambien en Opciones > AddOns, como en la lista de addons
    local category = Settings.RegisterVerticalLayoutCategory(BRAND .. "Seal Timers Forever|r")

    local lock = Settings.RegisterAddOnSetting(category, "SealTimersForever_Locked", "locked",
        db, Settings.VarType.Boolean, L.LOCK, DEFAULTS.locked)
    lock:SetValueChangedCallback(ApplyLock)
    Settings.CreateCheckbox(category, lock, L.LOCK_TOOLTIP)

    local scale = Settings.RegisterAddOnSetting(category, "SealTimersForever_Scale", "scale",
        db, Settings.VarType.Number, L.SIZE, DEFAULTS.scale)
    scale:SetValueChangedCallback(ApplyScale)
    local options = Settings.CreateSliderOptions(0.5, 3, 0.1)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return string.format("%d%%", math.floor(value * 100 + 0.5))
    end)
    Settings.CreateSlider(category, scale, options, L.SIZE_TOOLTIP)

    Settings.RegisterAddOnCategory(category)

    SLASH_SEALTIMERSFOREVER1 = "/stf"
    SlashCmdList.SEALTIMERSFOREVER = function(msg)
        local command = (msg or ""):lower():match("^%s*(%S*)")
        if command == "check" then return Check() end
        if command == "debug" then
            debugMode = not debugMode
            print(BRAND .. "Seal Timers Forever|r: " .. (debugMode and L.DEBUG_ON or L.DEBUG_OFF))
            return
        end
        if command == "reset" then
            wipe(db.durations)
            print(BRAND .. "Seal Timers Forever|r: " .. L.RESET_DONE)
            return
        end
        Settings.OpenToCategory(category:GetID())
    end
end

--------------------------------------------------
-- ARRANQUE
--------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if event == "PLAYER_LOGIN" then
        -- Solo tiene sentido para paladines: en el resto no se crea nada.
        if select(2, UnitClass("player")) ~= "PALADIN" then
            self:UnregisterAllEvents()
            return
        end
        SealTimersForeverDB = SealTimersForeverDB or {}
        db = SealTimersForeverDB
        for key, value in pairs(DEFAULTS) do
            if db[key] == nil then db[key] = value end
        end
        if db.durationsVersion ~= DURATIONS_VERSION then
            db.durations, db.durationsVersion = {}, DURATIONS_VERSION
        end
        BuildSealNames()
        ScanSpellBook()
        CreateAnchor()
        CreateOptions()
        self:RegisterUnitEvent("UNIT_AURA", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("SPELLS_CHANGED")
        FullScan()
    elseif event == "UNIT_AURA" then
        OnUnitAura(arg2)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSealCast(arg3)
    elseif event == "PLAYER_REGEN_ENABLED" then
        FullScan()
    elseif event == "SPELLS_CHANGED" then
        ScanSpellBook()
    end
end)
