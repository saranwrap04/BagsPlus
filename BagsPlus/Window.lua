local ADDON, BP = ...
local W = BP.W
local D = BP.Data
local Size = W.Size

local HEADER = 58
local FOOTER = 28
local PAD = 8
local SECTION_H = 18
local SECTION_GAP = 10
local STRIP_H = 34
local MIN_WIDTH = 330

local M = {}   -- window methods

------------------------------------------------------------------------
-- Data collection
------------------------------------------------------------------------
local function BagOrder(kind)
    if kind == "bank" then return BP.BANK_BAGS end
    local t = { 0, 1, 2, 3, 4 }
    if BP.db.showKeyring then t[#t + 1] = BP.KEYRING end
    return t
end

local function CollectLive(kind)
    local groups = {}
    for _, bag in ipairs(BagOrder(kind)) do
        local n = GetContainerNumSlots(bag)
        if n and n > 0 then
            local fam = 0
            if bag == BP.KEYRING then
                fam = 256
            elseif bag >= 0 then
                local _, f = GetContainerNumFreeSlots(bag)
                fam = f or 0
            end
            local g = { bag = bag, size = n, family = fam, recs = {} }
            for slot = 1, n do
                local tex, count, locked, q = GetContainerItemInfo(bag, slot)
                if tex then
                    g.recs[slot] = {
                        bag = bag, slot = slot, link = GetContainerItemLink(bag, slot),
                        count = count or 1, tex = tex, quality = q, locked = locked, live = true,
                    }
                end
            end
            groups[#groups + 1] = g
        end
    end
    return groups
end

local function CollectCached(kind, key)
    local groups = {}
    local c = BagsPlusChars[key]
    if not c then return groups end
    local list = (kind == "bank") and BP.BANK_BAGS or { 0, 1, 2, 3, 4, BP.KEYRING }
    for _, bag in ipairs(list) do
        local b = c.bags[bag]
        if b and b.size and b.size > 0 then
            local g = { bag = bag, size = b.size, family = b.family or 0, recs = {}, link = b.link, icon = b.icon }
            for slot, it in pairs(b.items) do
                g.recs[slot] = { bag = bag, slot = slot, link = it.l, count = it.c, tex = it.t, quality = it.q }
            end
            groups[#groups + 1] = g
        end
    end
    return groups
end

local function CollectGuild(key, tab)
    local g = BagsPlusGuilds[key]
    if not g or not g.tabs[tab] then return {} end
    local t = g.tabs[tab]
    local grp = { bag = tab, size = 98, family = 0, recs = {} }
    for slot, it in pairs(t.items) do
        grp.recs[slot] = { bag = tab, slot = slot, link = it.l, count = it.c, tex = it.t }
    end
    return { grp }
end

------------------------------------------------------------------------
-- Layouts
------------------------------------------------------------------------
local function OrderedGroups(groups, onlyBag)
    local general, special = {}, {}
    for _, g in ipairs(groups) do
        local show
        if onlyBag then show = (g.bag == onlyBag) else show = (g.bag ~= BP.KEYRING) end
        if show then
            if g.family == 0 then general[#general + 1] = g else special[#special + 1] = g end
        end
    end
    for _, g in ipairs(special) do general[#general + 1] = g end
    return general
end

local function LayoutSingle(self, groups, cols)
    local db = BP.db
    local step = db.size + db.spacing
    local entries = {}
    local i = 0
    for _, g in ipairs(OrderedGroups(groups, self.onlyBag)) do
        for slot = 1, g.size do
            local rec = g.recs[slot] or { bag = g.bag, slot = slot, empty = true, family = g.family, dim = self.queryParsed ~= nil }
            entries[#entries + 1] = { rec = rec, x = (i % cols) * step, y = floor(i / cols) * step }
            i = i + 1
        end
    end
    local rows = ceil(i / cols)
    return entries, {}, cols * step - db.spacing, max(rows * step - db.spacing, 0)
end

local function LayoutCategory(self, groups, cols)
    local db = BP.db
    local step = db.size + db.spacing
    local order = BP.CategoryOrder()
    local cmp = BP.Comparator(db.sort)
    local sections, specials = {}, {}
    local free = { count = 0 }
    local specialFree = {}

    local function Add(map, key, name, rec)
        local s = map[key]
        if not s then s = { key = key, name = name, recs = {} }; map[key] = s end
        s.recs[#s.recs + 1] = rec
        return s
    end

    for _, g in ipairs(OrderedGroups(groups, self.onlyBag)) do
        local isSpecial = g.family ~= 0 and db.specialSeparate
        for slot = 1, g.size do
            local rec = g.recs[slot]
            if rec then
                if isSpecial then
                    Add(specials, g.family, BP.FamilyName(g.family), rec)
                else
                    local key = BP.Classify(rec, order)
                    if key == "set" and rec.set then
                        Add(sections, "set:" .. rec.set, rec.set, rec)
                    else
                        Add(sections, key, BP.CategoryName(key), rec)
                    end
                end
            elseif db.emptyMode ~= "none" then
                local er = { bag = g.bag, slot = slot, empty = true, family = g.family, dim = self.queryParsed ~= nil }
                if db.emptyMode == "all" then
                    if isSpecial then
                        Add(specials, g.family, BP.FamilyName(g.family), er)
                    else
                        Add(sections, "free", "Free space", er)
                    end
                else
                    if isSpecial then
                        local sf = specialFree[g.family]
                        if not sf then sf = { count = 0, rec = er }; specialFree[g.family] = sf end
                        sf.count = sf.count + 1
                    else
                        free.count = free.count + 1
                        if not free.rec then free.rec = er end
                    end
                end
            end
        end
    end

    local list = {}
    for _, key in ipairs(order) do
        if key == "set" then
            local names = {}
            for k in pairs(sections) do
                if k:sub(1, 4) == "set:" then names[#names + 1] = k end
            end
            table.sort(names)
            for _, k in ipairs(names) do
                table.sort(sections[k].recs, BP.SectionComparator(sections[k].key))
                list[#list + 1] = sections[k]
            end
        else
            local s = sections[key]
            if s then
                table.sort(s.recs, BP.SectionComparator(s.key))
                list[#list + 1] = s
            end
        end
    end
    local fams = {}
    for fam in pairs(specials) do fams[#fams + 1] = fam end
    for fam in pairs(specialFree) do
        if not specials[fam] then
            fams[#fams + 1] = fam
            specials[fam] = { key = "s" .. fam, name = BP.FamilyName(fam), recs = {} }
        end
    end
    table.sort(fams)
    for _, fam in ipairs(fams) do
        local s = specials[fam]
        s.key = "s" .. fam
        table.sort(s.recs, BP.SectionComparator(s.key))
        local sf = specialFree[fam]
        if sf then
            sf.rec.free = sf.count
            s.shown = #s.recs + sf.count
            s.recs[#s.recs + 1] = sf.rec
        end
        list[#list + 1] = s
    end
    if sections.free then
        list[#list + 1] = sections.free
    elseif free.rec then
        free.rec.free = free.count
        list[#list + 1] = { key = "free", name = "Free space", recs = { free.rec }, shown = free.count }
    end

    -- pack sections in rows
    local totalW = cols * step - db.spacing
    local measure = self.measure
    local entries, headers = {}, {}
    local x, y, rowH = 0, 0, 0
    for _, s in ipairs(list) do
        local n = #s.recs
        local label = s.name .. " (" .. (s.shown or n) .. ")"
        measure:SetText(label)
        local hw = measure:GetStringWidth() + 26
        local collapsed = db.collapsed[s.key]
        local itemsW = (min(max(n, 1), cols)) * step - db.spacing
        local width = collapsed and min(hw, totalW) or min(max(itemsW, hw), totalW)
        local ncols = max(1, floor((width + db.spacing) / step))
        local itemsH = 0
        if not collapsed then
            itemsH = ceil(n / ncols) * step - db.spacing
        end
        local height = SECTION_H + (collapsed and 0 or itemsH + 2)
        if x > 0 and x + width > totalW + 0.5 then
            x = 0
            y = y + rowH + SECTION_GAP
            rowH = 0
        end
        headers[#headers + 1] = { key = s.key, text = label, x = x, y = y, w = width, collapsed = collapsed }
        if not collapsed then
            for idx, rec in ipairs(s.recs) do
                local i = idx - 1
                entries[#entries + 1] = {
                    rec = rec, x = x + (i % ncols) * step, y = y + SECTION_H + 2 + floor(i / ncols) * step,
                }
            end
        end
        rowH = max(rowH, height)
        x = x + width + SECTION_GAP
    end
    return entries, headers, totalW, y + rowH
end

------------------------------------------------------------------------
-- Window methods
------------------------------------------------------------------------
function M:IsLive()
    if self.kind == "bags" then return self.charKey == BP.myKey end
    if self.kind == "bank" then return self.charKey == BP.myKey and BP.bankOpen end
    return false
end

function M:GetLive(bag, slot)
    local key = bag .. ":" .. slot
    local b = self.live[key]
    if not b then
        local holder = self.holders[bag]
        if not holder then
            holder = CreateFrame("Frame", nil, self.content)
            holder:SetAllPoints(self.content)
            holder:SetID(bag)
            self.holders[bag] = holder
        end
        b = BP.NewLiveButton(holder, bag, slot)
        self.live[key] = b
        self.liveList[#self.liveList + 1] = b
    end
    return b
end

function M:GetHeader(i)
    local h = self.headerPool[i]
    if not h then
        h = CreateFrame("Button", nil, self.content)
        h:SetHeight(SECTION_H - 2)
        h.text = W.Gold(h, 11, "LEFT")
        h.text:SetPoint("LEFT", 0, 0)
        h.line = h:CreateTexture(nil, "ARTWORK")
        h.line:SetTexture(1, 0.82, 0, 0.35)
        h.line:SetHeight(1)
        h.line:SetPoint("BOTTOMLEFT", 0, 0)
        h.line:SetPoint("BOTTOMRIGHT", 0, 0)
        h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        h:SetScript("OnClick", function(s, btn)
            if btn == "RightButton" then
                if s.key == "free" then return end
                local base = BP.SortBase(s.key)
                local cur = BP.db.catSort[base] or "default"
                local items = { { text = "Sort " .. BP.CategoryName(base) .. " by", title = true } }
                for _, o in ipairs(BP.SORT_OPTIONS) do
                    items[#items + 1] = {
                        text = o.text, check = (o.value == cur),
                        func = function()
                            BP.db.catSort[base] = (o.value ~= "default") and o.value or nil
                            BP.Dirty()
                        end,
                    }
                end
                W.Menu(s, items, 170)
                return
            end
            BP.db.collapsed[s.key] = not BP.db.collapsed[s.key] or nil
            BP.Dirty()
        end)
        h:SetScript("OnEnter", function(s)
            s.text:SetTextColor(1, 1, 1)
            GameTooltip:SetOwner(s, "ANCHOR_TOPLEFT")
            GameTooltip:SetText("Click: collapse or expand", 1, 1, 1)
            if s.key ~= "free" then GameTooltip:AddLine("Right-click: change the item order", 0.7, 0.7, 0.7) end
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function(s) s.text:SetTextColor(1, 0.82, 0); GameTooltip:Hide() end)
        self.headerPool[i] = h
    end
    return h
end

function M:Apply(entries, headers, contentW, contentH)
    local db = BP.db
    local live = self.liveMode
    for _, b in ipairs(self.liveList) do b:Hide() end
    for _, b in ipairs(self.cached) do b:Hide() end
    for _, h in ipairs(self.headerPool) do h:Hide() end

    local used = 0
    for _, e in ipairs(entries) do
        local b
        if live then
            b = self:GetLive(e.rec.bag, e.rec.slot)
        else
            used = used + 1
            b = self.cached[used]
            if not b then
                b = BP.NewCachedButton(self.content)
                self.cached[used] = b
            end
        end
        BP.SizeButton(b, db.size)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.content, "TOPLEFT", e.x, -e.y)
        BP.ApplyButton(b, e.rec)
        b:Show()
    end

    for i, hd in ipairs(headers) do
        local h = self:GetHeader(i)
        h.key = hd.key
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", self.content, "TOPLEFT", hd.x, -hd.y)
        h:SetWidth(hd.w)
        h.text:SetText((hd.collapsed and "+ " or "") .. hd.text)
        h:Show()
    end

    local stripH = self.stripShown and STRIP_H or 0
    local width = max(contentW + 2 * PAD, MIN_WIDTH)
    Size(self.content, max(contentW, 1), max(contentH, 1))
    self.content:ClearAllPoints()
    self.content:SetPoint("TOPLEFT", self, "TOPLEFT", PAD, -(HEADER + stripH))
    Size(self, width, HEADER + stripH + max(contentH, 1) + FOOTER + PAD)
end

function M:CurrentGroups()
    if self.kind == "guild" then
        return CollectGuild(self.guildKey, self.tab), false
    end
    local live = self:IsLive()
    if live then return CollectLive(self.kind), true end
    return CollectCached(self.kind, self.charKey), false
end

function M:Refresh()
    local db = BP.db
    if not db then return end
    local groups, live = self:CurrentGroups()
    self.liveMode = live

    if self.onlyBag then
        local found
        for _, g in ipairs(groups) do if g.bag == self.onlyBag then found = true end end
        if not found then self.onlyBag = nil end
    end

    -- prepare records and apply the search
    local total, freeCount = 0, 0
    for _, g in ipairs(groups) do
        local counted = self.onlyBag and (g.bag == self.onlyBag) or (not self.onlyBag and g.bag ~= BP.KEYRING)
        if counted then total = total + g.size end
        for slot = 1, g.size do
            local rec = g.recs[slot]
            if rec then
                rec.family = g.family
                BP.Prepare(rec)
                if self.queryParsed then rec.dim = not BP.Search.Match(self.queryParsed, rec) end
            elseif counted then
                freeCount = freeCount + 1
            end
        end
    end

    local unfilled = 0
    for _, g in ipairs(groups) do
        for slot = 1, g.size do
            local rec = g.recs[slot]
            if rec and rec.link and not rec.filled then unfilled = unfilled + 1 end
        end
    end
    if unfilled > 0 and (self.retry or 0) < 6 then
        self.retry = (self.retry or 0) + 1
        BP.After(0.6, function() if self:IsShown() then self:Refresh() end end)
    end

    local layout
    local cols
    if self.kind == "guild" then
        layout = "single"; cols = db.colsBank
    elseif self.kind == "bank" then
        layout = db.layoutBank; cols = db.colsBank
    else
        layout = db.layoutBags; cols = db.colsBags
    end
    local entries, headers, cw, ch
    if layout == "category" then
        entries, headers, cw, ch = LayoutCategory(self, groups, cols)
    else
        entries, headers, cw, ch = LayoutSingle(self, groups, cols)
    end
    self:Apply(entries, headers, cw, ch)
    self:UpdateHeader(layout, live)
    self:UpdateStrip(groups, live)
    self:UpdateFooter(total, freeCount, live)
    self:SetScale(db.scale)
end

------------------------------------------------------------------------
-- Header, strip, footer
------------------------------------------------------------------------
local function ClassColor(class)
    local c = class and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

function M:UpdateHeader(layout, live)
    local label
    if self.kind == "guild" then
        local g = BagsPlusGuilds[self.guildKey or ""]
        label = g and g.name or "Guild bank"
        self.charBtn.text:SetTextColor(0.25, 1, 0.25)
    else
        local c = BagsPlusChars[self.charKey]
        label = (c and c.name or "?") .. (self.kind == "bank" and " - Bank" or "")
        self.charBtn.text:SetTextColor(ClassColor(c and c.class))
    end
    self.charBtn:SetLabel(label)
    local tw = self.charBtn.text:GetStringWidth() + 24
    Size(self.charBtn, max(tw, 110), 22)

    if self.layoutBtn then
        self.layoutBtn:SetLabel(layout == "category" and "Categories" or "Single")
    end
    if self.sortBtn then
        if live then self.sortBtn:Show() else self.sortBtn:Hide() end
    end
    if self.sellBtn then
        if live and BP.merchantOpen and self.kind == "bags" then self.sellBtn:Show() else self.sellBtn:Hide() end
    end
    if self.scanBtn then
        if BP.guildOpen then self.scanBtn:Show() else self.scanBtn:Hide() end
    end
end

function M:StripButton(i)
    local b = self.stripButtons[i]
    if not b then
        b = CreateFrame("Button", nil, self.strip)
        Size(b, 26, 26)
        W.Backdrop(b, 0.10, 0.10, 0.10, 1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnClick", function(s, btn)
            if s.guildTab then
                self.tab = s.guildTab
                self:Refresh()
                return
            end
            if btn == "RightButton" then
                self.onlyBag = nil
                self:Refresh()
                return
            end
            if CursorHasItem() and s.inv and self:IsLive() then
                PutItemInBag(s.inv)
            else
                self.onlyBag = (self.onlyBag ~= s.bag) and s.bag or nil
                self:Refresh()
            end
        end)
        b:SetScript("OnDragStart", function(s)
            if s.inv and self:IsLive() then PickupBagFromSlot(s.inv) end
        end)
        b:SetScript("OnReceiveDrag", function(s)
            if s.inv and self:IsLive() then PutItemInBag(s.inv) end
        end)
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            if s.guildTab then
                GameTooltip:SetText(s.tabName or ("Tab " .. s.guildTab), 1, 1, 1)
            elseif s.link then
                GameTooltip:SetHyperlink(s.link)
            else
                GameTooltip:SetText(s.title or "Bag", 1, 1, 1)
            end
            if not s.guildTab then
                GameTooltip:AddLine("Click: show only this bag. Right-click: show all.", 0.6, 0.6, 0.6)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.stripButtons[i] = b
    end
    return b
end

function M:UpdateStrip(groups, live)
    for _, b in ipairs(self.stripButtons) do b:Hide() end
    if self.purchase then self.purchase:Hide() end
    if not self.stripShown then return end
    local x = 0
    local idx = 0
    if self.kind == "guild" then
        local g = BagsPlusGuilds[self.guildKey or ""]
        if g then
            for tab = 1, (g.num or 0) do
                local t = g.tabs[tab]
                idx = idx + 1
                local b = self:StripButton(idx)
                b.guildTab, b.bag, b.inv, b.link = tab, nil, nil, nil
                b.tabName = t and t.name
                b.icon:SetTexture(t and t.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                b.icon:SetDesaturated(not t)
                b:SetBackdropBorderColor(self.tab == tab and 1 or 0, self.tab == tab and 0.82 or 0, 0, 1)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", self.strip, "TOPLEFT", x, -4)
                b:Show()
                x = x + 30
            end
        end
        return
    end
    for _, g in ipairs(groups) do
        idx = idx + 1
        local b = self:StripButton(idx)
        b.guildTab = nil
        b.bag = g.bag
        b.inv = nil
        b.link = g.link
        b.title = (g.bag == 0 and "Backpack") or (g.bag == BP.KEYRING and "Keyring (keys only)") or (g.bag == -1 and "Bank") or nil
        local icon = g.icon
        if live then
            if g.bag >= 1 and g.bag <= 4 then
                b.inv = ContainerIDToInventoryID(g.bag)
                b.link = GetInventoryItemLink("player", b.inv)
                icon = GetInventoryItemTexture("player", b.inv)
            elseif g.bag >= 5 then
                b.inv = BankButtonIDToInvSlotID(g.bag - 4, 1)
                b.link = GetInventoryItemLink("player", b.inv)
                icon = GetInventoryItemTexture("player", b.inv)
            elseif g.bag == 0 then
                icon = "Interface\\Buttons\\Button-Backpack-Up"
            elseif g.bag == BP.KEYRING then
                icon = "Interface\\ContainerFrame\\KeyRing-Bag-Icon"
            elseif g.bag == -1 then
                icon = "Interface\\Icons\\INV_Misc_Bag_09"
            end
        else
            if g.bag == -1 then icon = "Interface\\Icons\\INV_Misc_Bag_09" end
        end
        b.icon:SetTexture(icon or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        b.icon:SetDesaturated(false)
        local on = (self.onlyBag == g.bag)
        b:SetBackdropBorderColor(on and 1 or 0, on and 0.82 or 0, 0, 1)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.strip, "TOPLEFT", x, -4)
        b:Show()
        x = x + 30
    end
    if self.kind == "bank" and live and self.purchase then
        local num, full = GetNumBankSlots()
        if not full then
            self.purchase:ClearAllPoints()
            self.purchase:SetPoint("TOPLEFT", self.strip, "TOPLEFT", x + 6, -4)
            self.purchase.cost = GetBankSlotCost(num)
            self.purchase:Show()
        end
    end
end

function M:UpdateFooter(total, free, live)
    local money
    if self.kind == "guild" then
        local g = BagsPlusGuilds[self.guildKey or ""]
        money = g and g.money
    else
        local c = BagsPlusChars[self.charKey]
        money = live and BP.myKey == self.charKey and GetMoney() or (c and c.money)
    end
    self.money:SetText(money and BP.Money(money) or "")
    self.free:SetText(total > 0 and (free .. "/" .. total) or "")
    local cur = ""
    if self.kind == "bags" and live and BP.db.showCurrency then
        for i = 1, 3 do
            local name, count, _, icon = GetBackpackCurrencyInfo(i)
            if name and icon then
                cur = cur .. "|T" .. icon .. ":13:13:0:0|t " .. count .. "  "
            end
        end
    end
    self.currency:SetText(cur)
end

function M:SetSearch(text)
    self.search:SetText(text or "")
    self.queryParsed = BP.Search.Parse(text)
    if not text or text == "" then self.placeholder:Show() end
    self:Refresh()
end

function M:SetChar(key)
    self.charKey = key
    self.onlyBag = nil
    self:Refresh()
end

function M:SavePosition()
    local p, _, rp, x, y = self:GetPoint()
    BP.db.pos[self.kind] = { p, rp, x, y }
end

local DEFAULT_POS = {
    bags = { "BOTTOMRIGHT", "BOTTOMRIGHT", -60, 110 },
    bank = { "TOPLEFT", "TOPLEFT", 40, -110 },
    guild = { "TOPLEFT", "TOPLEFT", 80, -130 },
}

function M:RestorePosition()
    local p = BP.db.pos[self.kind] or DEFAULT_POS[self.kind]
    self:ClearAllPoints()
    self:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

function M:CharMenu(anchor)
    local items = {}
    if self.kind == "guild" then
        items[1] = { text = "Guilds", title = true }
        for key, g in pairs(BagsPlusGuilds) do
            items[#items + 1] = {
                text = g.name .. " (" .. g.realm .. ")", check = (key == self.guildKey),
                color = { 0.25, 1, 0.25 },
                func = function()
                    self.guildKey = key
                    self.tab = 1
                    self:Refresh()
                end,
            }
        end
    else
        items[1] = { text = "Characters", title = true }
        for _, e in ipairs(D.Characters()) do
            local c = e.c
            local label = c.name
            if c.realm ~= GetRealmName() then label = label .. " - " .. c.realm end
            local r, g, b = ClassColor(c.class)
            local key = e.key
            items[#items + 1] = {
                text = label, check = (key == self.charKey), color = { r, g, b },
                func = function() self:SetChar(key) end,
            }
        end
    end
    W.Menu(anchor, items, 150)
end

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------
function BP.CreateWindow(kind)
    local db = BP.db
    local f = CreateFrame("Frame", "BagsPlusFrame_" .. kind, UIParent)
    for k, v in pairs(M) do f[k] = v end
    f.kind = kind
    f.charKey = BP.myKey
    f.tab = 1
    f.live, f.liveList, f.holders, f.cached = {}, {}, {}, {}
    f.headerPool, f.stripButtons = {}, {}
    f.stripShown = (kind == "guild")
    f:SetFrameStrata(BP.db.strata or "HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    W.Backdrop(f, 0.06, 0.06, 0.06, db.alpha)
    Size(f, 400, 300)
    f:Hide()

    f:SetScript("OnDragStart", function(s) if not BP.db.lock then s:StartMoving() end end)
    f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); s:SavePosition() end)
    f:SetScript("OnShow", function(s)
        s.retry = 0
        s:SetFrameStrata(BP.db.strata or "HIGH")
        s:Raise()
        s:RestorePosition()
        s:SetBackdropColor(0.06, 0.06, 0.06, BP.db.alpha)
        s:Refresh()
    end)
    f:SetScript("OnHide", function(s)
        W.CloseMenu()
        if kind == "bank" and BP.bankOpen then CloseBankFrame() end
        if kind == "bags" and BP.db.clearNewOnClose and not BP.db.manualSort then BP.ClearNew() end
    end)

    f.measure = W.Text(f, 11, 1, 1, 1)
    f.measure:Hide()

    -- header row 1
    f.charBtn = W.Button(f, "", 140, 22, function(s) f:CharMenu(s) end)
    f.charBtn:SetPoint("TOPLEFT", PAD, -7)

    local close = W.Button(f, "x", 22, 22, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -PAD, -7)
    local cog = W.Button(f, "*", 22, 22, function() BP.OpenSettings() end)
    cog:SetPoint("RIGHT", close, "LEFT", -4, 0)
    cog.tip = "Settings"

    -- header row 2: search + buttons (right to left)
    local right = f
    local function Add(text, w, fn, tip, tip2)
        local b = W.Button(f, text, w, 22, fn)
        if right == f then
            b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -33)
        else
            b:SetPoint("RIGHT", right, "LEFT", -4, 0)
        end
        b.tip, b.tip2 = tip, tip2
        right = b
        return b
    end

    f.stripBtn = Add("Bags", 44, function(s)
        f.stripShown = not f.stripShown
        s:SetSelected(f.stripShown)
        f:Refresh()
    end, "Bag slots", "Show the bags. Click one to show only its items.")
    f.stripBtn:SetSelected(f.stripShown)
    if kind == "guild" then f.stripBtn:Hide() end

    if kind ~= "guild" then
        f.layoutBtn = Add("Single", 78, function()
            local key = (kind == "bank") and "layoutBank" or "layoutBags"
            BP.db[key] = (BP.db[key] == "category") and "single" or "category"
            f:Refresh()
        end, "Layout", "Switch between one grid and grouped categories.")
        f.sortBtn = Add("Sort", 44, function() BP.Sort(kind) end, "Sort", "Combine stacks and sort in place.")
    end
    if kind == "bags" then
        f.sellBtn = Add("Sell junk", 70, function() BP.SellJunk() end, "Sell junk", "Sell every grey item to the vendor.")
        f.sellBtn:Hide()
    end
    if kind == "guild" then
        f.scanBtn = Add("Scan tabs", 70, function() BP.ScanAllGuildTabs() end, "Scan tabs", "Open every tab once to save its contents.")
        f.scanBtn:Hide()
    end

    f.search = W.EditBox(f, 100, 22, nil)
    f.search:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -33)
    f.search:SetPoint("RIGHT", right, "LEFT", -6, 0)
    f.placeholder = W.Text(f.search, 12, 0.45, 0.45, 0.45)
    f.placeholder:SetPoint("LEFT", 7, 0)
    f.placeholder:SetText("Search (e.g. epic ilvl:>=200)")
    f.search:SetScript("OnTextChanged", function(s)
        local t = s:GetText()
        f.queryParsed = BP.Search.Parse(t)
        if t == "" then f.placeholder:Show() else f.placeholder:Hide() end
        BP.Dirty()
    end)
    f.search:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Search", 1, 1, 1)
        GameTooltip:AddLine(BP.Search.help, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    f.search:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- strip
    f.strip = CreateFrame("Frame", nil, f)
    Size(f.strip, 200, STRIP_H)
    f.strip:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -HEADER)
    f.strip:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -HEADER)
    if kind == "bank" then
        f.purchase = W.Button(f.strip, "Buy slot", 66, 26, function()
            StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
        end)
        f.purchase:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText("Buy a bank bag slot", 1, 1, 1)
            if s.cost then GameTooltip:AddLine(BP.Money(s.cost), 1, 1, 1) end
            GameTooltip:Show()
        end)
        f.purchase:Hide()
    end

    -- content
    f.content = CreateFrame("Frame", nil, f)
    Size(f.content, 100, 100)
    f.content:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -HEADER)

    -- footer
    f.money = W.Text(f, 12, 1, 1, 1, "LEFT")
    f.money:SetPoint("BOTTOMLEFT", PAD, 9)
    f.free = W.Text(f, 12, 0.7, 0.7, 0.7, "RIGHT")
    f.free:SetPoint("BOTTOMRIGHT", -PAD - 12, 9)
    f.currency = W.Text(f, 12, 1, 1, 1, "RIGHT")
    f.currency:SetPoint("RIGHT", f.free, "LEFT", -12, 0)
    if kind == "bags" then
        local cb = CreateFrame("Button", nil, f)
        cb:SetAllPoints(f.currency)
        cb:SetScript("OnClick", function() ToggleCharacter("TokenFrame") end)
    end

    -- resize grip (bottom right): dragging changes the number of columns
    local grip = CreateFrame("Button", nil, f)
    Size(grip, 16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(f:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    for _, t in ipairs({ grip:GetNormalTexture(), grip:GetPushedTexture(), grip:GetHighlightTexture() }) do
        if t then t:SetVertexColor(1, 0.82, 0) end
    end
    grip:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText("Resize", 1, 1, 1)
        GameTooltip:AddLine("Drag to change the number of columns.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    grip:SetScript("OnMouseDown", function(s, btn)
        if btn ~= "LeftButton" then return end
        local l, b = f:GetLeft(), f:GetBottom()
        if not l or not b then return end
        f:ClearAllPoints()
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
        s:SetScript("OnUpdate", function()
            local d = BP.db
            local step = d.size + d.spacing
            local cx = GetCursorPosition() / f:GetEffectiveScale()
            local width = cx - f:GetLeft()
            local cols = floor((width - 2 * PAD + d.spacing) / step + 0.5)
            local key, lo, hi
            if kind == "bags" then key, lo, hi = "colsBags", 6, 20 else key, lo, hi = "colsBank", 8, 24 end
            cols = min(max(cols, lo), hi)
            if cols ~= d[key] then
                d[key] = cols
                f:Refresh()
            end
        end)
    end)
    grip:SetScript("OnMouseUp", function(s)
        s:SetScript("OnUpdate", nil)
        f:SavePosition()
    end)
    f.grip = grip

    BP.windows[kind] = f
    return f
end

-- ESC closes the windows (toggled from the settings)
function BP.ApplyEsc()
    for kind, f in pairs(BP.windows) do
        local name = f:GetName()
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == name then tremove(UISpecialFrames, i) end
        end
        if BP.db.closeWithEsc then tinsert(UISpecialFrames, name) end
    end
end

function BP.ApplyLook()
    for _, f in pairs(BP.windows) do
        f:SetFrameStrata(BP.db.strata or "HIGH")
        f:SetScale(BP.db.scale)
        f:SetBackdropColor(0.06, 0.06, 0.06, BP.db.alpha)
    end
    BP.Dirty()
end
