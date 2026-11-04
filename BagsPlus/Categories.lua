local ADDON, BP = ...

------------------------------------------------------------------------
-- Item class mapping: localized -> English, through the auction house class list
------------------------------------------------------------------------
local ENG = { "Weapon", "Armor", "Container", "Consumable", "Glyph", "Trade Goods",
              "Projectile", "Quiver", "Recipe", "Gem", "Miscellaneous", "Quest" }
local locMap

local function BuildMap()
    locMap = {}
    for _, e in ipairs(ENG) do locMap[e] = e end
    locMap["Key"] = "Key"
    local list = { GetAuctionItemClasses() }
    if #list == #ENG then
        for i, name in ipairs(list) do locMap[name] = ENG[i] end
    end
end

function BP.TypeKey(rec)
    if not rec.type then return nil end
    if not locMap then BuildMap() end
    return locMap[rec.type]
end

local CLASS_ORDER = {
    Weapon = 1, Armor = 2, Container = 3, Consumable = 4, Glyph = 5, ["Trade Goods"] = 6,
    Projectile = 7, Quiver = 8, Recipe = 9, Gem = 10, Miscellaneous = 11, Quest = 12, Key = 13,
}

------------------------------------------------------------------------
-- Built-in category tests
------------------------------------------------------------------------
local function Equippable(r)
    return r.equip ~= nil and r.equip ~= ""
end

local tests = {
    new = function(r) return r.isNew and not BP.db.manualSort end,
    set = function(r) return BP.db.markSets and r.set end,
    quest = function(r) return r.quest or BP.TypeKey(r) == "Quest" end,
    food = function(r) return BP.TypeKey(r) == "Consumable" and r.sub == "Food & Drink" end,
    potion = function(r)
        return BP.TypeKey(r) == "Consumable" and (r.sub == "Potion" or r.sub == "Elixir" or r.sub == "Flask")
    end,
    consumable = function(r) return BP.TypeKey(r) == "Consumable" end,
    weapon = function(r) return BP.TypeKey(r) == "Weapon" and Equippable(r) end,
    armor = function(r) return BP.TypeKey(r) == "Armor" and Equippable(r) end,
    trade = function(r) return BP.TypeKey(r) == "Trade Goods" end,
    reagent = function(r) return r.type == "Reagent" or r.sub == "Reagent" end,
    gem = function(r) return BP.TypeKey(r) == "Gem" end,
    glyph = function(r) return BP.TypeKey(r) == "Glyph" end,
    recipe = function(r) return BP.TypeKey(r) == "Recipe" end,
    container = function(r) return BP.TypeKey(r) == "Container" end,
    ammo = function(r)
        local t = BP.TypeKey(r)
        return t == "Projectile" or t == "Quiver"
    end,
    key = function(r) return r.type == "Key" end,
    junk = function(r) return r.quality == 0 end,
    misc = function(r)
        local t = BP.TypeKey(r)
        if t == "Miscellaneous" then return true end
        -- gear-class items with no equip slot (gadgets, toys) are not gear
        return (t == "Armor" or t == "Weapon") and not Equippable(r)
    end,
}

local queryCache = {}

local function CustomMatch(c, rec)
    if rec.id and c.items and c.items[rec.id] then return true end
    if c.query and c.query ~= "" then
        local q = queryCache[c.query]
        if q == nil then
            q = BP.Search.Parse(c.query) or false
            queryCache[c.query] = q
        end
        if q and BP.Search.Match(q, rec) then return true end
    end
    return false
end

function BP.ClearQueryCache() wipe(queryCache) end

function BP.FindCustom(key)
    for _, c in ipairs(BP.db.custom) do
        if "c" .. c.id == key then return c end
    end
end

function BP.Classify(rec, order)
    local db = BP.db
    order = order or BP.CategoryOrder()
    BP.Fill(rec)
    -- 1. items listed by ID in any category always go there
    if rec.id then
        for _, key in ipairs(order) do
            if not db.disabled[key] then
                local c = (key:sub(1, 1) == "c" and tonumber(key:sub(2))) and BP.FindCustom(key) or db.overrides[key]
                if c and c.items and c.items[rec.id] then return key end
            end
        end
    end
    -- 2. rules, then the built-in tests, in category order
    for _, key in ipairs(order) do
        if not db.disabled[key] then
            if key:sub(1, 1) == "c" and tonumber(key:sub(2)) then
                local c = BP.FindCustom(key)
                if c and CustomMatch(c, rec) then return key end
            else
                local o = db.overrides[key]
                if o and o.query and o.query ~= "" and CustomMatch({ query = o.query }, rec) then return key end
                if tests[key] and tests[key](rec) then return key end
            end
        end
    end
    return "other"
end

------------------------------------------------------------------------
-- Comparators (used by the category view and the bag sorter)
------------------------------------------------------------------------
local EQUIP_ORDER = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CLOAK = 4,
    INVTYPE_CHEST = 5, INVTYPE_ROBE = 5, INVTYPE_BODY = 6, INVTYPE_TABARD = 7,
    INVTYPE_WRIST = 8, INVTYPE_HAND = 9, INVTYPE_WAIST = 10, INVTYPE_LEGS = 11,
    INVTYPE_FEET = 12, INVTYPE_FINGER = 13, INVTYPE_TRINKET = 14,
    INVTYPE_WEAPON = 15, INVTYPE_2HWEAPON = 16, INVTYPE_WEAPONMAINHAND = 17,
    INVTYPE_WEAPONOFFHAND = 18, INVTYPE_HOLDABLE = 19, INVTYPE_SHIELD = 20,
    INVTYPE_RANGED = 21, INVTYPE_RANGEDRIGHT = 21, INVTYPE_THROWN = 22, INVTYPE_RELIC = 23,
    INVTYPE_BAG = 24, INVTYPE_QUIVER = 25, INVTYPE_AMMO = 26,
}

local function NameOf(r) return (r.name or ""):lower() end

local function ByQuality(a, b)
    local qa, qb = a.quality or 0, b.quality or 0
    if qa ~= qb then return qa > qb end
    local na, nb = NameOf(a), NameOf(b)
    if na ~= nb then return na < nb end
    return (a.count or 1) > (b.count or 1)
end

local function ByName(a, b)
    local na, nb = NameOf(a), NameOf(b)
    if na ~= nb then return na < nb end
    return (a.count or 1) > (b.count or 1)
end

local function ByIlvl(a, b)
    local ia, ib = a.ilvl or 0, b.ilvl or 0
    if ia ~= ib then return ia > ib end
    return ByQuality(a, b)
end

local function ByType(a, b)
    local ca, cb = CLASS_ORDER[BP.TypeKey(a) or ""] or 99, CLASS_ORDER[BP.TypeKey(b) or ""] or 99
    if ca ~= cb then return ca < cb end
    local sa, sb = a.sub or "", b.sub or ""
    if sa ~= sb then return sa < sb end
    local ea, eb = EQUIP_ORDER[a.equip or ""] or 0, EQUIP_ORDER[b.equip or ""] or 0
    if ea ~= eb then return ea < eb end
    return ByIlvl(a, b)
end

BP.SORT_OPTIONS = {
    { value = "default",       text = "Default (global order)" },
    { value = "type",          text = "Type" },
    { value = "quality",       text = "Quality (best first)" },
    { value = "quality:desc",  text = "Quality (worst first)" },
    { value = "name",          text = "Name (A-Z)" },
    { value = "name:desc",     text = "Name (Z-A)" },
    { value = "ilvl",          text = "Item level (high first)" },
    { value = "ilvl:desc",     text = "Item level (low first)" },
    { value = "bag",           text = "Bag order" },
}

function BP.SortBase(key)
    if key and key:sub(1, 4) == "set:" then return "set" end
    return key
end

-- Sort comparator for one category section (falls back to the global sort order).
function BP.SectionComparator(key)
    local mode = BP.db.catSort[BP.SortBase(key)]
    if not mode or mode == "default" then
        if BP.db.manualSort then return BP.Comparator("bag") end
        return BP.Comparator(BP.db.sort)
    end
    local base, desc = mode:gsub(":desc$", "")
    local cmp = BP.Comparator(base)
    if desc > 0 then return function(a, b) return cmp(b, a) end end
    return cmp
end

function BP.Comparator(mode)
    if mode == "quality" then return ByQuality end
    if mode == "name" then return ByName end
    if mode == "ilvl" then return ByIlvl end
    if mode == "bag" then
        return function(a, b)
            if a.bag ~= b.bag then return a.bag < b.bag end
            return a.slot < b.slot
        end
    end
    return ByType
end
