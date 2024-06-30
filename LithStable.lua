local addonName, LithStable = ...

LithStable.DebugPrintFavorites = function()
    print("Lith Stable: Favorite Mounts Debug List")
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
    if not IsSpellKnown(34090) and not IsSpellKnown(34091) and not IsSpellKnown(90265) then
        return false
    end

    -- Check for Flight Master's License (required for Eastern Kingdoms, Kalimdor, and Deepholm)
    local flightMastersLicense = IsSpellKnown(90267)

    -- Check for Cold Weather Flying (required for Northrend)
    local coldWeatherFlying = IsSpellKnown(54197)

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

-- Main Functions
LithStable.SummonRandomMount = function(mountType)
    if InCombatLockdown() then
        print("Cannot summon a mount while in combat.")
        return
    end

    local favoriteMounts = {
        ground = {},
        flying = {}
    }
    local canFly = CanFlyInCurrentZone()

    for i = 1, C_MountJournal.GetNumMounts() do
        local name, spellID, _, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(i)
        local _, _, _, _, mountType = C_MountJournal.GetMountInfoExtraByID(i)
        
        if isCollected and isUsable and isFavorite and not shouldHideOnChar then
            if mountType == 248 or mountType == 247 then  -- 248 = Flying, 247 = Flying/Ground
                table.insert(favoriteMounts.flying, i)
            else
                table.insert(favoriteMounts.ground, i)
            end
        end
    end

    local mountList
    if mountType == "flying" and canFly then
        mountList = favoriteMounts.flying
    elseif mountType == "ground" or (mountType ~= "flying" and not canFly) then
        mountList = favoriteMounts.ground
    else
        mountList = canFly and (#favoriteMounts.flying > 0 and favoriteMounts.flying or favoriteMounts.ground) or favoriteMounts.ground
    end

    if #mountList > 0 then
        local randomIndex = math.random(#mountList)
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
        end
    else
        print("Could not toggle favorite status for this mount.")
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
    LithStable.SummonRandomMount()
end

local function SummonRandomFlyingMount()
    LithStable.SummonRandomMount("flying")
end

local function SummonRandomGroundMount()
    LithStable.SummonRandomMount("ground")
end

-- Make these functions global for keybindings
_G.LithStable_SummonRandomAutoMount = SummonRandomAutoMount
_G.LithStable_SummonRandomFlyingMount = SummonRandomFlyingMount
_G.LithStable_SummonRandomGroundMount = SummonRandomGroundMount