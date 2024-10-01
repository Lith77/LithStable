local addonName, LithStable = ...

LithStable.DebugPrintFavorites = function()
    print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Favorite Mounts Debug List"))
    print("---------------------------------------")
    for i = 1, C_MountJournal.GetNumMounts() do
        local name, spellID, _, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(i)
        local _, _, _, _, mountType = C_MountJournal.GetMountInfoExtraByID(i)
        
        if isFavorite then
            local mountTypeStr = (mountType == 248 or mountType == 247) and "Flying" or "Ground"
            local statusStr = isCollected and isUsable and not shouldHideOnChar and "Usable" or "Not Usable"
            print(string.format("%s (SpellID: %d): %s, %s", name, spellID, mountTypeStr, statusStr))
        end
    end
    print("---------------------------------------")
end

-- Helper Functions

-- Improved spell cache
local spellCache = {}
local function IsSpellKnownCached(spellID)
    if spellCache[spellID] == nil then
        spellCache[spellID] = IsSpellKnown(spellID)
    end
    return spellCache[spellID]
end

-- Function to update spell cache
local function UpdateSpellCache(newSpellID)
    spellCache[newSpellID] = true
    -- Also update related flying spells
    local flyingSpells = {34090, 34091, 90265, 90267, 54197}
    for _, spellID in ipairs(flyingSpells) do
        spellCache[spellID] = IsSpellKnown(spellID)
    end
end

-- Event frame for spell learning
local spellLearnFrame = CreateFrame("Frame")
spellLearnFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
spellLearnFrame:SetScript("OnEvent", function(self, event, newSpellID)
    UpdateSpellCache(newSpellID)
end)

local function GetContinentName(mapID)
    local mapInfo = C_Map.GetMapInfo(mapID)
    while mapInfo and mapInfo.mapType > 2 do -- Map types: 0=Cosmic, 1=World, 2=Continent, 3=Zone, etc.
        mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
    end
    return mapInfo and mapInfo.name or "Unknown"
end

local function CanFlyInCurrentZone()
    if not IsFlyableArea() then return false end

    local mapID = C_Map.GetBestMapForUnit("player")
    local continentName = GetContinentName(mapID)
    if not continentName then return false end
    --print("You are on the continent: " .. continentName)

    -- Check for any flying skill
    if not IsSpellKnownCached(34090) and not IsSpellKnownCached(34091) and not IsSpellKnownCached(90265) then
        return false
    end

    -- Check for Flight Master's License (required for Eastern Kingdoms, Kalimdor, and Deepholm)
    local flightMastersLicense = IsSpellKnownCached(90267)

    -- Check for Cold Weather Flying (required for Northrend)
    local coldWeatherFlying = IsSpellKnownCached(54197)

    if continentName == "Northrend" then
        return coldWeatherFlying
    elseif continentName == "Eastern Kingdoms" or continentName == "Kalimdor" or continentName == "Deepholm" then
        --[[
        if not flightMastersLicense then
            print(string.format("You need to learn Flight Master's License to fly in %s. Trying to summon a ground mount.", continentName))
        end
        ]]
        return flightMastersLicense
    else
        -- For other continents, assume flying is allowed if the area is flyable
        return true
    end
end
-- Improved random number generation
local function GetTrueRandomIndex(max)
    -- Get the current time in seconds and microseconds
    local currentTime = GetTime()
    local seconds = math.floor(currentTime)
    local microseconds = math.floor((currentTime - seconds) * 1000000)
    
    -- Use the microseconds as a seed for additional randomness
    for i = 1, microseconds % 10 + 1 do
        random()
    end
    
    -- Generate a random index
    return random(1, max)
end

-- Main Functions
LithStable.SummonRandomMount = function(rMountType, forceType)
    if InCombatLockdown() then
        print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Cannot summon a mount while in combat."))
        return
    end

    local favoriteMounts = {
        ground = {},
        flying = {}
    }
    local canFly = CanFlyInCurrentZone()
    local unusableFavorites = {}

    for i = 1, C_MountJournal.GetNumMounts() do
        local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isForDragonriding = C_MountJournal.GetMountInfoByID(i)
        if mountID then
            local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
            local localUsable, reason = C_MountJournal.GetMountUsabilityByID(mountID, false)
            --print(name, mountID)
            if isCollected and isFavorite and not shouldHideOnChar then
                if isUsable and localUsable then
                    if mountTypeID == 248 or mountTypeID == 247 or isForDragonriding then  -- 248 = Flying, 247 = Flying/Ground
                        table.insert(favoriteMounts.flying, mountID)
                    else
                        table.insert(favoriteMounts.ground, mountID)
                    end
                elseif localUsable then
                    --print(name, "C_MountJournal.GetMountUsabilityByID:",C_MountJournal.GetMountUsabilityByID(mountID, false))
                    table.insert(unusableFavorites, {name = name, reason = reason})
                end
            end
        end
    end

    -- Print warnings for favorite mounts the player can't use
    if #unusableFavorites > 0 then
        print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Warning: Some of your favorite mounts are not usable:"))
        for _, mount in ipairs(unusableFavorites) do
            print(format('|cFF8000FF%s|r|cffffffff%s|r %s (%s)', 'Lith', 'Stable:', mount.name, mount.reason))
        end
    end

    local mountList
    if rMountType == "flying" and (canFly or forceType) then
        if #favoriteMounts.flying > 0 then
            mountList = favoriteMounts.flying
        else
            mountList = favoriteMounts.ground
            print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "No flying mounts available. Summoning a ground mount instead"))
        end
    elseif rMountType == "ground" or (rMountType ~= "flying" and not canFly and not forceType) then
        mountList = favoriteMounts.ground
    else
        mountList = canFly and (#favoriteMounts.flying > 0 and favoriteMounts.flying or favoriteMounts.ground) or favoriteMounts.ground
    end

    if #mountList > 0 then
        --local randomIndex = math.random(#mountList)
        local randomIndex = GetTrueRandomIndex(#mountList)
        C_MountJournal.SummonByID(mountList[randomIndex])
    else
        print("You have no suitable favorite mounts available.")
    end
end


LithStable.ToggleFavorite = function()
    local selectedMountIndex = MountJournal.selectedMountID
    if not selectedMountIndex then
        print("No mount selected")
        return
    end

    local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(selectedMountIndex)
    
    if mountID then
        -- Find the mount's index in the displayed list
        local displayIndex
        for i = 1, C_MountJournal.GetNumDisplayedMounts() do
            local displayedMountID = select(12, C_MountJournal.GetDisplayedMountInfo(i))
            if displayedMountID == mountID then
                displayIndex = i
                break
            end
        end

        if displayIndex then
            local newFavoriteStatus = not isFavorite
            C_MountJournal.SetIsFavorite(displayIndex, newFavoriteStatus)
            
            -- Force the UI to update
            MountJournal_UpdateMountList()
            print(format('|cFF8000FF%s|r|cffffffff%s|r %s is now %s favorite', 'Lith', 'Stable:', creatureName, newFavoriteStatus and "a" or "not a"))
        end
    else
        print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Could not toggle favorite status for this mount."))
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName == addonName then
        -- Register slash commands
        SLASH_LITHSTABLE1 = "/ls"
        SLASH_LITHSTABLE2 = "/lithstable"
        SlashCmdList["LITHSTABLE"] = function(msg)
            if msg == "debug" then
                LithStable.DebugPrintFavorites()
            else
                LithStable.SummonRandomMount()
            end
        end
        
        -- Set up keybindings
        _G.BINDING_HEADER_LITHSTABLE = format('|cFF8000FF%s|r|cffffffff%s|r ', 'Lith', 'Stable: Your random mounts')
        _G["BINDING_NAME_LITHSTABLERANDOMAUTOMOUNT"] = "Summon Random Favorite Mount (Auto)"
        _G["BINDING_NAME_LITHSTABLERANDOMFLYINGMOUNT"] = "Summon Random Favorite Flying Mount"
        _G["BINDING_NAME_LITHSTABLERANDOMGROUNDMOUNT"] = "Summon Random Favorite Ground Mount"
    elseif loadedAddonName == "Blizzard_Collections" then
        -- Random Favorite Mount Button
        local randomButton = CreateFrame("Button", "LithStableRandomMountButton", MountJournal, "UIPanelButtonTemplate")
        randomButton:SetSize(32, 32)
        randomButton:SetPoint("TOPRIGHT", MountJournal, "TOPRIGHT", -7, -25)
        
        -- Set custom texture for the random mount button
        local randomButtonTexture = randomButton:CreateTexture(nil, "ARTWORK")
        randomButtonTexture:SetTexture("Interface\\AddOns\\LithStable\\images\\icon-summon.tga")
        randomButtonTexture:SetAllPoints(randomButton)
        randomButton:SetNormalTexture(randomButtonTexture)
        
        randomButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        randomButton:SetScript("OnClick", LithStable.SummonRandomMount)
        randomButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Send the stable boy to get you one of your favorite mounts.")
            GameTooltip:Show()
        end)
        randomButton:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        -- Toggle Favorite Button
        local favoriteButton = CreateFrame("Button", "LithStableToggleFavoriteButton", MountJournal, "UIPanelButtonTemplate")
        favoriteButton:SetSize(32, 32)
        favoriteButton:SetPoint("TOPRIGHT", randomButton, "TOPLEFT", -4, 0)
        -- Set custom texture for the favorite button
        local favoriteButtonTexture = favoriteButton:CreateTexture(nil, "ARTWORK")
        favoriteButtonTexture:SetTexture("Interface\\AddOns\\LithStable\\images\\icon-fav.tga")
        favoriteButtonTexture:SetAllPoints(favoriteButton)
        favoriteButton:SetNormalTexture(favoriteButtonTexture)
        
        favoriteButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        favoriteButton:SetScript("OnClick", LithStable.ToggleFavorite)
        favoriteButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Toggle selected mount as favorite")
            GameTooltip:Show()
        end)
        favoriteButton:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end
end)

-- Functions for keybindings
local function SummonRandomAutoMount()
    LithStable.SummonRandomMount(nil, false)
end

local function SummonRandomFlyingMount()
    LithStable.SummonRandomMount("flying", true)
end

local function SummonRandomGroundMount()
    LithStable.SummonRandomMount("ground", true)
end

-- Make these functions global for keybindings
_G.LithStable_SummonRandomAutoMount = SummonRandomAutoMount
_G.LithStable_SummonRandomFlyingMount = SummonRandomFlyingMount
_G.LithStable_SummonRandomGroundMount = SummonRandomGroundMount