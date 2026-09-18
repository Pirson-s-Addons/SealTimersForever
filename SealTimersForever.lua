-- Seal Timers Forever: los sellos de paladin activos en pantalla con su tiempo
-- restante, en un bloque que se mueve y cambia de tamano. Solo WoW Forever.
--
-- Valores secretos: en Forever, con restricciones activas (combate, encuentro,
-- PvP...), los datos de las auras son secretos para los addons salvo que
-- Blizzard marque el hechizo como "nunca secreto". Por eso hay dos vias:
--   * Aura legible: el tiempo es el del juego. GetAuraDuration da un objeto de
--     duracion que va tal cual a un Cooldown con la cuenta atras visible.
--   * Aura secreta: el sello se detecta por su LANZAMIENTO. UNIT_SPELLCAST_*
--     solo es secreto si la unidad no es el jugador ni su mascota, asi que el
--     hechizo que lanza el jugador siempre se lee. El tiempo sale de la ultima
--     duracion vista de ese sello con el aura legible (se guarda en la BD).
-- Al salir de combate se relee todo, por si algo se desajusto.
--
-- En Forever solo hay un sello activo: al lanzar otro, el anterior se sustituye
-- (y deja un "Eco", que no es un sello). El Juicio ya no consume el sello.
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
local DEFAULTS = { locked = true, scale = 1, point = "CENTER", x = 0, y = -150 }

local db
local sealNames, sealPrefix = {}, nil
local knownSeals = {}          -- spellID del libro de hechizos -> nombre del sello
local icons, order, pool = {}, {}, {}  -- nombre del sello -> icono
local anchor

--------------------------------------------------
-- QUE ES UN SELLO
--------------------------------------------------
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function Readable(value)
    return value ~= nil and not IsSecret(value)
end

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
    icon.sealName, icon.auraInstanceID, icon.hasTimer, icon.castAt = nil, nil, nil, nil
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
    return IsSecret(data) or data ~= nil
end

local function StartTimer(name)
    local icon = icons[name]
    local cooldown = icon.cooldown
    if icon.auraInstanceID then
        -- Tiempo exacto del juego
        local duration = C_UnitAuras.GetAuraDuration("player", icon.auraInstanceID)
        local isZero = duration:IsZero()
        if Readable(isZero) and isZero then
            -- Sello permanente: sin temporizador (uno de 0 s acabaria al momento)
            icon.hasTimer = false
            cooldown:Clear()
            return
        end
        cooldown:SetCooldownFromDurationObject(duration)
        icon.hasTimer = true
        local total = duration:GetTotalDuration()
        if Readable(total) and total > 0 then db.durations[name] = total end
    elseif db.durations[name] then
        -- Aura secreta: la ultima duracion vista, desde el lanzamiento
        cooldown:SetCooldown(icon.castAt or GetTime(), db.durations[name])
        icon.hasTimer = true
    else
        icon.hasTimer = false
        cooldown:Clear()
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
        HideSeal(name)
    end
end

local function TrackAura(aura)
    if not IsSeal(aura.name) then return end
    local icon = ShowSeal(aura.name, aura.icon)
    if Readable(aura.auraInstanceID) then icon.auraInstanceID = aura.auraInstanceID end
    HideOtherSeals(aura.name)
    StartTimer(aura.name)
end

--------------------------------------------------
-- EVENTOS
--------------------------------------------------
local function FullScan()
    for i = #order, 1, -1 do HideSeal(order[i]) end
    for _, aura in ipairs(C_UnitAuras.GetUnitAuras("player", "HELPFUL") or {}) do
        TrackAura(aura)
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
    if not info or info.isFullUpdate then
        -- En combate, con las auras secretas, releer todo borraria los sellos
        -- que no se pueden reconocer: solo se refresca lo que ya se sigue.
        if C_Secrets.ShouldAurasBeSecret() then RefreshTracked() else FullScan() end
        Layout()
        return
    end
    for _, aura in ipairs(info.addedAuras or {}) do TrackAura(aura) end
    for _, id in ipairs(info.removedAuraInstanceIDs or {}) do
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
    local icon = ShowSeal(name, C_Spell.GetSpellTexture(spellID))
    icon.castAt = GetTime()
    HideOtherSeals(name)
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    if aura and Readable(aura.auraInstanceID) then
        icon.auraInstanceID = aura.auraInstanceID
    elseif icon.auraInstanceID and not AuraExists(icon.auraInstanceID) then
        icon.auraInstanceID = nil
    end
    StartTimer(name)
    Layout()
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
    anchor.label:SetText(L.TITLE .. " - " .. L.DRAG_HINT)

    ApplyLock()
    ApplyScale()
end

--------------------------------------------------
-- OPCIONES
--------------------------------------------------
local function Check()
    print("|cffd597ffSeal Timers Forever|r: " .. L.CHECK_HEADER)
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
    local category = Settings.RegisterVerticalLayoutCategory("Seal Timers Forever")

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
        if msg and msg:lower():match("^%s*check") then return Check() end
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
        db.durations = db.durations or {}
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
