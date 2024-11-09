local addonName, LithStable = ...

-- Local state variables
local lastMountAttempt = 0
local MOUNT_COOLDOWN = 0.25
local spellCache = {}

-- Helper function to get mount name
function LithStable:GetMountName(mountID)
    if not mountID then return "None" end
    local name = C_MountJournal.GetMountInfoByID(mountID)
    return name or "Unknown"
end

-- Helper function to determine if a mount is a flying mount
function LithStable:IsFlyingMount(mountID)
    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    -- 248 = Pure Flying, 247 = Flying/Ground, 407 = Dragonriding
    return mountTypeID == 248 or mountTypeID == 247 or mountTypeID == 407
end

-- Function to update spell cache
function LithStable:UpdateSpellCache(newSpellID)
    spellCache[newSpellID] = true
    -- Also update related flying spells
    local flyingSpells = {34090, 34091, 90265, 90267, 54197}
    for _, spellID in ipairs(flyingSpells) do
        spellCache[spellID] = IsSpellKnown(spellID)
    end
end

-- Helper function for spell cache
function LithStable:IsSpellKnownCached(spellID)
    if spellCache[spellID] == nil then
        spellCache[spellID] = IsSpellKnown(spellID)
    end
    return spellCache[spellID]
end

-- Helper function for continent detection
function LithStable:GetContinentName(mapID)
    local mapInfo = C_Map.GetMapInfo(mapID)
    while mapInfo and mapInfo.mapType > 2 do
        mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
    end
    return mapInfo and mapInfo.name or "Unknown"
end

-- Flying check function
function LithStable:CanFlyInCurrentZone()
    if not IsFlyableArea() then return false end

    local mapID = C_Map.GetBestMapForUnit("player")
    local continentName = self:GetContinentName(mapID)
    if not continentName then return false end

    if not self:IsSpellKnownCached(34090) and not self:IsSpellKnownCached(34091) and not self:IsSpellKnownCached(90265) then
        return false
    end

    local flightMastersLicense = self:IsSpellKnownCached(90267)
    local coldWeatherFlying = self:IsSpellKnownCached(54197)

    if continentName == "Northrend" then
        return coldWeatherFlying
    elseif continentName == "Eastern Kingdoms" or continentName == "Kalimdor" or continentName == "Deepholm" then
        return flightMastersLicense
    else
        return true
    end
end

-- Improved random number generation
function LithStable:GetTrueRandomIndex(max)
    local currentTime = GetTime()
    local seconds = math.floor(currentTime)
    local microseconds = math.floor((currentTime - seconds) * 1000000)
    
    for i = 1, microseconds % 10 + 1 do
        random()
    end
    
    return random(1, max)
end

-- Random mount selection function
function LithStable:GetRandomMountExcludingLast(mountList, lastMount, isFlying)
    
    -- Add debug prints to understand our lists
    --print("Mount list size:", #mountList)
    --print("Is Flying list:", isFlying)
    --print("Last mount:", lastMount)

    local availableFlying = 0
    local availableGround = 0

    -- Count mounts by type
    for _, mountID in ipairs(mountList) do
        if self:IsFlyingMount(mountID) then
            availableFlying = availableFlying + 1
        else
            availableGround = availableGround + 1
        end
    end
    
    -- If we're looking for a flying mount and only have one
    if isFlying and availableFlying <= 1 then
        -- Find and return the single flying mount
        for _, mountID in ipairs(mountList) do
            if self:IsFlyingMount(mountID) then
               return mountID, 1
            end
        end
    end
    
    -- If we're looking for a ground mount and only have one
    if not isFlying and availableGround <= 1 then
        -- Find and return the single ground mount
        for _, mountID in ipairs(mountList) do
            if not self:IsFlyingMount(mountID) then
                return mountID, 1
            end
        end
    end

    -- Check reoccurring setting
    if self.db.char.useSharedSettings then
        if self.db.profile.settings.reoccurring then
            local randomIndex = self:GetTrueRandomIndex(#mountList)
            return mountList[randomIndex], randomIndex
        end
    else
        if self.db.char.settings.reoccurring then
            local randomIndex = self:GetTrueRandomIndex(#mountList)
            return mountList[randomIndex], randomIndex
        end
    end
    
    -- Create a list of indices excluding the last used mount
    local availableIndices = {}
    for i = 1, #mountList do
        if mountList[i] ~= lastMount then
            table.insert(availableIndices, i)
        end
    end
    
    -- If we filtered out all mounts, use the full list
    if #availableIndices == 0 then
        local randomIndex = self:GetTrueRandomIndex(#mountList)
        return mountList[randomIndex], randomIndex
    end
    
    local randomIndex = self:GetTrueRandomIndex(#availableIndices)
    return mountList[availableIndices[randomIndex]], availableIndices[randomIndex]
end

-- Cooldown check
function LithStable:CheckCooldown()
    local currentTime = GetTime()
    if (currentTime - lastMountAttempt) < MOUNT_COOLDOWN then
        return false
    end
    lastMountAttempt = currentTime
    return true
end

-- Helper function to check if player knows a spell
function LithStable:KnowsSpell(spellID)
    return IsSpellKnown(spellID)
end

-- Add this helper function to check if in water
function LithStable:IsInWater()
    return IsSwimming()
end

-- Helper functions for last mount handling
function LithStable:GetLastMount(mountType)
    return mountType == "flying" and self.lastFlyingMount or self.lastGroundMount
end

function LithStable:SetLastMount(mountType, mountID)
    if mountType == "flying" then
        self.lastFlyingMount = mountID
        -- Always save to character state
        self.db.char.state.lastFlyingMount = mountID
    else
        self.lastGroundMount = mountID
        -- Always save to character state
        self.db.char.state.lastGroundMount = mountID
    end
end

function LithStable:printHelp()
    print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Slash commands"))
    print("---------------------------------------")
    print("|cFFFFFF00/ls debug|r", "Prints a list of your Favorite mounts, and your last used Flying and Ground mount")
    print("|cFFFFFF00/ls last|r", "Prints a list of your last used Flying and Ground mount")
    print("|cFFFFFF00/ls config|r", "Opens the settings window")
    print("|cFFFFFF00/ls flying|r", "Summons a Flying mount")
    print("|cFFFFFF00/ls ground|r", "Summons a Ground mount")
    print("|cFFFFFF00/ls|r", "Summons a mount by auto selectings")
    print("|cFFFFFF00/ls help|r", "Prints this list")
    print("---------------------------------------")
end