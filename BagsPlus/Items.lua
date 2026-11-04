local ADDON, BP = ...
local W = BP.W
local WHITE = W.WHITE

------------------------------------------------------------------------
-- Item info
------------------------------------------------------------------------
local LINK_QUALITY = {
    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3,
    ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6, ["00ccff"] = 7,
}
function BP.LinkQuality(link)
    local hex = link and link:match("|c%x%x(%x%x%x%x%x%x)")
    return hex and LINK_QUALITY[hex:lower()]
end

function BP.Fill(rec)
    if rec.filled or not rec.link then return rec end
    local link = rec.link
    rec.id = tonumber(link:match("item:(%d+)"))
    local name, _, q, ilvl, lvl, itype, sub, stack, equip, _, price = GetItemInfo(link)
    if name then
        rec.name = name
        if rec.quality == nil or rec.quality < 0 then rec.quality = q end
        rec.ilvl = ilvl
        rec.reqLevel = lvl
        rec.type = itype
        rec.sub = sub
        rec.stack = stack
        rec.equip = equip
        rec.price = price or 0
        rec.filled = true
    else
        rec.name = link:match("%[(.-)%]") or "?"
    end
    if rec.quality == nil or rec.quality < 0 then rec.quality = BP.LinkQuality(link) or 1 end
    return rec
end

------------------------------------------------------------------------
-- Tooltip scanning (bind type, unusable)
------------------------------------------------------------------------
local tip = CreateFrame("GameTooltip", "BagsPlusScanTip", nil, "GameTooltipTemplate")
local scanCache = {}

function BP.InvalidateScan() wipe(scanCache) end

local function IsRed(r, g, b)
    return r and r > 0.9 and g < 0.25 and b < 0.25
end

function BP.ScanLive(rec)
    if not rec.live or not rec.link then return end
    local key = rec.bag .. ":" .. rec.slot
    local c = scanCache[key]
    if c and c.link == rec.link then
        rec.bound, rec.bind, rec.unusable, rec.tt = c.bound, c.bind, c.unusable, c.tt
        return
    end
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:ClearLines()
    if rec.bag == -1 then
        tip:SetInventoryItem("player", BankButtonIDToInvSlotID(rec.slot))
    else
        tip:SetBagItem(rec.bag, rec.slot)
    end
    local bound, bind, unusable = false, nil, false
    local lines = {}
    for i = 1, tip:NumLines() do
        local l = _G["BagsPlusScanTipTextLeft" .. i]
        local r = _G["BagsPlusScanTipTextRight" .. i]
        local t = l and l:GetText()
        if t then
            lines[#lines + 1] = t:lower()
            if i > 1 then
                if t == ITEM_SOULBOUND then bound = true
                elseif t == ITEM_BIND_ON_EQUIP then bind = "BoE"
                elseif t == ITEM_BIND_ON_PICKUP then bind = "BoP"
                elseif t == ITEM_BIND_ON_USE then bind = "BoU"
                elseif t == ITEM_BIND_TO_ACCOUNT or t == ITEM_ACCOUNTBOUND then bind = "BoA"; bound = true
                elseif t == ITEM_BIND_QUEST then bound = true
                end
                if IsRed(l:GetTextColor()) then unusable = true end
            end
        end
        if r and r:IsShown() then
            local rt = r:GetText()
            if rt then
                lines[#lines + 1] = rt:lower()
                if IsRed(r:GetTextColor()) then unusable = true end
            end
        end
    end
    if bound then bind = nil end
    local text = table.concat(lines, "\n")
    scanCache[key] = { link = rec.link, bound = bound, bind = bind, unusable = unusable, tt = text }
    rec.bound, rec.bind, rec.unusable, rec.tt = bound, bind, unusable, text
end

-- Tooltip text for search (works for cached items too, by link)
local textCache = {}
function BP.TooltipText(rec)
    if rec.tt then return rec.tt end
    if not rec.link then return "" end
    local c = textCache[rec.link]
    if c then return c end
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetHyperlink(rec.link)
    local lines = {}
    for i = 1, tip:NumLines() do
        local l = _G["BagsPlusScanTipTextLeft" .. i]
        local r = _G["BagsPlusScanTipTextRight" .. i]
        if l and l:GetText() then lines[#lines + 1] = l:GetText():lower() end
        if r and r:IsShown() and r:GetText() then lines[#lines + 1] = r:GetText():lower() end
    end
    c = table.concat(lines, "\n")
    textCache[rec.link] = c
    return c
end

------------------------------------------------------------------------
-- Equipment sets and new items
------------------------------------------------------------------------
BP.setMap = {}
BP.new = {}
local known = {}
BP.newReady = false

function BP.UpdateSets()
    wipe(BP.setMap)
    if not GetNumEquipmentSets then return end
    for i = 1, GetNumEquipmentSets() do
        local name = GetEquipmentSetInfo(i)
        if name then
            local ids = GetEquipmentSetItemIDs(name)
            if ids then
                for _, id in pairs(ids) do
                    if id and id > 0 then BP.setMap[id] = name end
                end
            end
        end
    end
end

-- New items are marked per stack (bag:slot -> item id). When your total of an item goes up,
-- only the stack that grew, or the stack that was just created, is marked.
local prevSnap = {}

function BP.TrackNew(skipMarking)
    local totals, snap = {}, {}
    -- worn gear and equipped bags count too, so swapping gear (spec change, equipment sets)
    -- moves items between worn and carried without looking like a gain
    for inv = 0, 23 do
        local l = GetInventoryItemLink("player", inv)
        if l then
            local id = tonumber(l:match("item:(%d+)"))
            if id then
                local c = GetInventoryItemCount and GetInventoryItemCount("player", inv) or 1
                totals[id] = (totals[id] or 0) + ((c and c > 0) and c or 1)
            end
        end
    end
    for bag = 0, 4 do
        local n = GetContainerNumSlots(bag)
        for slot = 1, (n or 0) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local id = tonumber(link:match("item:(%d+)"))
                local _, count = GetContainerItemInfo(bag, slot)
                count = count or 1
                totals[id] = (totals[id] or 0) + count
                snap[bag .. ":" .. slot] = { id = id, count = count }
            end
        end
    end
    if BP.newReady and not BP.bankOpen and not skipMarking then
        for key, s in pairs(snap) do
            if totals[s.id] > (known[s.id] or 0) then
                local p = prevSnap[key]
                if not p or p.id ~= s.id or s.count > p.count then BP.new[key] = s.id end
            end
        end
    end
    -- a mark ends when its stack is gone or the slot now holds something else
    if BP.pruneOK then
        for key, id in pairs(BP.new) do
            if not snap[key] or snap[key].id ~= id then BP.new[key] = nil end
        end
    end
    known, prevSnap = totals, snap
end

-- Judge changes only once the bags have been quiet for a moment: a gear swap moves items in
-- several steps, and the first step alone would look like a gain.
local due, pendingSkip
function BP.TrackNewSoon()
    pendingSkip = pendingSkip or BP.bankOpen
    due = GetTime() + 0.6
    if BP.newWaiting then return end
    BP.newWaiting = true
    local function check()
        local left = due - GetTime()
        if left > 0 then BP.After(left + 0.02, check); return end
        BP.newWaiting = false
        local skip = pendingSkip
        pendingSkip = nil
        BP.TrackNew(skip)
        BP.Dirty()
    end
    BP.After(0.62, check)
end

function BP.ClearNew()
    wipe(BP.new)
end

-- Fill a record with everything the views need.
function BP.Prepare(rec)
    BP.Fill(rec)
    if not rec.link then return rec end
    rec.isNew = (rec.live and rec.bag and rec.slot and BP.new[rec.bag .. ":" .. rec.slot] == rec.id) and true or false
    rec.set = BP.setMap[rec.id]
    if rec.live then
        if GetContainerItemQuestInfo then
            local isQ, qid = GetContainerItemQuestInfo(rec.bag, rec.slot)
            rec.quest = (isQ or qid) and true or false
        end
        BP.ScanLive(rec)
    end
    return rec
end

------------------------------------------------------------------------
-- Item buttons
------------------------------------------------------------------------
local QUALITY = {}
for q = 0, 7 do
    local r, g, b = GetItemQualityColor(q)
    QUALITY[q] = { r, g, b }
end
BP.QUALITY = QUALITY

local pulsing = {}
local pf = CreateFrame("Frame")
local pt = 0
pf:SetScript("OnUpdate", function(_, el)
    pt = pt + el
    local a = 0.35 + 0.35 * math.abs(math.sin(pt * 2.2))
    for b in pairs(pulsing) do b.glow:SetAlpha(a) end
end)

local function StyleButton(b, live)
    local name = b:GetName()
    b:SetNormalTexture(nil)
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    if nt then nt:SetTexture(nil); nt:SetAlpha(0) end

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetTexture(0.10, 0.10, 0.10, 1)
    b.bg:SetAllPoints(b)

    b.icon = (name and _G[name .. "IconTexture"]) or b:CreateTexture(nil, "ARTWORK")
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    b.count = (name and _G[name .. "Count"]) or b:CreateFontString(nil, "OVERLAY")
    b.count:ClearAllPoints()
    b.count:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b.count:SetJustifyH("RIGHT")
    b.count:SetDrawLayer("OVERLAY", 7)
    b.count:Show()
    if name and _G[name .. "Stock"] then _G[name .. "Stock"]:SetText("") end
    b.cooldown = name and _G[name .. "Cooldown"] or nil

    b.border = CreateFrame("Frame", nil, b)
    b.border:SetAllPoints(b)
    b.border:SetFrameLevel(b:GetFrameLevel() + 3)
    b.border:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    b.border:SetBackdropBorderColor(0, 0, 0, 1)

    b.glow = b.border:CreateTexture(nil, "OVERLAY")
    b.glow:SetTexture(1, 0.82, 0, 0.5)
    b.glow:SetAllPoints(b)
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()

    b:SetHighlightTexture(WHITE)
    local ht = b:GetHighlightTexture()
    ht:SetVertexColor(1, 1, 1, 0.22)
    ht:SetBlendMode("ADD")
    ht:SetAllPoints(b)
    if b.SetPushedTexture then
        b:SetPushedTexture(WHITE)
        local pu = b:GetPushedTexture()
        if pu then pu:SetVertexColor(1, 1, 1, 0.12) end
    end

    -- corner widgets
    b.cf, b.ci = {}, {}
    local layer = CreateFrame("Frame", nil, b)
    layer:SetAllPoints(b)
    layer:SetFrameLevel(b:GetFrameLevel() + 4)
    local corners = { TL = { "TOPLEFT", 2, -2 }, TR = { "TOPRIGHT", -2, -2 }, BL = { "BOTTOMLEFT", 2, 2 } }
    for pos, p in pairs(corners) do
        local fs = layer:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 12, "THICKOUTLINE")
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
        fs:SetPoint(p[1], p[2], p[3])
        b.cf[pos] = fs
        local t = layer:CreateTexture(nil, "OVERLAY")
        t:SetWidth(12); t:SetHeight(12)
        t:SetPoint(p[1], p[2], p[3])
        t:Hide()
        b.ci[pos] = t
    end

    b.coin = layer:CreateTexture(nil, "OVERLAY")
    b.coin:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
    b.coin:SetWidth(14); b.coin:SetHeight(14)
    b.coin:SetPoint("TOPRIGHT", -1, -1)
    b.coin:Hide()

    b.live = live
end

local CORNER_ICONS = {
    junk = { "Interface\\MoneyFrame\\UI-GoldIcon", 0, 1, 0, 1 },
    set = { "Interface\\Icons\\INV_Shield_05", 0.08, 0.92, 0.08, 0.92 },
    quest = { "Interface\\GossipFrame\\AvailableQuestIcon", 0, 1, 0, 1 },
}

local BIND_COLORS = {
    BoE = { 0.4, 1, 0.4 }, BoP = { 1, 0.35, 0.35 }, BoU = { 1, 0.85, 0.3 }, BoA = { 0.4, 0.8, 1 },
}

local function Corner(b, pos, kind, rec)
    local fs, tex = b.cf[pos], b.ci[pos]
    fs:SetFont(STANDARD_TEXT_FONT, BP.db.ilvlSize or 12, "THICKOUTLINE")
    fs:SetText("")
    tex:Hide()
    if not rec or rec.empty or not rec.link then return end
    if kind == "ilvl" then
        if rec.ilvl and rec.equip and rec.equip ~= "" and (rec.quality or 0) >= BP.db.ilvlMinQuality then
            fs:SetText(rec.ilvl)
            if BP.db.ilvlQualityColor then
                local c = QUALITY[rec.quality] or QUALITY[1]
                fs:SetTextColor(c[1], c[2], c[3])
            else
                fs:SetTextColor(1, 1, 1)
            end
        end
    elseif kind == "bind" then
        if rec.bind then
            local c = BIND_COLORS[rec.bind]
            fs:SetText(rec.bind)
            fs:SetTextColor(c[1], c[2], c[3])
        end
    elseif kind == "junk" then
        if rec.quality == 0 and (rec.price or 0) > 0 then
            local i = CORNER_ICONS.junk
            tex:SetTexture(i[1]); tex:SetTexCoord(i[2], i[3], i[4], i[5]); tex:Show()
        end
    elseif kind == "set" then
        if rec.set then
            local i = CORNER_ICONS.set
            tex:SetTexture(i[1]); tex:SetTexCoord(i[2], i[3], i[4], i[5]); tex:Show()
        end
    elseif kind == "quest" then
        if rec.quest then
            local i = CORNER_ICONS.quest
            tex:SetTexture(i[1]); tex:SetTexCoord(i[2], i[3], i[4], i[5]); tex:Show()
        end
    end
end

-- Paint a button from a record. rec may be nil (empty slot).
function BP.ApplyButton(b, rec)
    local db = BP.db
    b.rec = rec
    local has = rec and rec.link and not rec.empty
    if has then
        b.icon:SetTexture(rec.tex)
        b.icon:Show()
        b.count:SetText((rec.count or 1) > 1 and rec.count or "")
    else
        b.icon:SetTexture(nil)
        b.icon:Hide()
        if rec and rec.free and rec.free > 0 then
            b.count:SetText(rec.free)
        else
            b.count:SetText("")
        end
    end

    b.count:SetFont(STANDARD_TEXT_FONT, db.ilvlSize or 12, "THICKOUTLINE")
    b.count:SetShadowColor(0, 0, 0, 1)
    b.count:SetShadowOffset(1, -1)
    b.count:SetTextColor(1, 1, 1)
    b.count:Show()

    -- border colour: quest, then quality, then the colour of a special bag
    local r, g, bl = 0, 0, 0
    local fam = db.specialColors and rec and BP.FamilyColor(rec.family) or nil
    if has then
        if db.showQuest and rec.quest then
            r, g, bl = 1, 0.6, 0
        elseif db.qualityBorder and (rec.quality or 0) >= (db.borderMinQuality or 1) then
            local c = QUALITY[rec.quality] or QUALITY[1]
            r, g, bl = c[1], c[2], c[3]
        elseif fam then
            r, g, bl = fam[1], fam[2], fam[3]
        end
    elseif fam then
        r, g, bl = fam[1], fam[2], fam[3]
    end
    b.border:SetBackdropBorderColor(r, g, bl, 1)
    if fam then
        b.bg:SetTexture(fam[1] * 0.22, fam[2] * 0.22, fam[3] * 0.22, 1)
    else
        b.bg:SetTexture(0.10, 0.10, 0.10, 1)
    end

    -- red tint for unusable
    if has and db.showUnusable and rec.unusable then
        b.icon:SetVertexColor(1, 0.25, 0.25)
    else
        b.icon:SetVertexColor(1, 1, 1)
    end
    b.icon:SetDesaturated(has and rec.locked and true or false)

    -- new item pulse
    if has and db.showNew and rec.isNew then
        b.glow:Show()
        pulsing[b] = true
    else
        b.glow:Hide()
        pulsing[b] = nil
    end

    if has and db.junkCoin and rec.quality == 0 then b.coin:Show() else b.coin:Hide() end

    Corner(b, "TL", db.cornerTL, rec)
    Corner(b, "TR", db.cornerTR, rec)
    Corner(b, "BL", db.cornerBL, rec)

    b:SetAlpha((rec and rec.dim) and 0.25 or 1)

    if b.live and b.cooldown then
        if has then
            local start, dur, enable = GetContainerItemCooldown(rec.bag, rec.slot)
            CooldownFrame_SetTimer(b.cooldown, start or 0, dur or 0, enable or 0)
        else
            CooldownFrame_SetTimer(b.cooldown, 0, 0, 0)
        end
    end
end

local counter = 0

function BP.AddTooltipInfo(rec)
    if not (BP.db.tooltipInfo and rec and rec.link and not rec.empty) then return end
    BP.Fill(rec)
    local key = BP.Classify(rec)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Bags Plus: " .. BP.CategoryName(key), 1, 0.82, 0)
    GameTooltip:AddLine("type: " .. tostring(rec.type) .. "  |  sub: " .. tostring(rec.sub) ..
        "  |  slot: " .. ((rec.equip and rec.equip ~= "") and rec.equip or "none"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

-- Live button: secure Blizzard item template so clicks, drags, splits and vendor cursors just work.
function BP.NewLiveButton(holder, bag, slot)
    counter = counter + 1
    local tmpl = (bag == -1) and "BankItemButtonGenericTemplate" or "ContainerFrameItemButtonTemplate"
    local b = CreateFrame("Button", "BagsPlusItem" .. counter, holder, tmpl)
    b:SetID(slot)
    b.bag, b.slot = bag, slot
    b:SetWidth(36); b:SetHeight(36)
    if bag == -1 then
        b:UnregisterAllEvents()
        b:SetScript("OnEvent", nil)
    end
    StyleButton(b, true)
    b:HookScript("OnEnter", function(s)
        local rec = s.rec
        if rec and rec.id and rec.live and BP.new[rec.bag .. ":" .. rec.slot] and not BP.db.manualSort then
            BP.new[rec.bag .. ":" .. rec.slot] = nil
            rec.isNew = false
            s.glow:Hide()
            pulsing[s] = nil
        end
        BP.AddTooltipInfo(rec)
    end)
    return b
end

-- Cached button: plain frame, read-only, tooltip from the saved link.
function BP.NewCachedButton(parent)
    counter = counter + 1
    local b = CreateFrame("Button", "BagsPlusCached" .. counter, parent)
    b:SetWidth(36); b:SetHeight(36)
    b:RegisterForClicks("LeftButtonUp")
    StyleButton(b, false)
    b:SetScript("OnEnter", function(s)
        local rec = s.rec
        if rec and rec.link and not rec.empty then
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(rec.link)
            GameTooltip:Show()
            BP.AddTooltipInfo(rec)
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(s)
        local rec = s.rec
        if not (rec and rec.link and not rec.empty) then return end
        if IsModifiedClick("CHATLINK") then
            ChatEdit_InsertLink(rec.link)
        elseif IsModifiedClick("DRESSUP") then
            DressUpItemLink(rec.link)
        end
    end)
    return b
end

function BP.SizeButton(b, size)
    b:SetWidth(size)
    b:SetHeight(size)
end
