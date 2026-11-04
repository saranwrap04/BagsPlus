local ADDON, BP = ...
local W = {}
BP.W = W

local WHITE = "Interface\\Buttons\\WHITE8x8"
local FONT = STANDARD_TEXT_FONT
W.WHITE = WHITE

local function Size(f, w, h)
    f:SetWidth(w)
    f:SetHeight(h)
end
W.Size = Size

function W.Backdrop(f, r, g, b, a, er, eg, eb)
    f:SetBackdrop({
        bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(r or 0.06, g or 0.06, b or 0.06, a or 1)
    f:SetBackdropBorderColor(er or 0, eg or 0, eb or 0, 1)
end

function W.Text(parent, size, r, g, b, justify, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(FONT, size or 12, "")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

function W.Gold(parent, size, justify)
    return W.Text(parent, size, 1, 0.82, 0, justify)
end

------------------------------------------------------------------------
-- Button: gold text; selected = lighter box + white text
------------------------------------------------------------------------
function W.Button(parent, text, w, h, onclick)
    local b = CreateFrame("Button", nil, parent)
    Size(b, w or 80, h or 22)
    W.Backdrop(b, 0.10, 0.10, 0.10, 1)
    b.text = W.Gold(b, 12, "CENTER")
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetText(text or "")
    b.selected = false
    function b:SetSelected(v)
        self.selected = v and true or false
        if self.selected then
            self:SetBackdropColor(0.20, 0.20, 0.20, 1)
            self.text:SetTextColor(1, 1, 1)
        else
            self:SetBackdropColor(0.10, 0.10, 0.10, 1)
            self.text:SetTextColor(1, 0.82, 0)
        end
    end
    function b:SetLabel(t) self.text:SetText(t) end
    b:SetScript("OnEnter", function(s)
        s:SetBackdropBorderColor(1, 0.82, 0, 1)
        if s.tip then
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(s.tip, 1, 1, 1)
            if s.tip2 then GameTooltip:AddLine(s.tip2, 0.7, 0.7, 0.7, true) end
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(s)
        s:SetBackdropBorderColor(0, 0, 0, 1)
        GameTooltip:Hide()
    end)
    if onclick then b:SetScript("OnClick", onclick) end
    return b
end

function W.IconButton(parent, texture, size, onclick)
    local b = W.Button(parent, "", size, size, onclick)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    b.icon:SetTexture(texture)
    return b
end

------------------------------------------------------------------------
-- Check box: dark square filled gold
------------------------------------------------------------------------
function W.Check(parent, label, get, set)
    local c = CreateFrame("Button", nil, parent)
    Size(c, 220, 20)
    local box = CreateFrame("Frame", nil, c)
    Size(box, 14, 14)
    box:SetPoint("LEFT", 0, 0)
    W.Backdrop(box, 0.10, 0.10, 0.10, 1)
    local fill = box:CreateTexture(nil, "OVERLAY")
    fill:SetTexture(1, 0.82, 0, 1)
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    c.fill = fill
    c.label = W.Text(c, 12, 0.9, 0.9, 0.9)
    c.label:SetPoint("LEFT", box, "RIGHT", 7, 0)
    c.label:SetText(label)
    function c:Update()
        if get() then fill:Show() else fill:Hide() end
    end
    c:SetScript("OnClick", function(s)
        set(not get())
        s:Update()
    end)
    c:SetScript("OnEnter", function() box:SetBackdropBorderColor(1, 0.82, 0, 1) end)
    c:SetScript("OnLeave", function() box:SetBackdropBorderColor(0, 0, 0, 1) end)
    c:Update()
    return c
end

------------------------------------------------------------------------
-- Slider: gold label above, gold thumb, min / value box / max under
------------------------------------------------------------------------
function W.Slider(parent, label, min, max, step, get, set, width)
    local f = CreateFrame("Frame", nil, parent)
    Size(f, width or 220, 48)
    local t = W.Gold(f, 12, "LEFT")
    t:SetPoint("TOPLEFT", 0, 0)
    t:SetText(label)
    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    Size(s, width or 220, 8)
    s:SetPoint("TOPLEFT", 0, -20)
    W.Backdrop(s, 0.10, 0.10, 0.10, 1)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    local th = s:CreateTexture(nil, "OVERLAY")
    th:SetTexture(1, 0.82, 0, 1)
    Size(th, 8, 14)
    s:SetThumbTexture(th)
    local lo = W.Text(f, 10, 0.6, 0.6, 0.6, "LEFT")
    lo:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -3)
    lo:SetText(min)
    local hi = W.Text(f, 10, 0.6, 0.6, 0.6, "RIGHT")
    hi:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -3)
    hi:SetText(max)
    local val = W.Text(f, 11, 1, 1, 1, "CENTER")
    local vb = CreateFrame("Frame", nil, f)
    Size(vb, 44, 16)
    vb:SetPoint("TOP", s, "BOTTOM", 0, -2)
    W.Backdrop(vb, 0.10, 0.10, 0.10, 1)
    val:SetParent(vb)
    val:SetAllPoints(vb)
    local init = true
    s:SetScript("OnValueChanged", function(_, v)
        v = floor(v / step + 0.5) * step
        val:SetText(step < 1 and format("%.2f", v) or v)
        if not init then set(v) end
    end)
    function f:Update()
        init = true
        s:SetValue(get())
        init = false
        local v = get()
        val:SetText(step < 1 and format("%.2f", v) or v)
    end
    f:Update()
    return f
end

------------------------------------------------------------------------
-- Edit box
------------------------------------------------------------------------
function W.EditBox(parent, w, h, onenter)
    local e = CreateFrame("EditBox", nil, parent)
    Size(e, w or 160, h or 20)
    W.Backdrop(e, 0.04, 0.04, 0.04, 1)
    e:SetFont(FONT, 12, "")
    e:SetTextColor(1, 1, 1)
    e:SetTextInsets(6, 6, 0, 0)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(s)
        s:ClearFocus()
        if onenter then onenter(s:GetText()) end
    end)
    e:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(1, 0.82, 0, 1) end)
    e:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(0, 0, 0, 1) end)
    return e
end

------------------------------------------------------------------------
-- Section title: gold text centered between thin lines
------------------------------------------------------------------------
function W.Section(parent, text, width)
    local f = CreateFrame("Frame", nil, parent)
    Size(f, width or 400, 16)
    local t = W.Gold(f, 12, "CENTER")
    t:SetPoint("CENTER", 0, 0)
    t:SetText(text)
    local l = f:CreateTexture(nil, "ARTWORK")
    l:SetTexture(1, 0.82, 0, 0.35)
    l:SetHeight(1)
    l:SetPoint("LEFT", 0, 0)
    l:SetPoint("RIGHT", t, "LEFT", -8, 0)
    local r = f:CreateTexture(nil, "ARTWORK")
    r:SetTexture(1, 0.82, 0, 0.35)
    r:SetHeight(1)
    r:SetPoint("RIGHT", 0, 0)
    r:SetPoint("LEFT", t, "RIGHT", 8, 0)
    return f
end

------------------------------------------------------------------------
-- Side button: gold glow on the selected one
------------------------------------------------------------------------
function W.SideButton(parent, text, w, onclick)
    local b = CreateFrame("Button", nil, parent)
    Size(b, w or 130, 26)
    W.Backdrop(b, 0.08, 0.08, 0.08, 1)
    b.glow = b:CreateTexture(nil, "ARTWORK")
    b.glow:SetTexture(1, 0.82, 0, 0.18)
    b.glow:SetAllPoints(b)
    b.glow:Hide()
    b.bar = b:CreateTexture(nil, "OVERLAY")
    b.bar:SetTexture(1, 0.82, 0, 1)
    Size(b.bar, 2, 26)
    b.bar:SetPoint("LEFT", 0, 0)
    b.bar:Hide()
    b.text = W.Gold(b, 12, "LEFT")
    b.text:SetPoint("LEFT", 12, 0)
    b.text:SetText(text)
    function b:SetSelected(v)
        if v then
            self.glow:Show(); self.bar:Show(); self.text:SetTextColor(1, 1, 1)
        else
            self.glow:Hide(); self.bar:Hide(); self.text:SetTextColor(1, 0.82, 0)
        end
    end
    b:SetScript("OnClick", onclick)
    return b
end

------------------------------------------------------------------------
-- Flat popup menu: items = { {text=, func=, check=, color={r,g,b}, title=} ... }
------------------------------------------------------------------------
local menu, catcher
local rows = {}

local function BuildMenu()
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:SetAllPoints(UIParent)
    catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    catcher:Hide()
    menu = CreateFrame("Frame", "BagsPlusMenu", UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    W.Backdrop(menu, 0.06, 0.06, 0.06, 1)
    menu:Hide()
    catcher:SetScript("OnClick", function() W.CloseMenu() end)
    menu:SetScript("OnHide", function() catcher:Hide() end)
end

function W.CloseMenu()
    if menu then menu:Hide() end
end

function W.Menu(anchor, items, minWidth)
    if not menu then BuildMenu() end
    if menu:IsShown() and menu.owner == anchor then
        menu:Hide()
        return
    end
    menu.owner = anchor
    local width = minWidth or 120
    for i, it in ipairs(items) do
        local r = rows[i]
        if not r then
            r = CreateFrame("Button", nil, menu)
            r:SetHeight(20)
            r.hl = r:CreateTexture(nil, "BACKGROUND")
            r.hl:SetTexture(1, 0.82, 0, 0.18)
            r.hl:SetAllPoints(r)
            r.hl:Hide()
            r.tick = r:CreateTexture(nil, "OVERLAY")
            r.tick:SetTexture(1, 0.82, 0, 1)
            Size(r.tick, 6, 6)
            r.tick:SetPoint("LEFT", 6, 0)
            r.text = W.Text(r, 12, 1, 1, 1, "LEFT")
            r.text:SetPoint("LEFT", 18, 0)
            r:SetScript("OnEnter", function(s) if not s.title then s.hl:Show() end end)
            r:SetScript("OnLeave", function(s) s.hl:Hide() end)
            r:SetScript("OnClick", function(s)
                if s.title then return end
                W.CloseMenu()
                if s.func then s.func() end
            end)
            rows[i] = r
        end
        r.func = it.func
        r.title = it.title
        r.text:SetText(it.text)
        local c = it.color
        if it.title then
            r.text:SetTextColor(1, 0.82, 0)
        elseif c then
            r.text:SetTextColor(c[1], c[2], c[3])
        else
            r.text:SetTextColor(1, 1, 1)
        end
        if it.check then r.tick:Show() else r.tick:Hide() end
        local tw = r.text:GetStringWidth() + 32
        if tw > width then width = tw end
    end
    for i = 1, #rows do
        if i > #items then rows[i]:Hide() end
    end
    for i, it in ipairs(items) do
        local r = rows[i]
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1 - (i - 1) * 20)
        r:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, -1 - (i - 1) * 20)
        r:Show()
    end
    Size(menu, width, #items * 20 + 2)
    menu:ClearAllPoints()
    local bottom = anchor:GetBottom() or 0
    if bottom - (#items * 20 + 2) < 0 then
        menu:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
    else
        menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    end
    catcher:Show()
    menu:Show()
end

-- Drop-down: dark box, choice right-aligned, gold arrow. options = { {value=, text=}, ... }
function W.Dropdown(parent, label, options, get, set, width)
    local f = CreateFrame("Frame", nil, parent)
    Size(f, width or 220, 44)
    local t = W.Gold(f, 12, "LEFT")
    t:SetPoint("TOPLEFT", 0, 0)
    t:SetText(label)
    local b = CreateFrame("Button", nil, f)
    Size(b, width or 220, 22)
    b:SetPoint("TOPLEFT", 0, -18)
    W.Backdrop(b, 0.10, 0.10, 0.10, 1)
    b.text = W.Text(b, 12, 1, 1, 1, "RIGHT")
    b.text:SetPoint("RIGHT", -22, 0)
    local arrow = W.Gold(b, 11, "CENTER")
    arrow:SetPoint("RIGHT", -7, -1)
    arrow:SetText("v")
    local function Text()
        for _, o in ipairs(options) do
            if o.value == get() then return o.text end
        end
        return ""
    end
    function f:Update() b.text:SetText(Text()) end
    b:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(1, 0.82, 0, 1) end)
    b:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(0, 0, 0, 1) end)
    b:SetScript("OnClick", function(s)
        local items = {}
        for _, o in ipairs(options) do
            items[#items + 1] = {
                text = o.text, check = (o.value == get()),
                func = function() set(o.value); f:Update() end,
            }
        end
        W.Menu(s, items, width or 220)
    end)
    f:Update()
    return f
end
