local ADDON, BP = ...

local frame = CreateFrame("Frame")
frame:Hide()

local state = nil

local function BagIDs(kind)
    local list = (kind == "bank") and BP.BANK_BAGS or { 0, 1, 2, 3, 4 }
    local out = {}
    for _, bag in ipairs(list) do
        local n = GetContainerNumSlots(bag)
        if n and n > 0 then out[#out + 1] = bag end
    end
    return out
end

local function Fits(link, family)
    if family == 0 then return true end
    local f = GetItemFamily(link) or 0
    return bit.band(f, family) ~= 0
end

-- Read every slot. Returns groups (by bag family) and a flat list, plus whether anything is locked.
local function Read(bags)
    local groups, order, flat = {}, {}, {}
    local locked = false
    for _, bag in ipairs(bags) do
        local fam = 0
        if bag >= 0 then
            local _, f = GetContainerNumFreeSlots(bag)
            fam = f or 0
        end
        local g = groups[fam]
        if not g then
            g = { family = fam, slots = {} }
            groups[fam] = g
            order[#order + 1] = g
        end
        for slot = 1, GetContainerNumSlots(bag) do
            local tex, count, lk = GetContainerItemInfo(bag, slot)
            local s = { bag = bag, slot = slot, family = fam }
            if tex then
                s.link = GetContainerItemLink(bag, slot)
                s.count = count or 1
                s.live = true
                s.key = (s.link or "?") .. ":" .. s.count
                BP.Fill(s)
            else
                s.key = ""
            end
            if lk then locked = true end
            g.slots[#g.slots + 1] = s
            flat[#flat + 1] = s
        end
    end
    -- special groups first, general bags last
    table.sort(order, function(a, b)
        if (a.family == 0) ~= (b.family == 0) then return a.family ~= 0 end
        return a.family < b.family
    end)
    return order, flat, locked
end

local function Pick(s) PickupContainerItem(s.bag, s.slot) end

local function Stop(msg)
    frame:Hide()
    state = nil
    if msg then BP.Print(msg) end
end

local function Step()
    if CursorHasItem() then return true end
    local groups, flat, locked = Read(state.bags)
    if locked then return true end

    -- 1. merge partial stacks
    local partial = {}
    for _, s in ipairs(flat) do
        if s.link and s.stack and s.stack > 1 and s.count < s.stack then
            local list = partial[s.id]
            if not list then list = {}; partial[s.id] = list end
            list[#list + 1] = s
        end
    end
    for _, list in pairs(partial) do
        if #list >= 2 then
            table.sort(list, function(a, b) return a.count < b.count end)
            local src = list[1]
            for k = #list, 2, -1 do
                local dst = list[k]
                if Fits(src.link, dst.family) then
                    Pick(src); Pick(dst)
                    state.sig = nil
                    return true
                end
            end
        end
    end

    -- 2. fill special bags with items from general bags
    for _, g in ipairs(groups) do
        if g.family ~= 0 then
            local free
            for _, s in ipairs(g.slots) do
                if not s.link then free = s; break end
            end
            if free then
                for _, s in ipairs(flat) do
                    if s.link and s.family == 0 and Fits(s.link, g.family) then
                        Pick(s); Pick(free)
                        state.sig = nil
                        return true
                    end
                end
            end
        end
    end

    -- 3. order each group: swap the first wrong slot with the item that belongs there
    local cmp = BP.Comparator(BP.db.sort)
    for _, g in ipairs(groups) do
        local items = {}
        for _, s in ipairs(g.slots) do
            if s.link then items[#items + 1] = s end
        end
        table.sort(items, cmp)
        local n = #g.slots
        local want = {}
        for i = 1, n do want[i] = items[i] and items[i].key or "" end
        for i = 1, n do
            local cur = g.slots[i]
            if cur.key ~= want[i] then
                local pick
                for j = i + 1, n do
                    local c = g.slots[j]
                    if c.key == want[i] then
                        if c.key ~= want[j] then pick = c; break end
                        pick = pick or c
                    end
                end
                if pick then
                    local sig = i .. ":" .. cur.key .. ">" .. pick.bag .. ":" .. pick.slot
                    if state.sig == sig then
                        state.same = state.same + 1
                        if state.same > 6 then
                            Stop("Sorting stopped: a move did not go through.")
                            return false
                        end
                    else
                        state.sig = sig
                        state.same = 0
                    end
                    Pick(pick)
                    Pick(cur)
                    if cur.link then Pick(pick) end
                    return true
                end
            end
        end
    end

    Stop("Sorting done.")
    return false
end

local acc = 0
frame:SetScript("OnUpdate", function(_, el)
    acc = acc + el
    if acc < 0.08 then return end
    acc = 0
    if not state then frame:Hide(); return end
    state.ticks = state.ticks + 1
    if state.ticks > 2500 then Stop("Sorting stopped (too long).") return end
    Step()
end)

function BP.Sort(kind)
    if state then return end
    if kind == "bank" and not BP.bankOpen then
        BP.Print("Open the bank to sort it.")
        return
    end
    if CursorHasItem() then
        BP.Print("Put down the item on your cursor first.")
        return
    end
    local bags = BagIDs(kind)
    if #bags == 0 then return end
    state = { bags = bags, ticks = 0, same = 0 }
    BP.ClearNew()
    BP.Dirty()
    frame:Show()
end

function BP.IsSorting() return state ~= nil end
