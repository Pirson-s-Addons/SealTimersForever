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
-- Twist de sellos (estilo de los WeakAuras de TBC): una barra de golpe con la
-- zona de twist al final. PLAYER_SWING (C_SwingTimer) no es secreto, asi que
-- funciona en combate. En Forever el twist va con el "Eco": solo Orden,
-- Rectitud, Furia y Justicia lo dejan. El registro de combate si esta
-- restringido, asi que el acierto del twist se deduce (cambio de sello con Eco
-- entre dos golpes), no se lee del dano.
-- Contrastado con Gethe/wow-ui-source, rama "forever".

local _, ns = ...
local L = ns.L

-- Rango 1 de cada sello clasico (Rectitud, Cruzado, Luz, Sabiduria, Justicia y
-- Orden): sirven para pedir al cliente sus nombres en el idioma del jugador y
-- sacar el prefijo comun ("Sello de", "Seal of"...). Los sellos nuevos de
-- Forever (p. ej. Sello de Furia) entran por ese prefijo y por el libro de
-- hechizos, sin saber su ID.
local SEAL_SPELLS = { 21084, 21082, 20165, 20166, 20164, 20375 }
-- Sellos SIN Eco en Forever (Cruzado, Luz y Sabiduria): el resto, incluidos
-- los nuevos como el Sello de Furia, se pueden twistear.
local NO_ECHO_SPELLS = { 21082, 20165, 20166 }
-- Ecos del talento Twist of Light (Furia, Orden, Rectitud, Justicia): auras
-- propias sin duracion que consume el siguiente golpe. Solo para /stf debug.
local ECHO_SPELLS = { 1311701, 1311703, 1311704, 1311705 }
-- Muestra para colocar las cosas: Rectitud en el bloque; Rectitud y Orden
-- (golpe con twist) en el icono de golpe
local DEMO_SEAL, DEMO_HITS = 21084, { 21084, 20375 }
local HOLY = 2

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
local DEFAULTS = {
    locked = true, scale = 1, point = "CENTER", x = 0, y = -150,
    twistEnabled = true, swingBar = true, twistGlow = true, twistWindow = 0.4, twistSound = true,
    -- Icono en cada golpe: donde lo tenia el WeakAura (encima del objetivo)
    hitIcon = true, hitPoint = "CENTER", hitX = 60, hitY = 175,
}
-- Barra de golpe como la del WeakAura de Kaedin: encima del sello, amarilla
-- sobre azul oscuro, con el tiempo que queda en el centro y dos lineas.
local SWING_WIDTH, SWING_HEIGHT = 200, 14
-- Tiempo global de reutilizacion: la linea roja marca el ultimo momento para
-- usar una habilidad con GCD sin pisar la ventana de twist.
-- ponytail: fijo en 1,5 s; si Forever aplica celeridad al GCD, habria que leerlo.
local GCD = 1.5
-- Cuanto se ve el icono de cada golpe (como el WeakAura: 1,5 s)
local HIT_DURATION = 1.5
local HIT_SIZE = 36
local MAIN_HAND = Enum.PlayerSwingType and Enum.PlayerSwingType.MainHand or 0
-- Sube cuando cambia como se aprenden las duraciones: las viejas se descartan
-- (la 1: las antiguas podian ser la de un eco, mucho mas corta).
local DURATIONS_VERSION = 1
local EMPTY = {}

local db
local sealNames, sealPrefix = {}, nil
local knownSeals = {}          -- spellID del libro de hechizos -> nombre del sello
local icons, order, pool = {}, {}, {}  -- nombre del sello -> icono
local activeSeal               -- nombre del ultimo sello lanzado (o elegido al releer)
local noEcho = {}              -- nombres de los sellos sin Eco
local swingStart, swingDuration
local sealAtLastSwing          -- sello activo cuando cayo el ultimo golpe
local swingBar
local hitAnchor, hitIcons = nil, {}
local sealTextures = {}        -- nombre del sello -> ultima textura vista
local debugMode = false
local echoNames, echoIDs = {}, {}  -- /stf debug: nombre de cada Eco; auraInstanceID -> nombre
local previewing = false       -- pestana Posicion abierta: se ve la muestra
local anchor

-- Se ensena la muestra: desbloqueado o con la pestana Posicion abierta
local function Demo()
    return previewing or not db.locked
end

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
    for _, spellID in ipairs(NO_ECHO_SPELLS) do
        local name = C_Spell.GetSpellName(spellID)
        if name then noEcho[name] = true end
    end
    for _, spellID in ipairs(ECHO_SPELLS) do
        local name = C_Spell.GetSpellName(spellID)
        if name then echoNames[name] = true end
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

local function HasEcho(name)
    return name ~= nil and not noEcho[name]
end

-- Solo por ID, nunca por nombre: el dano del Sello de Orden (y otros efectos
-- del sello) se llama igual que el sello y tambien lanza UNIT_SPELLCAST_SUCCEEDED,
-- asi que por nombre cada golpe con efecto reiniciaba el contador.
local function SealNameForSpell(spellID)
    if not Readable(spellID) then return nil end
    if knownSeals[spellID] then return knownSeals[spellID] end
    if tContains(SEAL_SPELLS, spellID) then return C_Spell.GetSpellName(spellID) end
    return nil
end

--------------------------------------------------
-- ICONOS (uno por sello, por nombre)
--------------------------------------------------
local HideSeal, Layout

-- Segundos truncados, como el tiempo del bufo de Blizzard (su formateador usa
-- Truncate). El contador del Cooldown redondea hacia arriba y marcaba 1 s mas.
local truncSeconds
if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
    truncSeconds = C_StringUtil.CreateNumericRuleFormatter()
    truncSeconds:SetBreakpoints({ { threshold = 0, step = 1,
        rounding = Enum.NumericRuleFormatRounding.Down, format = "%d" } })
end

local function TruncateCountdown(cooldown)
    if truncSeconds then pcall(cooldown.SetCountdownFormatter, cooldown, truncSeconds) end
end

-- Icono con cuenta atras grande y amarilla, como la de OmniCC en los WeakAuras
local function BuildIcon(parent, size, fontSize)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(size, size)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    icon.cooldown:SetReverse(true)
    icon.cooldown:SetDrawEdge(false)
    icon.cooldown:SetHideCountdownNumbers(false)
    local countdown = icon.cooldown:GetCountdownFontString()
    countdown:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    countdown:SetTextColor(1, 0.82, 0)
    return icon
end

local function AcquireIcon()
    local icon = table.remove(pool)
    if not icon then
        icon = BuildIcon(anchor, ICON_SIZE, 18)
        TruncateCountdown(icon.cooldown)
        -- Brillo de "cambia de sello ya" (zona de twist)
        icon.glow = icon:CreateTexture(nil, "OVERLAY")
        icon.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        icon.glow:SetBlendMode("ADD")
        icon.glow:SetVertexColor(1, 0.82, 0)
        icon.glow:SetPoint("CENTER")
        icon.glow:SetSize(ICON_SIZE * 1.8, ICON_SIZE * 1.8)
        icon.glow:Hide()
        -- Se acabo el tiempo: el sello expiro (tambien cubre retiradas que
        -- llegaron secretas y no se pudieron leer).
        icon.cooldown:SetScript("OnCooldownDone", function(self)
            local parent = self:GetParent()
            if parent.hasTimer and parent.sealName then
                HideSeal(parent.sealName)
                Layout()
            end
        end)
    end
    icon:Show()
    return icon
end

-- Sello de muestra en el bloque mientras se coloca, si no hay ninguno de verdad
local function UpdateSealDemo()
    local demo = anchor.demo
    local show = Demo() and #order == 0
    if show and not demo:IsShown() then demo.cooldown:SetCooldown(GetTime(), DEFAULT_DURATION) end
    demo:SetShown(show)
end

Layout = function()
    for i, name in ipairs(order) do
        local icon = icons[name]
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", anchor, "LEFT", (i - 1) * (ICON_SIZE + SPACING), 0)
    end
    UpdateSealDemo()
end

local function ShowSeal(name, texture)
    local icon = icons[name]
    if not icon then
        icon = AcquireIcon()
        icon.sealName = name
        icons[name] = icon
        order[#order + 1] = name
    end
    if Readable(texture) then
        icon.texture:SetTexture(texture)
        sealTextures[name] = texture
    end
    return icon
end

HideSeal = function(name)
    local icon = icons[name]
    if not icon then return end
    icon:Hide()
    icon.glow:Hide()
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

-- En combate no se puede preguntar: GetAuraDataByAuraInstanceID da error
-- ("Auras cannot be accessed when secret while tainted"). Se da por buena y al
-- salir de combate FullScan relee todo.
local function AuraExists(id)
    if C_Secrets.ShouldAurasBeSecret() then return true end
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
-- Solo fuera de combate: en combate el aura puede ser secreta o haber cambiado
-- de ID tras relanzar, y consultarla podria fallar.
local function LearnFromAura(name, id)
    if C_Secrets.ShouldAurasBeSecret() or not AuraExists(id) then return end
    local duration = C_UnitAuras.GetAuraDuration("player", id)
    if not duration or duration:HasSecretValues() or duration:IsZero() then return end
    Learn(name, duration:GetTotalDuration())
end

local function StartTimer(name)
    local icon = icons[name]
    if not icon then return end
    local cooldown = icon.cooldown
    if icon.castAt then
        -- Lanzado por el jugador: su duracion desde el lanzamiento. Relanzar un
        -- sello lo renueva entero, asi que es exacto y no depende de nada secreto.
        -- El temporizador va PRIMERO: nada de lo que venga despues puede
        -- impedir que un relanzamiento lo reinicie.
        cooldown:SetCooldown(icon.castAt, SealDuration(name))
        icon.hasTimer = true
        Debug(("%s: %.1f s desde el lanzamiento"):format(name, SealDuration(name)))
        if icon.auraInstanceID then LearnFromAura(name, icon.auraInstanceID) end
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
    -- Justo al salir de combate (o tras /reload en combate) las auras aun son
    -- secretas y GetUnitAuras da error: se deja todo como esta y se reintenta.
    local ok, auras = pcall(C_UnitAuras.GetUnitAuras, "player", "HELPFUL")
    if not ok then
        Debug("auras aun secretas: se relee en 0,5 s")
        C_Timer.After(0.5, FullScan)
        return
    end
    -- HideSeal borra el sello activo y cuando se lanzo: se guardan antes
    local wanted = activeSeal
    local wantedCastAt = wanted and icons[wanted] and icons[wanted].castAt
    for i = #order, 1, -1 do HideSeal(order[i]) end
    local best, bestTotal
    for _, aura in ipairs(List(auras)) do
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

-- /stf debug: aparece un Eco de Twist of Light (si su aura se puede leer)
local function DebugEcho(aura)
    local name, id = aura.name, aura.auraInstanceID
    if not Readable(name) or not echoNames[name] then return end
    if Readable(id) then echoIDs[id] = name end
    Debug("eco: " .. name)
end

-- /stf debug: dano que recibe el objetivo (UNIT_COMBAT), para ver si el del
-- sello llega aparte y legible. Sagrado (2) justo tras el golpe = sello o Eco.
local function DebugUnitCombat(action, amount, school)
    if not debugMode then return end
    if IsSecret(action) or IsSecret(amount) or IsSecret(school) then
        Debug("objetivo: UNIT_COMBAT secreto")
        return
    end
    local since = swingStart and ("%.2f s tras tu golpe"):format(GetTime() - swingStart) or "sin golpe"
    Debug(("objetivo: %s %s, escuela %s%s, %s"):format(tostring(action), tostring(amount),
        tostring(school), school == HOLY and " (Sagrado)" or "", since))
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
    for _, aura in ipairs(List(info.addedAuras)) do
        if debugMode then DebugEcho(aura) end
        TrackAura(aura)
    end
    for _, id in ipairs(List(info.removedAuraInstanceIDs)) do
        if Readable(id) and echoIDs[id] then
            Debug("eco consumido: " .. echoIDs[id])
            echoIDs[id] = nil
        end
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
    -- El contador se reinicia ANTES de tocar ninguna aura: en combate el aura
    -- vieja puede ser secreta o haber desaparecido, y si consultarla falla
    -- (error oculto) el relanzamiento no reiniciaria nada.
    StartTimer(name)
    Layout()
    -- El aura se renueva justo despues del lanzamiento: se relee entonces
    C_Timer.After(RECAST_REFRESH, function()
        if icons[name] then
            RefreshTracked()
            Layout()
        end
    end)
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
end

--------------------------------------------------
-- TEMPORIZADOR DE GOLPE Y TWIST
--------------------------------------------------
local function SetGlow(on, pulse)
    for name, icon in pairs(icons) do
        local show = on and name == activeSeal
        icon.glow:SetShown(show)
        if show then icon.glow:SetAlpha(pulse) end
    end
end

-- Lineas sobre la barra: roja = ultimo GCD (GCD s antes del golpe), verde =
-- empieza la ventana de twist (twistWindow s antes del golpe)
local function PlaceTick(tick, secondsBeforeSwing)
    local fraction = (swingDuration - secondsBeforeSwing) / swingDuration
    tick:SetShown(fraction > 0)
    if fraction > 0 then
        tick:ClearAllPoints()
        tick:SetPoint("TOP", swingBar, "TOPLEFT", SWING_WIDTH * fraction, 0)
        tick:SetPoint("BOTTOM", swingBar, "BOTTOMLEFT", SWING_WIDTH * fraction, 0)
    end
end

local function UpdateTicks()
    if not swingDuration or swingDuration <= 0 then return end
    PlaceTick(swingBar.gcdTick, GCD)
    PlaceTick(swingBar.twistTick, db.twistWindow)
end

-- El reloj del golpe va en el bloque (siempre visible), no en la barra: asi el
-- parpadeo funciona aunque la barra este desactivada.
local function OnSwingUpdate()
    if not swingStart then return end
    local elapsed = GetTime() - swingStart
    -- Sin golpes un rato (fin del combate, sin objetivo): se esconde
    if elapsed > swingDuration + 1 then
        swingStart = nil
        SetGlow(false)
        if not Demo() then swingBar:Hide() end
        return
    end
    if swingBar:IsShown() then
        swingBar:SetValue(math.min(elapsed / swingDuration, 1))
        swingBar.text:SetFormattedText("%.1f", math.max(swingDuration - elapsed, 0))
    end
    local inWindow = elapsed >= swingDuration - db.twistWindow and elapsed <= swingDuration
    SetGlow(db.twistEnabled and db.twistGlow and inWindow and HasEcho(activeSeal),
        0.55 + 0.45 * math.sin(GetTime() * 14))
end

local function ApplySwingBar()
    -- Al colocarla (Demo) se ensena aunque no haya golpes
    local show = db.twistEnabled and db.swingBar and (swingStart ~= nil or Demo())
    swingBar:SetShown(show)
    if Demo() and not swingStart then
        swingDuration = swingDuration or 3.5
        UpdateTicks()
        swingBar:SetValue(0.7)
        swingBar.text:SetText("1.0")
    end
    if not (db.twistEnabled and db.twistGlow) then SetGlow(false) end
end

local function Tick(r, g, b)
    local tick = swingBar:CreateTexture(nil, "OVERLAY")
    tick:SetWidth(2)
    tick:SetColorTexture(r, g, b, 1)
    return tick
end

local function CreateSwingBar()
    swingBar = CreateFrame("StatusBar", nil, anchor)
    swingBar:SetSize(SWING_WIDTH, SWING_HEIGHT)
    swingBar:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
    swingBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    swingBar:SetStatusBarColor(0.8, 0.75, 0.05)
    swingBar:SetMinMaxValues(0, 1)
    swingBar.bg = swingBar:CreateTexture(nil, "BACKGROUND")
    swingBar.bg:SetAllPoints()
    swingBar.bg:SetColorTexture(0.1, 0.1, 0.45, 0.9)
    swingBar.gcdTick = Tick(1, 0.1, 0.1)
    swingBar.twistTick = Tick(0.1, 1, 0.1)
    swingBar.text = swingBar:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    swingBar.text:SetPoint("CENTER")
    swingBar:Hide()
    anchor:SetScript("OnUpdate", OnSwingUpdate)
end

-- Iconos de golpe: el sello activo y, si el golpe aplica un twist, tambien el
-- anterior (el Eco), con HIT_DURATION s de cuenta atras.
local ApplyHitAnchor

local function CreateHitIcon(index)
    local hit = BuildIcon(hitAnchor, HIT_SIZE, 16)
    hit:SetPoint("LEFT", hitAnchor, "LEFT", (index - 1) * (HIT_SIZE + SPACING), 0)
    hit.cooldown:SetScript("OnCooldownDone", function(self)
        self:GetParent():Hide()
        -- Colocandolo, tras un golpe de verdad vuelve la muestra
        if Demo() then ApplyHitAnchor() end
    end)
    hit:Hide()
    return hit
end

local function ShowHits(names)
    for i = 1, #hitIcons do hitIcons[i]:Hide() end
    for i, name in ipairs(names) do
        local hit = hitIcons[i]
        hit.texture:SetTexture(sealTextures[name] or "Interface\\Icons\\INV_Misc_QuestionMark")
        hit.cooldown:SetCooldown(GetTime(), HIT_DURATION)
        hit:Show()
    end
end

ApplyHitAnchor = function()
    local enabled = db.twistEnabled and db.hitIcon
    local demo = enabled and Demo()
    hitAnchor:EnableMouse(enabled and not db.locked)
    hitAnchor.bg:SetShown(demo)
    hitAnchor.label:SetShown(demo)
    -- Muestra: un golpe con twist (sello activo y su Eco), sin cuenta atras
    for i, hit in ipairs(hitIcons) do
        if demo then
            hit.texture:SetTexture(C_Spell.GetSpellTexture(DEMO_HITS[i]))
            hit.cooldown:Clear()
        end
        hit:SetShown(demo)
    end
end

local function CreateHitAnchor()
    hitAnchor = CreateFrame("Frame", "SealTimersForeverHitAnchor", UIParent)
    hitAnchor:SetSize(HIT_SIZE, HIT_SIZE)
    hitAnchor:SetPoint(db.hitPoint, UIParent, db.hitPoint, db.hitX, db.hitY)
    hitAnchor:SetMovable(true)
    hitAnchor:SetClampedToScreen(true)
    hitAnchor:RegisterForDrag("LeftButton")
    hitAnchor:SetScript("OnDragStart", hitAnchor.StartMoving)
    hitAnchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.hitPoint, db.hitX, db.hitY = point, x, y
        if ns.RefreshOptions then ns.RefreshOptions() end
    end)
    hitAnchor.bg = hitAnchor:CreateTexture(nil, "BACKGROUND")
    hitAnchor.bg:SetAllPoints()
    hitAnchor.bg:SetColorTexture(0.84, 0.59, 1, 0.35)
    hitAnchor.label = hitAnchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hitAnchor.label:SetPoint("BOTTOM", hitAnchor, "TOP", 0, 2)
    hitAnchor.label:SetText(BRAND .. L.HIT_ICON .. "|r - " .. L.DRAG_HINT)
    hitIcons[1], hitIcons[2] = CreateHitIcon(1), CreateHitIcon(2)
    ApplyHitAnchor()
end

local function OnSwing(duration, swingType)
    if swingType ~= MAIN_HAND or not Readable(duration) or duration <= 0 then return end
    -- Twist acertado: entre el golpe anterior y este se cambio desde un sello
    -- con Eco, asi que este golpe aplica el sello anterior ademas del nuevo.
    local twisted = sealAtLastSwing and activeSeal and activeSeal ~= sealAtLastSwing
        and HasEcho(sealAtLastSwing)
    if twisted then
        Debug(("twist: %s -> %s"):format(sealAtLastSwing, activeSeal))
        if db.twistEnabled and db.twistSound then PlaySound(SOUNDKIT.MAP_PING) end
    end
    if db.twistEnabled and db.hitIcon and activeSeal then
        ShowHits(twisted and { activeSeal, sealAtLastSwing } or { activeSeal })
    end
    sealAtLastSwing = activeSeal
    swingStart, swingDuration = GetTime(), duration
    UpdateTicks()
    ApplySwingBar()
end

--------------------------------------------------
-- BLOQUE MOVIL
--------------------------------------------------
-- Arrastrar solo desbloqueado; el fondo, el rotulo y la muestra tambien con la
-- pestana Posicion abierta
local function ApplyLock()
    anchor:EnableMouse(not db.locked)
    anchor.bg:SetShown(Demo())
    anchor.label:SetShown(Demo())
    UpdateSealDemo()
    if swingBar then ApplySwingBar() end
    if hitAnchor then ApplyHitAnchor() end
end

local function SetPreview(on)
    previewing = on
    ApplyLock()
end

-- Posicion al pixel (pestana Posicion). Los deslizadores van en pixeles de
-- pantalla desde el centro; db guarda el punto en la escala del bloque, como
-- al arrastrar.
local POSITIONS = {
    seals = { point = "point", x = "x", y = "y", frame = function() return anchor end },
    hit = { point = "hitPoint", x = "hitX", y = "hitY", frame = function() return hitAnchor end },
}

local function Round(value) return math.floor(value + 0.5) end

local function Place(pos)
    local f = pos.frame()
    f:ClearAllPoints()
    f:SetPoint(db[pos.point], UIParent, db[pos.point], db[pos.x], db[pos.y])
end

local function GetOffset(what)
    local pos, scale = POSITIONS[what], db.scale
    if db[pos.point] == "CENTER" then return Round(db[pos.x] * scale), Round(db[pos.y] * scale) end
    -- Arrastrado (otro punto de anclaje): se mide donde quedo
    local x, y = pos.frame():GetCenter()
    if not x then return 0, 0 end -- ponytail: sin colocar aun, sale en 0
    local cx, cy = UIParent:GetCenter()
    return Round(x * scale - cx), Round(y * scale - cy)
end

local function SetOffset(what, x, y)
    local pos, scale = POSITIONS[what], db.scale
    local ox, oy = GetOffset(what)
    db[pos.point], db[pos.x], db[pos.y] = "CENTER", (x or ox) / scale, (y or oy) / scale
    Place(pos)
end

local function ResetPositions()
    for _, pos in pairs(POSITIONS) do
        db[pos.point], db[pos.x], db[pos.y] = DEFAULTS[pos.point], DEFAULTS[pos.x], DEFAULTS[pos.y]
        Place(pos)
    end
end

local function ApplyScale()
    anchor:SetScale(db.scale)
    if hitAnchor then hitAnchor:SetScale(db.scale) end
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
        if ns.RefreshOptions then ns.RefreshOptions() end
    end)

    -- Solo se ven desbloqueado: marcan donde va el bloque aunque no haya sellos
    anchor.bg = anchor:CreateTexture(nil, "BACKGROUND")
    anchor.bg:SetAllPoints()
    anchor.bg:SetColorTexture(0.84, 0.59, 1, 0.35)
    anchor.label = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    anchor.label:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
    anchor.label:SetText(BRAND .. L.TITLE .. "|r - " .. L.DRAG_HINT)
    -- Sello de muestra: vuelve a empezar al acabar mientras se coloca
    anchor.demo = BuildIcon(anchor, ICON_SIZE, 18)
    TruncateCountdown(anchor.demo.cooldown)
    anchor.demo:SetPoint("LEFT", anchor, "LEFT", 0, 0)
    anchor.demo.texture:SetTexture(C_Spell.GetSpellTexture(DEMO_SEAL))
    anchor.demo.cooldown:SetScript("OnCooldownDone", function(self)
        self:SetCooldown(GetTime(), DEFAULT_DURATION)
    end)
    anchor.demo:Hide()

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

-- El panel vive en UI/Options.lua; aqui solo se le pasa lo que necesita
local function CreateOptions()
    local category = ns.CreateOptions({
        db = db, defaults = DEFAULTS,
        ApplyLock = ApplyLock, ApplyScale = ApplyScale, ApplySwingBar = ApplySwingBar,
        ApplyHitAnchor = ApplyHitAnchor, UpdateTicks = UpdateTicks,
        SetPreview = SetPreview, GetOffset = GetOffset, SetOffset = SetOffset,
        ResetPositions = ResetPositions,
    })

    SLASH_SEALTIMERSFOREVER1 = "/stf"
    SlashCmdList.SEALTIMERSFOREVER = function(msg)
        local command = (msg or ""):lower():match("^%s*(%S*)")
        if command == "check" then return Check() end
        if command == "debug" then
            debugMode = not debugMode
            print(BRAND .. "Seal Timers Forever|r: " .. (debugMode and L.DEBUG_ON or L.DEBUG_OFF))
            -- Si el juego marca los Ecos como secretos en combate
            for _, spellID in ipairs(ECHO_SPELLS) do
                Debug(("eco %s (%d): %s en combate"):format(C_Spell.GetSpellName(spellID) or "?", spellID,
                    C_Secrets.ShouldSpellAuraBeSecret(spellID) and "secreto" or "legible"))
            end
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
frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4, arg5)
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
        CreateSwingBar()
        ApplySwingBar()
        CreateHitAnchor()
        ApplyScale()
        CreateOptions()
        self:RegisterUnitEvent("UNIT_AURA", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("SPELLS_CHANGED")
        self:RegisterEvent("PLAYER_SWING")
        self:RegisterUnitEvent("UNIT_COMBAT", "target")
        FullScan()
    elseif event == "UNIT_AURA" then
        OnUnitAura(arg2)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSealCast(arg3)
    elseif event == "PLAYER_SWING" then
        OnSwing(arg1, arg2)
    elseif event == "UNIT_COMBAT" then
        DebugUnitCombat(arg2, arg4, arg5)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Fuera de combate el siguiente golpe no cuenta como twist
        sealAtLastSwing = nil
        FullScan()
    elseif event == "SPELLS_CHANGED" then
        ScanSpellBook()
    end
end)
