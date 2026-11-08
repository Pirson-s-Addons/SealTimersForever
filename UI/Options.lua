local ADDON_NAME, ns = ...
local L = ns.L

-- ==========================================
-- OPCIONES
-- ==========================================
-- Raiz "Acerca de" (UI/About.lua) y, colgando de ella, "General" con los
-- ajustes, "Aviso" (brillo al acabarse el sello) y "Posicion" para colocar cada cosa al pixel (como DR Tracker
-- Forever): paneles propios con la plantilla de todos los addons de Pirson
-- (titulo, logo con version, secciones en morado y "Valores por defecto").

local HEADER = "|cffC47FF3"
local LOGO = "Interface\\AddOns\\SealTimersForever\\img\\logo_stf"
local X = 16
-- Lo que devuelve "Valores por defecto": los ajustes del panel, no la posicion
local PANEL_KEYS = { "locked", "scale", "twistEnabled", "swingBar", "twistGlow", "twistWindow", "twistSound", "hitIcon" }
-- Los de la pagina Aviso
local ALERT_KEYS = { "expireGlow", "expireStyle", "expireTime", "expireIntensity" }

local function AddTooltip(widget, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Header(panel, y, text)
    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", X, y)
    fs:SetText(HEADER .. text .. "|r")
end

local function Separator(panel, y)
    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.1)
    line:SetSize(580, 1)
    line:SetPoint("TOPLEFT", X, y)
end

-- Panel con titulo y logo con la version, oculto hasta que se abra
local function NewPanel()
    local panel = CreateFrame("Frame")
    panel:Hide() -- nace oculto: si no, el Show() al abrir la categoria no dispara OnShow

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", X, -16)
    title:SetText(L.OPTIONS_TITLE)

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(110, 110)
    logo:SetPoint("TOPRIGHT", -38, -5)
    logo:SetTexture(LOGO)

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOP", logo, "BOTTOM", 0, -2)
    version:SetText("v" .. (C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"))
    return panel
end

local function ResetButton(panel, y, onClick)
    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(180, 26)
    reset:SetPoint("TOPLEFT", X, y)
    reset:SetText(L.DEFAULTS)
    reset:SetScript("OnClick", onClick)
end

local refreshers = {}

-- Al arrastrar algo con la pestana Posicion abierta, los deslizadores lo siguen
function ns.RefreshOptions()
    for panel, refresh in pairs(refreshers) do
        if panel:IsVisible() then refresh() end
    end
end

-- api: { db, defaults, ApplyLock, ApplyScale, ApplySwingBar, ApplyHitAnchor, UpdateTicks,
--        SetPreview, GetOffset, SetOffset, ResetPositions, CreateAlertPreview, UpdateExpireGlow }
-- Devuelve la subcategoria General (destino de /stf).
function ns.CreateOptions(api)
    local db = api.db
    local widgets, children = {}, {}

    local function Checkbox(panel, key, label, tooltip, x, y, onChange)
        local cb = CreateFrame("CheckButton", "SealTimersForever_" .. key, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        _G[cb:GetName() .. "Text"]:SetText(label)
        cb:SetScript("OnClick", function(self)
            db[key] = self:GetChecked() and true or false
            if onChange then onChange() end
        end)
        AddTooltip(cb, tooltip)
        cb.Refresh = function(self) self:SetChecked(db[key]) end
        widgets[#widgets + 1] = cb
        return cb
    end

    -- key: un ajuste de db, o { name, get, set } para lo que no se guarda tal cual
    local function Slider(panel, key, label, tooltip, x, y, min, max, step, format, onChange)
        local get = type(key) == "table" and key.get or function() return db[key] end
        local set = type(key) == "table" and key.set or function(value) db[key] = value end
        local slider = CreateFrame("Slider", "SealTimersForever_" .. (type(key) == "table" and key.name or key),
            panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", x + 10, y)
        slider:SetWidth(400)
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        local name = slider:GetName()
        _G[name .. "Low"]:SetText(format(min))
        _G[name .. "High"]:SetText(format(max))
        local function Label() _G[name .. "Text"]:SetText(label .. ": " .. format(get())) end
        slider:SetScript("OnValueChanged", function(_, value)
            value = math.floor(value / step + 0.5) * step
            if value == get() then return end
            set(value)
            Label()
            if onChange then onChange() end
        end)
        AddTooltip(slider, tooltip)
        slider.Refresh = function(self)
            self:SetValue(get())
            Label()
        end
        widgets[#widgets + 1] = slider
        return slider
    end

    local function Refresh()
        for _, widget in ipairs(widgets) do widget:Refresh() end
    end

    -- Las opciones de twist cuelgan del interruptor: apagado, se ven desactivadas
    local function UpdateChildren()
        for _, widget in ipairs(children) do
            widget:SetEnabled(db.twistEnabled)
            widget:SetAlpha(db.twistEnabled and 1 or 0.5)
        end
    end

    --------------------------------------------------
    -- GENERAL
    --------------------------------------------------
    local panel = NewPanel()

    -- General: bloqueo y tamano del bloque
    Header(panel, -56, L.GENERAL_HEADER)
    Checkbox(panel, "locked", L.LOCK, L.LOCK_TOOLTIP, X, -81, api.ApplyLock)
    Slider(panel, "scale", L.SIZE, L.SIZE_TOOLTIP, X, -135, 0.5, 3, 0.1, function(value)
        return string.format("%d%%", math.floor(value * 100 + 0.5))
    end, api.ApplyScale)
    Separator(panel, -180)

    -- Seal twisting: un interruptor general y, colgando de el, sus opciones
    Header(panel, -200, L.TWIST_HEADER)
    Checkbox(panel, "twistEnabled", L.TWIST_ENABLED, L.TWIST_ENABLED_TOOLTIP, X, -225, function()
        api.ApplySwingBar()
        api.ApplyHitAnchor()
        UpdateChildren()
    end)
    local cx = X + 20
    children[#children + 1] = Checkbox(panel, "swingBar", L.SWING_BAR, L.SWING_BAR_TOOLTIP, cx, -255, api.ApplySwingBar)
    children[#children + 1] = Checkbox(panel, "twistGlow", L.TWIST_GLOW, L.TWIST_GLOW_TOOLTIP, cx, -285, api.ApplySwingBar)
    children[#children + 1] = Slider(panel, "twistWindow", L.TWIST_WINDOW, L.TWIST_WINDOW_TOOLTIP, cx, -335, 0.1, 1, 0.1,
        function(value) return string.format("%.1f s", value) end, api.UpdateTicks)
    children[#children + 1] = Checkbox(panel, "twistSound", L.TWIST_SOUND, L.TWIST_SOUND_TOOLTIP, cx, -370, nil)
    children[#children + 1] = Checkbox(panel, "hitIcon", L.HIT_ICON, L.HIT_ICON_TOOLTIP, cx, -400, api.ApplyHitAnchor)
    Separator(panel, -440)

    panel:SetScript("OnShow", function()
        Refresh()
        UpdateChildren()
    end)

    ResetButton(panel, -460, function()
        for _, key in ipairs(PANEL_KEYS) do db[key] = api.defaults[key] end
        api.ApplyLock()
        api.ApplyScale()
        api.ApplySwingBar()
        api.ApplyHitAnchor()
        api.UpdateTicks()
        Refresh()
        UpdateChildren()
    end)

    --------------------------------------------------
    -- AVISO: brillo cuando el sello se acaba, con vista previa en vivo
    --------------------------------------------------
    local alert = NewPanel()
    local alertChildren = {}
    local function UpdateAlertChildren()
        for _, widget in ipairs(alertChildren) do
            widget:SetEnabled(db.expireGlow)
            widget:SetAlpha(db.expireGlow and 1 or 0.5)
        end
    end
    Header(alert, -56, L.ALERT_HEADER)
    Checkbox(alert, "expireGlow", L.EXPIRE_GLOW, L.EXPIRE_GLOW_TOOLTIP, X, -81, UpdateAlertChildren)

    local styles = {
        { "pulse", L.ALERT_PULSE }, { "steady", L.ALERT_STEADY },
        { "flash", L.ALERT_FLASH }, { "proc", L.ALERT_PROC },
    }
    local styleLabel = alert:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    styleLabel:SetPoint("TOPLEFT", cx, -122)
    styleLabel:SetText(L.ALERT_STYLE)
    local style = CreateFrame("Frame", "SealTimersForever_expireStyle", alert, "UIDropDownMenuTemplate")
    style:SetPoint("LEFT", styleLabel, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(style, 200)
    AddTooltip(style, L.ALERT_STYLE_TOOLTIP)
    local function StyleText()
        for _, item in ipairs(styles) do
            if item[1] == db.expireStyle then return item[2] end
        end
    end
    UIDropDownMenu_Initialize(style, function()
        for _, item in ipairs(styles) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item[2]
            info.checked = db.expireStyle == item[1]
            info.func = function()
                db.expireStyle = item[1]
                UIDropDownMenu_SetText(style, item[2])
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    style.Refresh = function(self) UIDropDownMenu_SetText(self, StyleText()) end
    style.SetEnabled = function(self, on)
        if on then UIDropDownMenu_EnableDropDown(self) else UIDropDownMenu_DisableDropDown(self) end
    end
    widgets[#widgets + 1] = style
    alertChildren[1] = style
    alertChildren[2] = Slider(alert, "expireTime", L.EXPIRE_TIME, L.EXPIRE_TIME_TOOLTIP, cx, -175, 1, 15, 1,
        function(value) return string.format("%d s", value) end)
    alertChildren[3] = Slider(alert, "expireIntensity", L.ALERT_INTENSITY, L.ALERT_INTENSITY_TOOLTIP, cx, -225, 0.25, 1, 0.05,
        function(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end)

    -- Vista previa: un sello que cuenta el umbral + 2 s en bucle, para ver
    -- como entra el aviso con el tipo y la intensidad elegidos
    local previewLabel = alert:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOPLEFT", 490, -160)
    previewLabel:SetText(L.PREVIEW)
    local preview = api.CreateAlertPreview(alert, 56)
    preview:SetPoint("TOP", previewLabel, "BOTTOM", 0, -22)
    local previewStart, previewLength = 0, 0
    alert:SetScript("OnUpdate", function()
        local now = GetTime()
        if now >= previewStart + previewLength then
            previewStart, previewLength = now, db.expireTime + 2
            preview.cooldown:SetCooldown(previewStart, previewLength)
        end
        api.UpdateExpireGlow(preview, previewStart + previewLength, now)
    end)
    Separator(alert, -275)

    alert:SetScript("OnShow", function()
        previewLength = 0 -- la vista previa empieza de cero al abrir
        Refresh()
        UpdateAlertChildren()
    end)

    ResetButton(alert, -295, function()
        for _, key in ipairs(ALERT_KEYS) do db[key] = api.defaults[key] end
        previewLength = 0
        Refresh()
        UpdateAlertChildren()
    end)

    --------------------------------------------------
    -- POSICION: elegir que mover y moverlo al pixel, viendo la muestra
    --------------------------------------------------
    local position = NewPanel()
    Header(position, -56, L.POSITION_HEADER)
    local hint = position:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", X, -78)
    hint:SetWidth(440)
    hint:SetJustifyH("LEFT")
    hint:SetText(L.POS_HINT)

    local editing = "seals"
    local objects = { { "seals", L.POS_SEALS }, { "hit", L.HIT_ICON } }
    local label = position:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", X, -116)
    label:SetText(L.POS_OBJECT)
    local dropdown = CreateFrame("Frame", "SealTimersForever_posObject", position, "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", label, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(dropdown, 220)
    AddTooltip(dropdown, L.POS_OBJECT_TOOLTIP)
    local function TextOf(value)
        for _, item in ipairs(objects) do
            if item[1] == value then return item[2] end
        end
    end
    UIDropDownMenu_Initialize(dropdown, function()
        for _, item in ipairs(objects) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item[2]
            info.checked = editing == item[1]
            info.func = function()
                editing = item[1]
                Refresh()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    dropdown.Refresh = function(self) UIDropDownMenu_SetText(self, TextOf(editing)) end
    widgets[#widgets + 1] = dropdown

    local function Pixels(value) return string.format("%d px", value) end
    local halfW = math.floor(UIParent:GetWidth() / 2)
    local halfH = math.floor(UIParent:GetHeight() / 2)
    Slider(position, {
        name = "posX",
        get = function() return (api.GetOffset(editing)) end,
        set = function(value) api.SetOffset(editing, value, nil) end,
    }, L.POS_X, L.POS_TOOLTIP, X, -167, -halfW, halfW, 1, Pixels)
    Slider(position, {
        name = "posY",
        get = function() return select(2, api.GetOffset(editing)) end,
        set = function(value) api.SetOffset(editing, nil, value) end,
    }, L.POS_Y, L.POS_TOOLTIP, X, -217, -halfH, halfH, 1, Pixels)
    Separator(position, -257)

    ResetButton(position, -277, function()
        api.ResetPositions()
        Refresh()
    end)

    -- Abierta: se ve la muestra de todo para saber donde quedara
    position:SetScript("OnShow", function()
        api.SetPreview(true)
        Refresh()
    end)
    position:SetScript("OnHide", function() api.SetPreview(false) end)
    refreshers[position] = Refresh

    local root = ns.CreateAbout({
        name = "Seal Timers Forever",
        logo = LOGO,
        github = "https://github.com/Pirson-s-Addons/SealTimersForever",
        curseforge = "https://www.curseforge.com/wow/addons/seal-timers-forever",
        commands = {
            { "/stf", L.CMD_OPEN },
            { "/stf check", L.CMD_CHECK },
            { "/stf reset", L.CMD_RESET },
            { "/stf debug", L.CMD_DEBUG },
        },
    })
    local category = Settings.RegisterCanvasLayoutSubcategory(root, panel, L.GENERAL_HEADER)
    Settings.RegisterCanvasLayoutSubcategory(root, alert, L.ALERT_HEADER)
    Settings.RegisterCanvasLayoutSubcategory(root, position, L.POSITION_HEADER)
    return category
end
