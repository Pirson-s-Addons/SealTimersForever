local ADDON_NAME, ns = ...
local L = ns.L

-- ==========================================
-- OPCIONES
-- ==========================================
-- Raiz "Acerca de" (UI/About.lua) y, colgando de ella, "General" con los
-- ajustes: panel propio con la plantilla de todos los addons de Pirson
-- (titulo, logo con version, secciones en morado y "Valores por defecto").

local HEADER = "|cffC47FF3"
local LOGO = "Interface\\AddOns\\SealTimersForever\\img\\logo_stf"
local X = 16
-- Lo que devuelve "Valores por defecto": los ajustes del panel, no la posicion
local PANEL_KEYS = { "locked", "scale", "twistEnabled", "swingBar", "twistGlow", "twistWindow", "twistSound", "hitIcon" }

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

-- api: { db, defaults, ApplyLock, ApplyScale, ApplySwingBar, ApplyHitAnchor, UpdateTicks }
-- Devuelve la subcategoria General (destino de /stf).
function ns.CreateOptions(api)
    local db = api.db
    local panel = CreateFrame("Frame")
    panel:Hide() -- nace oculto: si no, el Show() al abrir la categoria no dispara OnShow
    local widgets, children = {}, {}

    local function Checkbox(key, label, tooltip, x, y, onChange)
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

    local function Slider(key, label, tooltip, x, y, min, max, step, format, onChange)
        local slider = CreateFrame("Slider", "SealTimersForever_" .. key, panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", x + 10, y)
        slider:SetWidth(400)
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        local name = slider:GetName()
        _G[name .. "Low"]:SetText(format(min))
        _G[name .. "High"]:SetText(format(max))
        local function Label() _G[name .. "Text"]:SetText(label .. ": " .. format(db[key])) end
        slider:SetScript("OnValueChanged", function(_, value)
            value = math.floor(value / step + 0.5) * step
            if value == db[key] then return end
            db[key] = value
            Label()
            onChange()
        end)
        AddTooltip(slider, tooltip)
        slider.Refresh = function(self)
            self:SetValue(db[key])
            Label()
        end
        widgets[#widgets + 1] = slider
        return slider
    end

    -- Las opciones de twist cuelgan del interruptor: apagado, se ven desactivadas
    local function UpdateChildren()
        for _, widget in ipairs(children) do
            widget:SetEnabled(db.twistEnabled)
            widget:SetAlpha(db.twistEnabled and 1 or 0.5)
        end
    end

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

    -- General: posicion y tamano del bloque
    Header(panel, -56, L.GENERAL_HEADER)
    Checkbox("locked", L.LOCK, L.LOCK_TOOLTIP, X, -81, api.ApplyLock)
    Slider("scale", L.SIZE, L.SIZE_TOOLTIP, X, -135, 0.5, 3, 0.1, function(value)
        return string.format("%d%%", math.floor(value * 100 + 0.5))
    end, api.ApplyScale)
    Separator(panel, -180)

    -- Seal twisting: un interruptor general y, colgando de el, sus opciones
    Header(panel, -200, L.TWIST_HEADER)
    Checkbox("twistEnabled", L.TWIST_ENABLED, L.TWIST_ENABLED_TOOLTIP, X, -225, function()
        api.ApplySwingBar()
        api.ApplyHitAnchor()
        UpdateChildren()
    end)
    local cx = X + 20
    children[#children + 1] = Checkbox("swingBar", L.SWING_BAR, L.SWING_BAR_TOOLTIP, cx, -255, api.ApplySwingBar)
    children[#children + 1] = Checkbox("twistGlow", L.TWIST_GLOW, L.TWIST_GLOW_TOOLTIP, cx, -285, api.ApplySwingBar)
    children[#children + 1] = Slider("twistWindow", L.TWIST_WINDOW, L.TWIST_WINDOW_TOOLTIP, cx, -335, 0.1, 1, 0.1,
        function(value) return string.format("%.1f s", value) end, api.UpdateTicks)
    children[#children + 1] = Checkbox("twistSound", L.TWIST_SOUND, L.TWIST_SOUND_TOOLTIP, cx, -370, nil)
    children[#children + 1] = Checkbox("hitIcon", L.HIT_ICON, L.HIT_ICON_TOOLTIP, cx, -400, api.ApplyHitAnchor)
    Separator(panel, -440)

    local function Refresh()
        for _, widget in ipairs(widgets) do widget:Refresh() end
        UpdateChildren()
    end
    panel:SetScript("OnShow", Refresh)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(180, 26)
    reset:SetPoint("TOPLEFT", X, -460)
    reset:SetText(L.DEFAULTS)
    reset:SetScript("OnClick", function()
        for _, key in ipairs(PANEL_KEYS) do db[key] = api.defaults[key] end
        api.ApplyLock()
        api.ApplyScale()
        api.ApplySwingBar()
        api.ApplyHitAnchor()
        api.UpdateTicks()
        Refresh()
    end)

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
    return Settings.RegisterCanvasLayoutSubcategory(root, panel, L.GENERAL_HEADER)
end
