-- Seal Timers Forever: los sellos de paladin activos en pantalla con su tiempo
-- restante, en un bloque que se mueve y cambia de tamano. Solo WoW Forever.
--
-- Valores secretos: en Forever, con restricciones activas (combate, encuentro,
-- PvP...), los datos de las auras son secretos para los addons, salvo los
-- hechizos que Blizzard marque como "nunca secretos". Por eso:
--   * El tiempo lo pinta el propio juego: GetAuraDuration devuelve un objeto de
--     duracion que se pasa tal cual a un Cooldown con la cuenta atras visible.
--     Aqui no se hace ninguna cuenta con el.
--   * Reconocer que un aura es un sello necesita leer su nombre. Si es secreto,
--     no se puede: se ignora sin errores. /stf check dice, sello a sello, si
--     el cliente lo deja leer en combate (C_Secrets.ShouldSpellAuraBeSecret).
-- Contrastado con Gethe/wow-ui-source, rama "forever".

local _, ns = ...
local L = ns.L

-- Rango 1 de cada sello clasico (Rectitud, Cruzado, Luz, Sabiduria, Justicia y
-- Orden). Solo sirven para pedir al cliente su nombre en el idioma del jugador:
-- los demas rangos comparten nombre, y un sello nuevo de Forever (p. ej. "Sello
-- de furia") se reconoce por el prefijo comun ("Sello de", "Seal of"...).
local SEAL_SPELLS = { 21084, 21082, 20165, 20166, 20164, 20375 }

local ICON_SIZE = 40
local SPACING = 4
local DEFAULTS = { locked = true, scale = 1, point = "CENTER", x = 0, y = -150 }

local db
local sealNames, sealPrefix = {}, nil
local tracked, order, pool = {}, {}, {}
local anchor

--------------------------------------------------
-- QUE ES UN SELLO
--------------------------------------------------
local function Readable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
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

--------------------------------------------------
-- ICONOS
--------------------------------------------------
local Untrack

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
        -- Red de seguridad: si la retirada del aura llego con un ID secreto, el
        -- icono se quita igualmente cuando se le acaba el tiempo.
        icon.cooldown:SetScript("OnCooldownDone", function(self)
            local parent = self:GetParent()
            if parent.auraInstanceID then Untrack(parent.auraInstanceID) end
        end)
    end
    icon:Show()
    return icon
end

local function Layout()
    for i, id in ipairs(order) do
        local icon = tracked[id]
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", anchor, "LEFT", (i - 1) * (ICON_SIZE + SPACING), 0)
    end
end

local function RefreshDuration(id)
    local cooldown = tracked[id].cooldown
    local duration = C_UnitAuras.GetAuraDuration("player", id)
    -- Un sello sin duracion (permanente hasta cambiarlo, como en MoP) va sin
    -- temporizador: uno de 0 s acabaria al momento y quitaria el icono.
    local isZero = duration:IsZero()
    if Readable(isZero) and isZero then
        cooldown:Clear()
    else
        cooldown:SetCooldownFromDurationObject(duration)
    end
end

local function Track(aura)
    local id = aura.auraInstanceID
    if not Readable(id) then return end
    if not tracked[id] then
        local icon = AcquireIcon()
        icon.auraInstanceID = id
        tracked[id] = icon
        order[#order + 1] = id
    end
    tracked[id].texture:SetTexture(aura.icon)
    RefreshDuration(id)
end

Untrack = function(id)
    local icon = tracked[id]
    if not icon then return end
    icon:Hide()
    icon.auraInstanceID = nil
    pool[#pool + 1] = icon
    tracked[id] = nil
    for i = #order, 1, -1 do
        if order[i] == id then table.remove(order, i) end
    end
end

-- ponytail: con un aura secreta en una actualizacion completa (login, cambio de
-- zona en combate) ese sello no se ve hasta que se vuelva a lanzar.
local function FullScan()
    for i = #order, 1, -1 do Untrack(order[i]) end
    for _, aura in ipairs(C_UnitAuras.GetUnitAuras("player", "HELPFUL") or {}) do
        if IsSeal(aura.name) then Track(aura) end
    end
    Layout()
end

local function OnUnitAura(info)
    if not info or info.isFullUpdate then return FullScan() end
    for _, aura in ipairs(info.addedAuras or {}) do
        if IsSeal(aura.name) then Track(aura) end
    end
    for _, id in ipairs(info.updatedAuraInstanceIDs or {}) do
        if Readable(id) and tracked[id] then RefreshDuration(id) end
    end
    for _, id in ipairs(info.removedAuraInstanceIDs or {}) do
        if Readable(id) then Untrack(id) end
    end
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
    for _, spellID in ipairs(SEAL_SPELLS) do
        local name = C_Spell.GetSpellName(spellID)
        if not name then
            print("  " .. L.CHECK_MISSING:format(spellID))
        elseif C_Secrets.ShouldSpellAuraBeSecret(spellID) then
            print("  " .. L.CHECK_SECRET:format(name))
        else
            print("  " .. L.CHECK_OPEN:format(name))
        end
    end
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
frame:SetScript("OnEvent", function(self, event, unit, info)
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
        BuildSealNames()
        CreateAnchor()
        CreateOptions()
        self:RegisterUnitEvent("UNIT_AURA", "player")
        FullScan()
    elseif event == "UNIT_AURA" then
        OnUnitAura(info)
    end
end)
