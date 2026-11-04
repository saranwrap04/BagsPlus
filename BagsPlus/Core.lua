local ADDON, BP = ...
_G.BagsPlus = BP

BP.VERSION = "1.0.12"
BP.TITLE = "Bags Plus"
BP.GOLD = { 1, 0.82, 0 }
BP.windows = {}

-- Built-in categories, in default order. "other" is always the final fallback.
BP.BUILTIN = {
    { key = "new",       name = "New items" },
    { key = "set",       name = "Equipment sets" },
    { key = "quest",     name = "Quest" },
    { key = "junk",      name = "Junk" },
    { key = "food",      name = "Food & Drink" },
    { key = "potion",    name = "Potions & Elixirs" },
    { key = "consumable",name = "Consumables" },
    { key = "weapon",    name = "Weapons" },
    { key = "armor",     name = "Armor" },
    { key = "trade",     name = "Trade Goods" },
    { key = "reagent",   name = "Reagents" },
    { key = "gem",       name = "Gems" },
    { key = "glyph",     name = "Glyphs" },
    { key = "recipe",    name = "Recipes" },
    { key = "container", name = "Bags" },
    { key = "ammo",      name = "Ammunition" },
    { key = "key",       name = "Keys" },
    { key = "misc",      name = "Miscellaneous" },
    { key = "other",     name = "Other" },
}

BP.defaults = {
    layoutBags = "category",
    layoutBank = "single",
    colsBags = 10,
    colsBank = 14,
    size = 36,
    spacing = 3,
    scale = 1,
    alpha = 0.95,
    sort = "type",
    manualSort = true,
    emptyMode = "one",        -- all / one / none (category view)
    specialSeparate = true,
    cornerTL = "ilvl",
    cornerTR = "none",
    junkCoin = true,
    cornerBL = "bind",
    ilvlMinQuality = 2,
    ilvlSize = 12,
    specialColors = true,
    borderMinQuality = 1,
    ilvlQualityColor = false,
    tooltipInfo = false,
    orderVersion = 0,
    qualityBorder = true,
    showUnusable = true,
    showNew = true,
    markSets = true,
    showQuest = true,
    showKeyring = true,
    showCurrency = true,
    autoSellJunk = false,
    lock = false,
    strata = "HIGH",
    clearNewOnClose = true,
    closeWithEsc = true,
    pos = {},
    collapsed = {},
    disabled = {},
    custom = {},
    overrides = {},
    catSort = {},
    order = nil,
    nextCustom = 1,
}

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end
BP.copy = copy

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local handlers = {}
local ef = CreateFrame("Frame")
ef:SetScript("OnEvent", function(self, event, ...)
    local h = handlers[event]
    if h then
        for i = 1, #h do h[i](event, ...) end
    end
end)

function BP.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        ef:RegisterEvent(event)
    end
    tinsert(handlers[event], fn)
end

------------------------------------------------------------------------
-- Timers (no C_Timer on 3.3.5)
------------------------------------------------------------------------
local timers = {}
local tf = CreateFrame("Frame")
tf:Hide()
tf:SetScript("OnUpdate", function()
    local now = GetTime()
    for i = #timers, 1, -1 do
        local t = timers[i]
        if t and t.t <= now then
            tremove(timers, i)
            t.fn()
        end
    end
    if #timers == 0 then tf:Hide() end
end)

function BP.After(sec, fn)
    tinsert(timers, { t = GetTime() + sec, fn = fn })
    tf:Show()
end

local pending = false
function BP.Dirty()
    if pending then return end
    pending = true
    BP.After(0.05, function()
        pending = false
        BP.RefreshAll()
    end)
end

function BP.RefreshAll()
    for _, w in pairs(BP.windows) do
        if w:IsShown() then w:Refresh() end
    end
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
function BP.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Bags Plus|r " .. tostring(msg))
end

function BP.Money(copper)
    copper = copper or 0
    local g = floor(copper / 10000)
    local s = floor((copper % 10000) / 100)
    local c = copper % 100
    local out = ""
    if g > 0 then out = out .. g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t " end
    if s > 0 or g > 0 then out = out .. s .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t " end
    out = out .. c .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
    return out
end

function BP.CategoryOrder()
    local db = BP.db
    if (db.orderVersion or 0) < 2 then
        db.order = nil           -- default order changed (junk now follows quest)
        db.orderVersion = 2
    end
    local seen, order = {}, {}
    local valid = {}
    for _, c in ipairs(BP.BUILTIN) do valid[c.key] = true end
    for _, c in ipairs(db.custom) do valid["c" .. c.id] = true end
    if db.order then
        for _, k in ipairs(db.order) do
            if valid[k] and not seen[k] and k ~= "other" then
                seen[k] = true
                order[#order + 1] = k
            end
        end
    end
    -- custom categories not yet ordered go first, built-ins keep their default place
    for _, c in ipairs(db.custom) do
        local k = "c" .. c.id
        if not seen[k] then seen[k] = true; tinsert(order, 1, k) end
    end
    for i, c in ipairs(BP.BUILTIN) do
        if not seen[c.key] and c.key ~= "other" then
            seen[c.key] = true
            local pos
            for j = i - 1, 1, -1 do
                local prev = BP.BUILTIN[j].key
                for n, k in ipairs(order) do
                    if k == prev then pos = n + 1; break end
                end
                if pos then break end
            end
            pos = pos or (#order + 1)
            tinsert(order, pos, c.key)
        end
    end
    order[#order + 1] = "other"
    db.order = order
    return order
end

function BP.CategoryName(key)
    local o = BP.db.overrides and BP.db.overrides[key]
    if o and o.name and o.name ~= "" then return o.name end
    for _, c in ipairs(BP.BUILTIN) do
        if c.key == key then return c.name end
    end
    for _, c in ipairs(BP.db.custom) do
        if "c" .. c.id == key then return c.name end
    end
    return key
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
BP.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    BagsPlusDB = BagsPlusDB or {}
    for k, v in pairs(BP.defaults) do
        if BagsPlusDB[k] == nil then BagsPlusDB[k] = copy(v) end
    end
    for _, k in ipairs({ "cornerTL", "cornerTR", "cornerBL" }) do
        if BagsPlusDB[k] == "junk" then BagsPlusDB[k] = "none" end   -- the coin is its own setting now
    end
    BP.db = BagsPlusDB
    BP.Data.Init()
end)

BP.On("PLAYER_LOGIN", function()
    BP.Data.Login()
    BP.Install()
end)

------------------------------------------------------------------------
-- Slash
------------------------------------------------------------------------
SLASH_BAGSPLUS1 = "/bplus"
SLASH_BAGSPLUS2 = "/bagsplus"
SlashCmdList["BAGSPLUS"] = function(msg)
    msg = strtrim(msg or ""):lower()
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "settings" or cmd == "options" then
        BP.OpenSettings()
    elseif cmd == "bags" then
        BP.ToggleBags()
    elseif cmd == "bank" then
        BP.ToggleBank()
    elseif cmd == "guild" then
        BP.ToggleGuild()
    elseif cmd == "sort" then
        BP.Sort(BP.bankOpen and BP.windows.bank and BP.windows.bank:IsShown() and "bank" or "bags")
    elseif cmd == "search" then
        BP.ShowBags()
        BP.windows.bags:SetSearch(rest)
    elseif cmd == "reset" then
        BP.db.pos = {}
        for kind, w in pairs(BP.windows) do w:RestorePosition() end
        BP.Print("Window positions reset.")
    else
        BP.Print("/bplus  settings   |   /bplus bags | bank | guild   |   /bplus sort   |   /bplus search <text>   |   /bplus reset")
    end
end
