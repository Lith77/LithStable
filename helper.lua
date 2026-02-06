local addonName, LithStable = ...

-- Local state variables
local lastMountAttempt = 0
local MOUNT_COOLDOWN = 0.25
local spellCache = {}
local TRACKED_SPELLS = {
    [33391] = true,   -- Journeyman Riding
    [34090] = true,   -- Expert Riding (flying)
    [90265] = true -- Master Riding (flying)
}

-- Helper function to get mount name
function LithStable:GetMountName(mountID)
    if not mountID then return "None" end
    local name = C_MountJournal.GetMountInfoByID(mountID)
    return name or "Unknown"
end

function LithStable:CategorizeMount(mountID)
    -- Get the mount type ID
    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    
    local categories = {}

    -- Define categories based on MountTypeID
    local flyingTypes = {247, 248, 402, 407, 424, 436}
    local aquaticTypes = {231, 232, 254, 407, 412, 436} -- Includes Wavewhisker (436), Deepstar Polyp (407) and Otterworldly Ottuk Carrier (407) which is both flying and aquatic
    local groundTypes = {229, 230, 241, 269, 284, 398, 408, 412}
    
    -- Check if the mount type is in the flying categories
    local isFlying = false
    for _, typeID in ipairs(flyingTypes) do
        if mountTypeID == typeID then
            isFlying = true
            --print("Mount ID:", mountID, "is FLYING")
            break
        end
    end
    
    -- Check if the mount type is in the aquatic categories
    local isAquatic = false
    for _, typeID in ipairs(aquaticTypes) do
        if mountTypeID == typeID then
            isAquatic = true
            --print("Mount ID:", mountID, "is AQUATIC")
            break
        end
    end
    
    -- Assign categories based on findings
    if isFlying then 
        categories.flying = true 
    end
    
    if isAquatic then 
        categories.aquatic = true 
    end
    
    -- If not flying or aquatic, it's a ground mount
    if not isFlying and not isAquatic then
        categories.ground = true
        --print("Mount ID:", mountID, "is GROUND")
    end
    
    return categories
end

function LithStable:IsFlyingMount(mountID)
    local categories = self:CategorizeMount(mountID)
    return categories.flying == true
end

function LithStable:IsAquaticMount(mountID)
    local categories = self:CategorizeMount(mountID)
    return categories.aquatic == true
end

--[[
-- Helper function to determine if a mount is a flying mount
function LithStable:IsFlyingMount(mountID)
    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    -- 248 = Pure Flying, 247 = Flying/Ground, 402 = Dragonriding, 424 = Dragonriding mounts, including mounts that have dragonriding animations but are not yet enabled for dragonriding
    return mountTypeID == 229 or mountTypeID == 238 or mountTypeID == 248 or mountTypeID == 247 or mountTypeID == 402 or mountTypeID == 436 or mountTypeID == 424
end

-- Helper function to determine if a mount is a water mount
function LithStable:IsAquaticMount(mountID)
    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    -- 231 = Ground and increased swim speed, 232 = Aquatic, can only be used in Vashj'ir, 254 = Aquatic only
   return mountTypeID == 231 or mountTypeID == 232 or mountTypeID == 254 or mountTypeID == 436
end
]]--

function LithStable:NotifySpellStateChanged()
    for spellID in pairs(TRACKED_SPELLS) do
        if IsSpellKnown(spellID) and not spellCache[spellID] then
            spellCache[spellID] = true
            self:UpdateSpellCache(spellID)
        end
    end
    MountJournal.SummonRandomFavoriteSpellFrame:Hide();
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
function LithStable:GetRandomMountExcludingLast(mountList, lastMount, isFlying, isAquatic)
    
    -- Add debug prints to understand our lists
    --print("Mount list size:", #mountList)
    --print("Is Flying list:", isFlying)
    --print("Last mount:", lastMount)

    local availableFlying = 0
    local availableGround = 0
    local availableAquatic = 0

    -- Count mounts by type
    for _, mountID in ipairs(mountList) do
        if self:IsFlyingMount(mountID) then
            availableFlying = availableFlying + 1
        elseif self:IsAquaticMount(mountID) then
            availableAquatic = availableAquatic + 1
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

    -- If we're looking for an aquatic mount and only have one
    if isAquatic and availableAquatic <= 1 then
        for _, mountID in ipairs(mountList) do
            if self:IsAquaticMount(mountID) then
               return mountID, 1
            end
        end
    end
    
    -- If we're looking for a ground mount and only have one
    if not isFlying and availableGround <= 1 then
        -- Find and return the single ground mount
        for _, mountID in ipairs(mountList) do
            if not self:IsFlyingMount(mountID) and not self:IsAquaticMount(mountID) then
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
    elseif mountType == "aquatic" then
        self.lastAquaticMount = mountID
        -- Always save to character state
        self.db.char.state.lastAquaticMount = mountID
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
