local ADDON, BP = ...
local W = BP.W
local Size = W.Size

local frame
local pages, sideButtons = {}, {}
local current

local function Set(key, after)
    return function(v)
        BP.db[key] = v
        if after then after() else BP.Dirty() end
    end
end
local function Get(key) return function() return BP.db[key] end end

local CORNER_OPTS = {
    { value = "none", text = "None" }, { value = "ilvl", text = "Item level" },
    { value = "bind", text = "Bind type" },
    { value = "set", text = "Equipment set" }, { value = "quest", text = "Quest" },
}

------------------------------------------------------------------------
-- Flow layout: section titles, full-width check boxes, side-by-side sliders/drop-downs
------------------------------------------------------------------------
local PAGE_W = 520
local COL_W = 240
local COL_X = 280

local function Flow(p)
    local f = { y = 0 }
    function f:Section(text)
        if self.y > 0 then self.y = self.y + 10 end
        local s = W.Section(p, text, PAGE_W)
        s:SetPoint("TOPLEFT", 0, -self.y)
        self.y = self.y + 26
    end
    function f:Check(w)
        w:SetParent(p)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", 0, -self.y)
        w:SetWidth(PAGE_W)
        self.y = self.y + 24
    end
    function f:Pair(a, b)
        local h = 0
        for i, w in ipairs({ a, b }) do
            w:SetParent(p)
            w:ClearAllPoints()
            w:SetPoint("TOPLEFT", (i == 1) and 0 or COL_X, -self.y)
            h = max(h, w:GetHeight() or 40)
        end
        self.y = self.y + h + 14
    end
    return f
end

------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------
local function PageGeneral(p)
    local F = Flow(p)
    F:Section("Windows")
    F:Pair(
        W.Dropdown(p, "Window layer", {
            { value = "MEDIUM", text = "Normal" }, { value = "HIGH", text = "Above chat" },
            { value = "DIALOG", text = "Above everything" },
        }, Get("strata"), Set("strata", BP.ApplyLook), COL_W),
        W.Slider(p, "Scale", 0.6, 1.6, 0.05, Get("scale"), Set("scale", BP.ApplyLook), COL_W))
    F:Pair(
        W.Slider(p, "Background opacity", 0.3, 1, 0.05, Get("alpha"), Set("alpha", BP.ApplyLook), COL_W),
        CreateFrame("Frame", nil, p))
    F:Check(W.Check(p, "Lock window positions", Get("lock"), Set("lock")))
    F:Check(W.Check(p, "Close windows with Esc", Get("closeWithEsc"), Set("closeWithEsc", BP.ApplyEsc)))
    F:Section("Bags")
    F:Check(W.Check(p, "Show keyring button in the bag strip", Get("showKeyring"), Set("showKeyring")))
    F:Check(W.Check(p, "Show watched currencies in the footer", Get("showCurrency"), Set("showCurrency")))
    F:Check(W.Check(p, "Clear new-item marks when bags close (not when sorting by hand)", Get("clearNewOnClose"), Set("clearNewOnClose")))
    F:Check(W.Check(p, "Sell junk automatically at vendors", Get("autoSellJunk"), Set("autoSellJunk")))
end

local function PageLayout(p)
    local F = Flow(p)
    local layouts = { { value = "single", text = "Single grid" }, { value = "category", text = "Categories" } }
    F:Section("Layout")
    F:Pair(W.Dropdown(p, "Bags layout", layouts, Get("layoutBags"), Set("layoutBags"), COL_W),
           W.Dropdown(p, "Bank layout", layouts, Get("layoutBank"), Set("layoutBank"), COL_W))
    F:Pair(W.Slider(p, "Bag columns", 6, 20, 1, Get("colsBags"), Set("colsBags"), COL_W),
           W.Slider(p, "Bank columns", 8, 24, 1, Get("colsBank"), Set("colsBank"), COL_W))
    F:Pair(W.Slider(p, "Button size", 24, 48, 1, Get("size"), Set("size"), COL_W),
           W.Slider(p, "Button spacing", 0, 10, 1, Get("spacing"), Set("spacing"), COL_W))
    F:Section("Categories view")
    F:Pair(W.Dropdown(p, "Empty slots", {
               { value = "one", text = "One, with free count" }, { value = "all", text = "Show all" },
               { value = "none", text = "Hide" },
           }, Get("emptyMode"), Set("emptyMode"), COL_W),
           CreateFrame("Frame", nil, p))
    F:Check(W.Check(p, "Keep special bags (quiver, herbs...) in their own section", Get("specialSeparate"), Set("specialSeparate")))
    F:Section("Sorting")
    F:Pair(W.Dropdown(p, "Sort button order", {
               { value = "type", text = "Type" }, { value = "quality", text = "Quality" },
               { value = "name", text = "Name" }, { value = "ilvl", text = "Item level" },
           }, Get("sort"), Set("sort"), COL_W),
           CreateFrame("Frame", nil, p))
    F:Check(W.Check(p, "Sort only when I click Sort", Get("manualSort"), Set("manualSort")))
end

local function PageItems(p)
    local F = Flow(p)
    F:Section("Corner labels")
    F:Pair(W.Dropdown(p, "Top-left corner", CORNER_OPTS, Get("cornerTL"), Set("cornerTL"), COL_W),
           W.Dropdown(p, "Top-right corner", CORNER_OPTS, Get("cornerTR"), Set("cornerTR"), COL_W))
    F:Pair(W.Dropdown(p, "Bottom-left corner", CORNER_OPTS, Get("cornerBL"), Set("cornerBL"), COL_W),
           W.Slider(p, "Item level from quality (0-6)", 0, 6, 1, Get("ilvlMinQuality"), Set("ilvlMinQuality"), COL_W))
    F:Check(W.Check(p, "Colour item level by quality", Get("ilvlQualityColor"), Set("ilvlQualityColor")))
    F:Section("Text and borders")
    F:Pair(W.Slider(p, "Item level and count text size", 8, 16, 1, Get("ilvlSize"), Set("ilvlSize"), COL_W),
           W.Slider(p, "Border from quality (0 grey - 6)", 0, 6, 1, Get("borderMinQuality"), Set("borderMinQuality"), COL_W))
    F:Check(W.Check(p, "Quality-coloured borders", Get("qualityBorder"), Set("qualityBorder")))
    F:Check(W.Check(p, "Colour special bag slots (engineering, herbs...)", Get("specialColors"), Set("specialColors")))
    F:Check(W.Check(p, "Orange border on quest items", Get("showQuest"), Set("showQuest")))
    F:Check(W.Check(p, "Tint unusable items red", Get("showUnusable"), Set("showUnusable")))
    F:Section("Markers")
    F:Check(W.Check(p, "Coin icon on junk (grey) items", Get("junkCoin"), Set("junkCoin")))
    F:Check(W.Check(p, "Highlight new items", Get("showNew"), Set("showNew")))
    F:Check(W.Check(p, "Equipment set items in their own section", Get("markSets"), Set("markSets")))
    F:Check(W.Check(p, "Show category and item type in tooltips", Get("tooltipInfo"), Set("tooltipInfo")))
end

-- Categories editor
local function PageCategories(p)
    local sec = W.Section(p, "Categories", PAGE_W)
    sec:SetPoint("TOPLEFT", 0, -4)
    local ROWS = 13
    local offset = 0
    local selected
    local rows = {}
    local editor = CreateFrame("Frame", nil, p)
    Size(editor, 290, 336)
    editor:SetPoint("TOPLEFT", p, "TOPLEFT", 214, -28)

    local nameBox, queryBox, itemsBox, hint, delBtn, sortDrop
    local function Target(create)
        if not selected then return nil end
        local c = BP.FindCustom(selected)
        if c then return c, true end
        local o = BP.db.overrides[selected]
        if not o and create then o = { query = "", items = {} }; BP.db.overrides[selected] = o end
        return o, false
    end
    local function Order() return BP.CategoryOrder() end

    local function Move(key, dir)
        local o = Order()
        for i, k in ipairs(o) do
            if k == key then
                local j = i + dir
                if j >= 1 and j < #o then -- "other" stays last
                    o[i], o[j] = o[j], o[i]
                end
                break
            end
        end
        BP.Dirty()
    end

    local Refresh
    local function LoadEditor()
        if not selected then editor:Hide(); return end
        local c, isCustom = Target(false)
        editor:Show()
        nameBox:SetText(BP.CategoryName(selected))
        queryBox:SetText(c and c.query or "")
        local ids = {}
        for id in pairs(c and c.items or {}) do ids[#ids + 1] = id end
        table.sort(ids)
        itemsBox:SetText(table.concat(ids, ","))
        delBtn:SetLabel(isCustom and "Delete category" or "Reset category")
        if sortDrop then sortDrop:Update() end
    end

    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, p)
        Size(r, 190, 22)
        r:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -28 - (i - 1) * 24)
        W.Backdrop(r, 0.08, 0.08, 0.08, 1)
        r.glow = r:CreateTexture(nil, "ARTWORK")
        r.glow:SetTexture(1, 0.82, 0, 0.18)
        r.glow:SetAllPoints(r)
        r.glow:Hide()
        r.on = CreateFrame("Button", nil, r)
        Size(r.on, 12, 12)
        r.on:SetPoint("LEFT", 5, 0)
        W.Backdrop(r.on, 0.10, 0.10, 0.10, 1)
        r.fill = r.on:CreateTexture(nil, "OVERLAY")
        r.fill:SetTexture(1, 0.82, 0, 1)
        r.fill:SetPoint("TOPLEFT", 3, -3)
        r.fill:SetPoint("BOTTOMRIGHT", -3, 3)
        r.text = W.Text(r, 12, 1, 1, 1)
        r.text:SetPoint("LEFT", 24, 0)
        r.text:SetPoint("RIGHT", -46, 0)
        r.up = W.Button(r, "^", 18, 18, function() Move(r.key, -1); Refresh() end)
        r.up:SetPoint("RIGHT", -24, 0)
        r.down = W.Button(r, "v", 18, 18, function() Move(r.key, 1); Refresh() end)
        r.down:SetPoint("RIGHT", -3, 0)
        r.on:SetScript("OnClick", function()
            local d = BP.db.disabled
            d[r.key] = (not d[r.key]) or nil
            BP.Dirty(); Refresh()
        end)
        r:SetScript("OnClick", function() selected = r.key; LoadEditor(); Refresh() end)
        rows[i] = r
    end

    function Refresh()
        local o = Order()
        for i = 1, ROWS do
            local r = rows[i]
            local key = o[i + offset]
            if key then
                r.key = key
                local ov = BP.db.overrides[key]
                local changed = key:match("^c%d+$") or (ov and ((ov.query and ov.query ~= "") or next(ov.items or {}) or ov.name))
                r.text:SetText(BP.CategoryName(key) .. (changed and " *" or ""))
                if BP.db.disabled[key] then r.fill:Hide() else r.fill:Show() end
                if selected == key then r.glow:Show() else r.glow:Hide() end
                if key == "other" then r.up:Hide(); r.down:Hide(); r.on:Hide() else r.up:Show(); r.down:Show(); r.on:Show() end
                r:Show()
            else
                r:Hide()
            end
        end
    end
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, d)
        local max_ = max(#Order() - ROWS, 0)
        offset = min(max(offset - d, 0), max_)
        Refresh()
    end)

    local newBtn = W.Button(p, "New category", 190, 22, function()
        local db = BP.db
        local id = db.nextCustom
        db.nextCustom = id + 1
        tinsert(db.custom, { id = id, name = "New category", query = "", items = {} })
        selected = "c" .. id
        BP.Dirty(); LoadEditor(); Refresh()
    end)
    newBtn:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -28 - ROWS * 24 - 4)

    -- editor
    local t1 = W.Gold(editor, 12); t1:SetPoint("TOPLEFT", 0, 0); t1:SetText("Name")
    nameBox = W.EditBox(editor, 290, 22, nil)
    nameBox:SetPoint("TOPLEFT", 0, -16)
    local t2 = W.Gold(editor, 12); t2:SetPoint("TOPLEFT", 0, -50); t2:SetText("Search rule")
    queryBox = W.EditBox(editor, 290, 22, nil)
    queryBox:SetPoint("TOPLEFT", 0, -66)
    local t3 = W.Gold(editor, 12); t3:SetPoint("TOPLEFT", 0, -100); t3:SetText("Item IDs (comma separated)")
    itemsBox = W.EditBox(editor, 290, 22, nil)
    itemsBox:SetPoint("TOPLEFT", 0, -116)
    hint = W.Text(editor, 11, 0.6, 0.6, 0.6)
    hint:SetPoint("TOPLEFT", 0, -148)
    hint:SetWidth(290)
    hint:SetJustifyH("LEFT")
    hint:SetText("Rule: same words as the bag search (epic armor, boe !junk). Listed IDs always go here. Reset undoes changes to a built-in category.")

    local function Commit()
        local c, isCustom = Target(true)
        if not c then return end
        local name = strtrim(nameBox:GetText())
        if isCustom then
            c.name = (name ~= "") and name or "Category"
        else
            local default
            for _, b in ipairs(BP.BUILTIN) do if b.key == selected then default = b.name end end
            c.name = (name ~= "" and name ~= default) and name or nil
        end
        c.query = strtrim(queryBox:GetText())
        c.items = {}
        for id in itemsBox:GetText():gmatch("%d+") do c.items[tonumber(id)] = true end
        BP.ClearQueryCache()
        BP.Dirty(); Refresh()
    end
    for _, e in ipairs({ nameBox, queryBox, itemsBox }) do
        e:SetScript("OnEnterPressed", function(s) s:ClearFocus(); Commit() end)
        e:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(0, 0, 0, 1); Commit() end)
    end

    local add = W.Button(editor, "Add item on cursor", 290, 22, function()
        local kind, id = GetCursorInfo()
        if kind == "item" and id then
            local c = Target(true)
            if c then
                c.items = c.items or {}
                c.items[id] = true
                ClearCursor()
                LoadEditor()
                BP.ClearQueryCache(); BP.Dirty(); Refresh()
            end
        else
            BP.Print("Pick up an item first, then click this button.")
        end
    end)
    add:SetPoint("TOPLEFT", 0, -230)
    delBtn = W.Button(editor, "Delete category", 290, 22, function()
        local _, isCustom = Target(false)
        if isCustom then
            for i, c in ipairs(BP.db.custom) do
                if "c" .. c.id == selected then
                    tremove(BP.db.custom, i)
                    BP.db.disabled[selected] = nil
                    break
                end
            end
            selected = nil
        else
            BP.db.overrides[selected] = nil
        end
        BP.ClearQueryCache(); BP.Dirty(); LoadEditor(); Refresh()
    end)
    delBtn:SetPoint("TOPLEFT", 0, -258)

    sortDrop = W.Dropdown(editor, "Item order", BP.SORT_OPTIONS,
        function() return BP.db.catSort[BP.SortBase(selected or "")] or "default" end,
        function(v)
            if selected then BP.db.catSort[BP.SortBase(selected)] = (v ~= "default") and v or nil end
            BP.Dirty()
        end, 290)
    sortDrop:SetPoint("TOPLEFT", 0, -288)

    editor:Hide()
    p.Update = function() offset = 0; Refresh(); LoadEditor() end
end

local function PageCharacters(p)
    local sec = W.Section(p, "Characters", PAGE_W)
    sec:SetPoint("TOPLEFT", 0, -4)
    local rows = {}
    local total = W.Gold(p, 12, "LEFT")
    total:SetPoint("TOPLEFT", 0, -28)
    local function Refresh()
        local list = BP.Data.Characters()
        total:SetText("All characters: " .. BP.Money(BP.Data.TotalMoney()))
        for i = 1, 12 do
            local r = rows[i]
            if not r then
                r = CreateFrame("Frame", nil, p)
                Size(r, PAGE_W, 22)
                r:SetPoint("TOPLEFT", 0, -52 - (i - 1) * 24)
                r.text = W.Text(r, 12, 1, 1, 1)
                r.text:SetPoint("LEFT", 0, 0)
                r.gold = W.Text(r, 12, 1, 1, 1, "RIGHT")
                r.gold:SetPoint("RIGHT", -70, 0)
                r.del = W.Button(r, "Remove", 62, 20, function()
                    BagsPlusChars[r.key] = nil
                    Refresh()
                end)
                r.del:SetPoint("RIGHT", 0, 0)
                rows[i] = r
            end
            local e = list[i]
            if e then
                r.key = e.key
                local c = e.c
                local col = c.class and RAID_CLASS_COLORS[c.class]
                r.text:SetText(c.name .. (c.realm ~= GetRealmName() and (" - " .. c.realm) or ""))
                if col then r.text:SetTextColor(col.r, col.g, col.b) end
                r.gold:SetText(BP.Money(c.money or 0))
                if e.key == BP.myKey then r.del:Hide() else r.del:Show() end
                r:Show()
            else
                r:Hide()
            end
        end
    end
    p.Update = Refresh
end

local function PageCommands(p)
    local sec = W.Section(p, "Commands and search", PAGE_W)
    sec:SetPoint("TOPLEFT", 0, -4)
    local t = W.Text(p, 12, 0.9, 0.9, 0.9)
    t:SetPoint("TOPLEFT", 0, -28)
    t:SetWidth(PAGE_W)
    t:SetJustifyH("LEFT")
    t:SetText(
        "|cffffd100/bplus|r  settings\n" ..
        "|cffffd100/bplus bags | bank | guild|r  open a window (bank and guild show saved contents when away)\n" ..
        "|cffffd100/bplus sort|r  combine stacks and sort in place\n" ..
        "|cffffd100/bplus search <text>|r  search your bags\n" ..
        "|cffffd100/bplus reset|r  reset window positions\n\n" ..
        "|cffffd100Search words|r\n" ..
        "plain words match name, type and slot\n" ..
        "q:epic  q:>=rare  ilvl:>=200  ilvl:180-200  req:>=70  count:>1\n" ..
        "type:armor  sub:plate  slot:head  set:any  set:name\n" ..
        "boe  bop  bou  boa  soulbound  junk  new  quest  unusable  usable\n" ..
        "price:>5g  bag:2  tt:text in the tooltip\n" ..
        "!word to exclude, |  or  or  to combine alternatives\n\n" ..
        "Click a section title in the category view to collapse it.\n" ..
        "Choose another character from the name button at the top of a window to see their saved bags and bank.")
    local v = W.Text(p, 11, 0.6, 0.6, 0.6)
    v:SetPoint("BOTTOMLEFT", 0, 6)
    v:SetText("Bags Plus " .. BP.VERSION .. " by Saranwrap")
end

------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------
local PAGES = {
    { "General", PageGeneral }, { "Layout", PageLayout }, { "Item buttons", PageItems },
    { "Categories", PageCategories }, { "Characters", PageCharacters }, { "Commands", PageCommands },
}

local function Select(i)
    current = i
    for n, b in ipairs(sideButtons) do b:SetSelected(n == i) end
    for n, p in ipairs(pages) do
        if n == i then
            p:Show()
            if p.Update then p:Update() end
            for _, c in ipairs({ p:GetChildren() }) do
                if c.Update and c ~= p then c:Update() end
            end
        else
            p:Hide()
        end
    end
end

local function Build()
    frame = CreateFrame("Frame", "BagsPlusSettings", UIParent)
    Size(frame, 700, 600)
    frame:SetPoint("CENTER", 0, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    W.Backdrop(frame, 0.06, 0.06, 0.06, 1)
    tinsert(UISpecialFrames, "BagsPlusSettings")

    local title = W.Gold(frame, 14, "CENTER")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Bags Plus")
    local close = W.Button(frame, "x", 22, 22, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -8, -8)

    local side = CreateFrame("Frame", nil, frame)
    Size(side, 130, 520)
    side:SetPoint("TOPLEFT", 10, -40)
    for i, def in ipairs(PAGES) do
        local b = W.SideButton(side, def[1], 130, function() Select(i) end)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * 30)
        sideButtons[i] = b
        local p = CreateFrame("Frame", nil, frame)
        Size(p, PAGE_W, 540)
        p:SetPoint("TOPLEFT", 160, -42)
        p:Hide()
        def[2](p)
        pages[i] = p
    end
    frame:Hide()
end

function BP.OpenSettings()
    if not frame then Build() end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        Select(current or 1)
    end
end
