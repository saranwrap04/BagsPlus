local ADDON, BP = ...
local D = BP.Data

------------------------------------------------------------------------
-- Show / hide
------------------------------------------------------------------------
function BP.ShowBags()
    local w = BP.windows.bags
    w.charKey = w.charKey or BP.myKey
    if not w:IsShown() then w:Show() else w:Refresh() end
end
function BP.HideBags() BP.windows.bags:Hide() end
function BP.ToggleBags()
    local w = BP.windows.bags
    if w:IsShown() then w:Hide() else w.charKey = BP.myKey; w:Show() end
end

function BP.ShowBank()
    local w = BP.windows.bank
    if not w:IsShown() then w:Show() else w:Refresh() end
end
function BP.ToggleBank()
    local w = BP.windows.bank
    if w:IsShown() then w:Hide() else w:Show() end
end

function BP.ToggleGuild()
    local w = BP.windows.guild
    if w:IsShown() then w:Hide(); return end
    if not w.guildKey then
        local key = D.GuildKey()
        if not key or not BagsPlusGuilds[key] then
            for k in pairs(BagsPlusGuilds) do key = k; break end
        end
        w.guildKey = key
    end
    if not w.guildKey then
        BP.Print("No guild bank saved yet. Open your guild bank once.")
        return
    end
    w:Show()
end

------------------------------------------------------------------------
-- Junk
------------------------------------------------------------------------
function BP.SellJunk()
    if not BP.merchantOpen then return end
    local total, n = 0, 0
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, count, _, q = GetContainerItemInfo(bag, slot)
                local price = select(11, GetItemInfo(link))
                if q == 0 and price and price > 0 then
                    total = total + price * (count or 1)
                    n = n + 1
                    UseContainerItem(bag, slot)
                end
            end
        end
    end
    if n > 0 then BP.Print("Sold " .. n .. " junk item(s) for " .. BP.Money(total)) end
end

------------------------------------------------------------------------
-- Guild bank scan
------------------------------------------------------------------------
function BP.ScanAllGuildTabs()
    if not BP.guildOpen then return end
    local num = GetNumGuildBankTabs()
    local current = GetCurrentGuildBankTab()
    local tab = 0
    local function Next()
        tab = tab + 1
        if tab > num or not BP.guildOpen then
            if BP.guildOpen then SetCurrentGuildBankTab(current); QueryGuildBankTab(current) end
            BP.Print("Guild bank saved.")
            return
        end
        local _, _, viewable = GetGuildBankTabInfo(tab)
        if viewable == false then return Next() end
        SetCurrentGuildBankTab(tab)
        QueryGuildBankTab(tab)
        BP.After(1.2, function()
            D.ScanGuildTab(tab)
            Next()
        end)
    end
    Next()
end

------------------------------------------------------------------------
-- Install: windows, replaced bag functions, events
------------------------------------------------------------------------
function BP.Install()
    BP.CreateWindow("bags")
    BP.CreateWindow("bank")
    BP.CreateWindow("guild")
    BP.ApplyEsc()
    BP.UpdateSets()
    BP.TrackNew()

    ToggleBackpack = function() BP.ToggleBags() end
    OpenBackpack = function() BP.ShowBags() end
    CloseBackpack = function() BP.HideBags() end
    ToggleBag = function(id)
        if id and id >= 5 and id <= 11 then BP.ToggleBank() else BP.ToggleBags() end
    end
    OpenBag = function() BP.ShowBags() end
    CloseBag = function() BP.HideBags() end
    ToggleAllBags = function() BP.ToggleBags() end
    OpenAllBags = function(force)
        if force then BP.ShowBags() else BP.ToggleBags() end
    end
    CloseAllBags = function() BP.HideBags() end
    IsBagOpen = function(id)
        if BP.windows.bags:IsShown() then return id end
        return nil
    end
    ToggleKeyRing = function()
        local w = BP.windows.bags
        w.charKey = BP.myKey
        if w:IsShown() and w.onlyBag == BP.KEYRING then
            w.onlyBag = nil
            w:Refresh()
            return
        end
        BP.db.showKeyring = true
        w.onlyBag = BP.KEYRING
        w.stripShown = true
        w.stripBtn:SetSelected(true)
        if w:IsShown() then w:Refresh() else w:Show() end
    end

    if BankFrame then
        BankFrame:UnregisterAllEvents()
        BankFrame:Hide()
    end
end

BP.On("BAG_UPDATE", function(_, bag)
    if not BP.db or not D.me then return end
    if bag and (bag >= 0 and bag <= 4 or bag == BP.KEYRING) then D.ScanBag(bag) end
    if bag and bag >= 5 and BP.bankOpen then D.ScanBank() end
    BP.TrackNew()
    BP.InvalidateScan()
    BP.Dirty()
end)
BP.On("PLAYERBANKSLOTS_CHANGED", function()
    if BP.bankOpen then D.ScanBank() end
    BP.InvalidateScan()
    BP.Dirty()
end)
BP.On("PLAYERBANKBAGSLOTS_CHANGED", function()
    if BP.bankOpen then D.ScanBank() end
    BP.Dirty()
end)
BP.On("ITEM_LOCK_CHANGED", function() BP.Dirty() end)
BP.On("BAG_UPDATE_COOLDOWN", function() BP.Dirty() end)
BP.On("CURRENCY_DISPLAY_UPDATE", function() BP.Dirty() end)
BP.On("UNIT_INVENTORY_CHANGED", function(_, unit)
    if unit == "player" and D.me then
        for bag = 1, 4 do D.ScanBag(bag) end
        BP.Dirty()
    end
end)
BP.On("PLAYER_MONEY", function() D.UpdateMoney(); BP.Dirty() end)
BP.On("EQUIPMENT_SETS_CHANGED", function() BP.UpdateSets(); BP.Dirty() end)
BP.On("PLAYER_LEVEL_UP", function()
    if D.me then D.me.level = UnitLevel("player") end
    BP.InvalidateScan()
end)
BP.On("SKILL_LINES_CHANGED", function() BP.InvalidateScan() end)
BP.On("PLAYER_ENTERING_WORLD", function()
    BP.UpdateSets()
    if not BP.newTimer then
        BP.newTimer = true
        -- bag contents arrive in bursts right after login; only changes after that count as new
        BP.After(8, function()
            BP.TrackNew()
            BP.newReady = true
        end)
    end
end)

BP.On("BANKFRAME_OPENED", function()
    BP.bankOpen = true
    D.ScanBank()
    local w = BP.windows.bank
    w.charKey = BP.myKey
    w:Show()
    w:Refresh()
    BP.ShowBags()
end)
BP.On("BANKFRAME_CLOSED", function()
    BP.bankOpen = false
    local w = BP.windows.bank
    if w then
        if w:IsShown() then w:Hide() end
    end
    BP.Dirty()
end)

BP.On("MERCHANT_SHOW", function()
    BP.merchantOpen = true
    if BP.db.autoSellJunk then BP.After(0.3, BP.SellJunk) end
    BP.Dirty()
end)
BP.On("MERCHANT_CLOSED", function()
    BP.merchantOpen = false
    BP.Dirty()
end)

BP.On("GUILDBANKFRAME_OPENED", function()
    BP.guildOpen = true
    BP.Dirty()
end)
BP.On("GUILDBANKFRAME_CLOSED", function()
    BP.guildOpen = false
    BP.Dirty()
end)
BP.On("GUILDBANKBAGSLOTS_CHANGED", function()
    if BP.guildOpen and not BP.scanningGuild then
        D.ScanGuildTab(GetCurrentGuildBankTab())
        local w = BP.windows.guild
        if w and w:IsShown() then w:Refresh() end
    end
end)
