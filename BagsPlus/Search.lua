local ADDON, BP = ...
local S = {}
BP.Search = S

local QUALITY_NAMES = {
    poor = 0, junk = 0, gray = 0, grey = 0, common = 1, white = 1, uncommon = 2, green = 2,
    rare = 3, blue = 3, epic = 4, purple = 4, legendary = 5, orange = 5, artifact = 6, heirloom = 7,
}

-- "5g 20s" / "300" (copper) -> copper
local function ParseMoney(s)
    local total, found = 0, false
    for n, u in s:gmatch("(%d+)([gsc]?)") do
        n = tonumber(n)
        if u == "g" then total = total + n * 10000; found = true
        elseif u == "s" then total = total + n * 100; found = true
        else total = total + n; found = true end
    end
    return found and total or nil
end

-- Numeric expressions: ">=200", "<30", "=5", "200-250", "200"
local function NumTest(expr, parseValue)
    parseValue = parseValue or tonumber
    local op, rest = expr:match("^([<>=]=?)(.+)$")
    if op then
        local v = parseValue(rest)
        if not v then return nil end
        if op == ">" then return function(x) return x and x > v end
        elseif op == ">=" then return function(x) return x and x >= v end
        elseif op == "<" then return function(x) return x and x < v end
        elseif op == "<=" then return function(x) return x and x <= v end
        else return function(x) return x and x == v end end
    end
    local a, b = expr:match("^(.-)%-(.+)$")
    if a and parseValue(a) and parseValue(b) then
        a, b = parseValue(a), parseValue(b)
        return function(x) return x and x >= a and x <= b end
    end
    local v = parseValue(expr)
    if v then return function(x) return x and x == v end end
    return nil
end

local function QualityValue(s)
    return QUALITY_NAMES[s] or tonumber(s)
end

local function Has(hay, needle)
    return hay and hay:lower():find(needle, 1, true) ~= nil
end

local function SlotText(rec)
    if rec.equip and rec.equip ~= "" then
        return (_G[rec.equip] or rec.equip):lower()
    end
    return ""
end

local function Scan(rec)
    if rec.live and rec.bound == nil and rec.link then BP.ScanLive(rec) end
end

local keywords = {
    junk = function(r) return r.quality == 0 end,
    new = function(r) return r.isNew end,
    quest = function(r) return r.quest or r.type == "Quest" end,
    unusable = function(r) Scan(r); return r.unusable end,
    usable = function(r) Scan(r); return not r.unusable end,
    equippable = function(r) return r.equip and r.equip ~= "" end,
    equipment = function(r) return r.equip and r.equip ~= "" end,
    soulbound = function(r) Scan(r); return r.bound end,
    bound = function(r) Scan(r); return r.bound end,
    boe = function(r) Scan(r); return r.bind == "BoE" end,
    bop = function(r) Scan(r); return r.bind == "BoP" end,
    bou = function(r) Scan(r); return r.bind == "BoU" end,
    boa = function(r) Scan(r); return r.bind == "BoA" end,
    stackable = function(r) return (r.stack or 1) > 1 end,
}

local function MakeTerm(raw)
    local neg = false
    if raw:sub(1, 1) == "!" or raw:sub(1, 1) == "-" then
        neg = true
        raw = raw:sub(2)
    end
    if raw == "" then return nil end
    local fn
    local key, val = raw:match("^(%a+):(.+)$")
    if key then
        if key == "q" or key == "quality" then
            local t = NumTest(val, QualityValue)
            if t then fn = function(r) return t(r.quality) end end
        elseif key == "ilvl" or key == "il" or key == "level" then
            local t = NumTest(val)
            if t then fn = function(r) return t(r.ilvl) end end
        elseif key == "req" or key == "lvl" then
            local t = NumTest(val)
            if t then fn = function(r) return t(r.reqLevel) end end
        elseif key == "count" or key == "c" then
            local t = NumTest(val)
            if t then fn = function(r) return t(r.count) end end
        elseif key == "price" or key == "sell" then
            local t = NumTest(val, ParseMoney)
            if t then fn = function(r) return t((r.price or 0) * (r.count or 1)) end end
        elseif key == "bag" then
            local t = NumTest(val)
            if t then fn = function(r) return t(r.bag) end end
        elseif key == "type" or key == "t" then
            fn = function(r) return Has(r.type, val) or Has(r.sub, val) end
        elseif key == "sub" then
            fn = function(r) return Has(r.sub, val) end
        elseif key == "slot" then
            fn = function(r) return SlotText(r):find(val, 1, true) ~= nil end
        elseif key == "set" then
            fn = function(r)
                if val == "any" then return r.set ~= nil end
                return r.set and Has(r.set, val)
            end
        elseif key == "bind" then
            local k = keywords[val]
            if k then fn = k end
        elseif key == "tt" or key == "tooltip" then
            fn = function(r) return BP.TooltipText(r):find(val, 1, true) ~= nil end
        elseif key == "name" or key == "n" then
            fn = function(r) return Has(r.name, val) end
        end
    end
    if not fn then
        local k = keywords[raw]
        if k then
            fn = k
        else
            fn = function(r)
                return Has(r.name, raw) or Has(r.type, raw) or Has(r.sub, raw) or SlotText(r):find(raw, 1, true) ~= nil
            end
        end
    end
    if neg then
        local inner = fn
        return function(r) return not inner(r) end
    end
    return fn
end

-- Parse into alternatives (separated by "|" or " or "), each a list of AND terms.
function S.Parse(text)
    text = text and strtrim(text:lower()) or ""
    if text == "" then return nil end
    text = text:gsub("%s+or%s+", "|")
    local alts = {}
    for part in text:gmatch("[^|]+") do
        local terms = {}
        for word in part:gmatch("%S+") do
            local t = MakeTerm(word)
            if t then terms[#terms + 1] = t end
        end
        if #terms > 0 then alts[#alts + 1] = terms end
    end
    if #alts == 0 then return nil end
    return alts
end

function S.Match(query, rec)
    if not query then return true end
    if not rec.link then return false end
    BP.Fill(rec)
    for _, terms in ipairs(query) do
        local ok = true
        for i = 1, #terms do
            if not terms[i](rec) then ok = false; break end
        end
        if ok then return true end
    end
    return false
end

S.help = "Examples: epic ilvl:>=200  |  type:armor slot:head  |  boe !junk  |  set:any  |  price:>5g  |  tt:fire resistance"
