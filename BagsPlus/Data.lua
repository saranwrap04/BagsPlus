local ADDON, BP = ...
local D = {}
BP.Data = D

BP.BANK_BAGS = { -1, 5, 6, 7, 8, 9, 10, 11 }
BP.KEYRING = KEYRING_CONTAINER or -2

BP.FAMILY = {
    [1] = "Quiver", [2] = "Ammo Pouch", [4] = "Soul Bag", [8] = "Leatherworking Bag",
    [16] = "Inscription Bag", [32] = "Herb Bag", [64] = "Enchanting Bag",
    [128] = "Engineering Bag", [256] = "Keyring", [512] = "Gem Bag", [1024] = "Mining Bag",
}

BP.FAMILY_COLORS = {
    [1]    = { 0.72, 0.52, 0.28 },  -- quiver / ammo pouch
    [2]    = { 0.72, 0.52, 0.28 },
    [4]    = { 0.65, 0.35, 0.85 },  -- soul bag
    [8]    = { 0.80, 0.55, 0.30 },  -- leatherworking
    [16]   = { 0.25, 0.75, 0.85 },  -- inscription
    [32]   = { 0.30, 0.85, 0.30 },  -- herbalism
    [64]   = { 0.45, 0.55, 1.00 },  -- enchanting
    [128]  = { 1.00, 0.55, 0.05 },  -- engineering
    [256]  = { 0.90, 0.85, 0.40 },  -- keyring
    [512]  = { 0.95, 0.25, 0.45 },  -- gems
    [1024] = { 0.65, 0.65, 0.60 },  -- mining
}

function BP.FamilyColor(fam)
    if not fam or fam == 0 then return nil end
    for bit_, c in pairs(BP.FAMILY_COLORS) do
        if bit.band(fam, bit_) ~= 0 then return c end
    end
end

function BP.FamilyName(fam)
    if not fam or fam == 0 then return nil end
    for bit_, name in pairs(BP.FAMILY) do
        if bit.band(fam, bit_) ~= 0 then return name end
    end
    return "Special Bag"
end

function D.Key(name, realm) return name .. "-" .. realm end

function D.Init()
    BagsPlusChars = BagsPlusChars or {}
    BagsPlusGuilds = BagsPlusGuilds or {}
    local name, realm = UnitName("player"), GetRealmName()
    BP.myKey = D.Key(name, realm)
    local c = BagsPlusChars[BP.myKey]
    if not c then
        c = { bags = {} }
        BagsPlusChars[BP.myKey] = c
    end
    c.bags = c.bags or {}
    c.name, c.realm = name, realm
    D.me = c
end

function D.Login()
    local c = D.me
    c.class = select(2, UnitClass("player"))
    c.faction = UnitFactionGroup("player")
    c.level = UnitLevel("player")
    c.money = GetMoney()
    c.seen = time()
    for _, bag in ipairs({ 0, 1, 2, 3, 4 }) do D.ScanBag(bag) end
    D.ScanBag(BP.KEYRING)
end

local function BagInfo(bag)
    if bag == 0 then
        return nil, "Interface\\Buttons\\Button-Backpack-Up"
    elseif bag >= 1 and bag <= 4 then
        local inv = ContainerIDToInventoryID(bag)
        return GetInventoryItemLink("player", inv), GetInventoryItemTexture("player", inv)
    elseif bag >= 5 and bag <= 11 then
        local inv = BankButtonIDToInvSlotID(bag - 4, 1)
        return GetInventoryItemLink("player", inv), GetInventoryItemTexture("player", inv)
    elseif bag == BP.KEYRING then
        return nil, "Interface\\ContainerFrame\\KeyRing-Bag-Icon"
    end
    return nil, nil
end

-- Reads one bag from the live API into a plain table.
function D.ReadBag(bag)
    local n = GetContainerNumSlots(bag)
    if not n or n <= 0 then return nil end
    local family = 0
    if bag == BP.KEYRING then
        family = 256
    elseif bag >= 0 then
        local _, f = GetContainerNumFreeSlots(bag)
        family = f or 0
    end
    local link, icon = BagInfo(bag)
    local rec = { size = n, family = family, link = link, icon = icon, items = {} }
    for slot = 1, n do
        local tex, count, _, q = GetContainerItemInfo(bag, slot)
        if tex then
            rec.items[slot] = { l = GetContainerItemLink(bag, slot), c = count or 1, t = tex, q = q }
        end
    end
    return rec
end

function D.ScanBag(bag)
    local r = D.ReadBag(bag)
    if r then
        D.me.bags[bag] = r
    elseif bag >= 0 and bag <= 4 or bag == BP.KEYRING then
        D.me.bags[bag] = nil
    end
end

function D.ScanBank()
    for _, bag in ipairs(BP.BANK_BAGS) do
        local r = D.ReadBag(bag)
        D.me.bags[bag] = r
    end
    D.me.bankSeen = time()
end

function D.UpdateMoney()
    if D.me then D.me.money = GetMoney() end
end

function D.Characters()
    local list = {}
    for key, c in pairs(BagsPlusChars) do
        list[#list + 1] = { key = key, c = c }
    end
    local myRealm = GetRealmName()
    table.sort(list, function(a, b)
        if a.key == BP.myKey then return true end
        if b.key == BP.myKey then return false end
        local ar, br = a.c.realm == myRealm, b.c.realm == myRealm
        if ar ~= br then return ar end
        return a.key < b.key
    end)
    return list
end

function D.TotalMoney()
    local sum = 0
    for _, c in pairs(BagsPlusChars) do sum = sum + (c.money or 0) end
    return sum
end

------------------------------------------------------------------------
-- Guild bank cache
------------------------------------------------------------------------
function D.GuildKey()
    local g = GetGuildInfo("player")
    if not g then return nil end
    return g .. "-" .. GetRealmName(), g
end

function D.ScanGuildTab(tab)
    local key, gname = D.GuildKey()
    if not key or not tab then return end
    local g = BagsPlusGuilds[key]
    if not g then
        g = { name = gname, realm = GetRealmName(), tabs = {} }
        BagsPlusGuilds[key] = g
    end
    local name, icon = GetGuildBankTabInfo(tab)
    local t = { name = name, icon = icon, items = {} }
    for slot = 1, 98 do
        local tex, count = GetGuildBankItemInfo(tab, slot)
        if tex then
            t.items[slot] = { l = GetGuildBankItemLink(tab, slot), c = count or 1, t = tex }
        end
    end
    g.tabs[tab] = t
    g.num = GetNumGuildBankTabs()
    g.money = GetGuildBankMoney and GetGuildBankMoney() or g.money
    g.seen = time()
end
