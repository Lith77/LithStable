local addonName, LithStable = ...
LithStable = LibStub("AceAddon-3.0"):NewAddon(LithStable, addonName, "AceConsole-3.0", "AceEvent-3.0")

-- State variables
LithStable.lastFlyingMount = nil
LithStable.lastGroundMount = nil
LithStable.lastAquaticMount = nil
LithStable.pendingMount = nil
LithStable.pendingMountType = nil
--LithStable.aquaticMountBackup = false

function LithStable:OnInitialize()
    -- Initialize settings
    self:InitializeSettings()

    -- Load last mount states from character saved variables
    self.lastFlyingMount = self.db.char.state.lastFlyingMount
    self.lastGroundMount = self.db.char.state.lastGroundMount
    self.lastAquaticMount = self.db.char.state.lastAquaticMount

    -- Initialize aquaticMountBackup
    --self:UpdateAquaticMountBackup()

    -- Register slash commands
    self:RegisterChatCommand("ls", "HandleSlashCommand")
    self:RegisterChatCommand("lithstable", "HandleSlashCommand")
    
    -- Set up keybinding header
    _G.BINDING_HEADER_LITHSTABLE = format('|cFF8000FF%s|r|cffffffff%s|r ', 'Lith', 'Stable: Your random mounts')
    _G["BINDING_NAME_LITHSTABLERANDOMAUTOMOUNT"] = "Summon Random Favorite Mount (Auto)"
    _G["BINDING_NAME_LITHSTABLERANDOMFLYINGMOUNT"] = "Summon Random Favorite Flying Mount"
    _G["BINDING_NAME_LITHSTABLERANDOMGROUNDMOUNT"] = "Summon Random Favorite Ground Mount"

    -- Set up keybinding functions
    _G["LithStable_SummonRandomAutoMount"] = function()
        self:SummonRandomMount(nil, false)
    end
    
    _G["LithStable_SummonRandomFlyingMount"] = function()
        self:SummonRandomMount("flying", true)
    end
    
    _G["LithStable_SummonRandomGroundMount"] = function()
        self:SummonRandomMount("ground", true)
    end
end

--[[
function LithStable:UpdateAquaticMountBackup()
    if self.db.char.useSharedSettings then
        self.aquaticMountBackup = self.db.profile.settings.aquaticBackup
    else
        self.aquaticMountBackup = self.db.char.settings.aquaticBackup
    end
end]]

function LithStable:HandleSlashCommand(msg)
    --local command = string.lower(msg)
    local args = {strsplit(" ", msg)}
    local command = string.lower(args[1] or "")
    if command == "help" then
        self:printHelp()
    elseif command == "debug" then
        self:DebugPrintFavorites()
    elseif command == "debugtypes" then
        self:DebugMountTypes()
    elseif command == "last" then
        self:DebugPrintLastMounts()
    elseif command == "config" or command == "options" then
        self:OpenConfig()
    elseif command == "flying" then
        self:SummonRandomMount("flying", true)
    elseif command == "ground" then
        self:SummonRandomMount("ground", true)    
    elseif command == "debugam" then
        if args[2] then
            local mountID = tonumber(args[2])
            if mountID then
                self:DebugPrintAnyMount(mountID)
            else
                print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Invalid mount ID. Please provide a valid number."))
            end
        else
            print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Usage: /ls debugam [mount_id]"))
        end
    else
        self:SummonRandomMount(nil, false)
    end
end


-- Main mount summoning function
function LithStable:SummonRandomMount(rMountType, forceType)
    
    if not self:CheckCooldown() then
        return
    end

    if InCombatLockdown() then
        print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Cannot summon a mount while in combat."))
        return
    end

    if IsMounted() then
        Dismount()
        if self:ShouldDismountOnly() then
            --print(format("isMounted %s, Dismount only %s", tostring(true), tostring(true)))
            return
        end
    end

    local favoriteMounts = {
        ground = {},
        flying = {},
        aquatic = {}
    }
    local canFly = self:CanFlyInCurrentZone()
    local isSubmerged = IsSubmerged()
    local isSwimming = IsSwimming()
    local unusableFavorites = {}
    for i = 1, C_MountJournal.GetNumMounts() do
        local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(C_MountJournal.GetDisplayedMountID(i))
        
        if mountID and isCollected and isUsable then
            local localUsable, reason = C_MountJournal.GetMountUsabilityByID(mountID, false)
            if isCollected and isFavorite and not shouldHideOnChar then
                if isUsable and localUsable then
                    -- Get proper mount categorization
                    local categories = self:CategorizeMount(mountID)
                    
                    -- Add to appropriate lists based on categories
                    if categories.flying then
                        table.insert(favoriteMounts.flying, mountID)
                    end
                    
                    if categories.aquatic then
                        table.insert(favoriteMounts.aquatic, mountID)
                    end
                    
                    if categories.ground then
                        table.insert(favoriteMounts.ground, mountID)
                    end
                elseif localUsable then
                    table.insert(unusableFavorites, {name = name, reason = reason})
                end
            end
        end
    end

    if #unusableFavorites > 0 then
        print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Warning: Some of your favorite mounts are not usable:"))
        for _, mount in ipairs(unusableFavorites) do
            print(format('|cFF8000FF%s|r|cffffffff%s|r %s (%s)', 'Lith', 'Stable:', mount.name, mount.reason))
        end
    end

    --print("isSubmerged:", isSubmerged)
    --print("isSwimming:", isSwimming)
    --print("canFly:", canFly)
    --print("favoriteMounts.aquatic:", #favoriteMounts.aquatic)
    --print("favoriteMounts.flying:", #favoriteMounts.flying)
    --print("favoriteMounts.ground:", #favoriteMounts.ground)
    --print("self.aquaticMountBackup:", self.aquaticMountBackup)

    local mountList
    local isFlying = false
    local isAquatic = false

    if (isSubmerged or isSwimming) and not forceType then
        if #favoriteMounts.aquatic > 0 then
            mountList = favoriteMounts.aquatic
            isAquatic = true
        --[[ removed because not all flying mounts can be summoned in water, and no way to know
        elseif self.aquaticMountBackup and canFly and #favoriteMounts.flying > 0 then
            mountList = favoriteMounts.flying
            isFlying = true
            print("flying")
        elseif self.aquaticMountBackup and #favoriteMounts.ground > 0 then
            mountList = favoriteMounts.ground
            print("ground")]]
        else
            print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "No aquatic mounts available."))
            return
        end
        LithStable:SRM(mountList, isFlying, isAquatic);
        return
    elseif rMountType == "flying" and (canFly or forceType) then
        if #favoriteMounts.flying > 0 then
            mountList = favoriteMounts.flying
            isFlying = true
            --print("canFly:", canFly, "forceType:", forceType)
        else
            mountList = favoriteMounts.ground
            print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "No flying mounts available. Summoning a ground mount instead"))
        end
        LithStable:SRM(mountList, isFlying, isAquatic);
        return
    elseif rMountType == "ground" or (rMountType ~= "flying" and not canFly and not forceType) then
        mountList = favoriteMounts.ground
        LithStable:SRM(mountList, isFlying, isAquatic);
        return
    else
        if canFly and #favoriteMounts.flying > 0 then
            mountList = favoriteMounts.flying
            isFlying = true
        else
            mountList = favoriteMounts.ground
        end
        LithStable:SRM(mountList, isFlying, isAquatic);
        return
    end
end

function LithStable:SRM(mountList, isFlying, isAquatic)
    if #mountList > 0 then
        local selectedMount, selectedIndex
        if isFlying then
            selectedMount, selectedIndex = self:GetRandomMountExcludingLast(mountList, self:GetLastMount("flying"), true, false)
        elseif isAquatic then
            selectedMount, selectedIndex = self:GetRandomMountExcludingLast(mountList, self:GetLastMount("aquatic"), false, true)
        else
            selectedMount, selectedIndex = self:GetRandomMountExcludingLast(mountList, self:GetLastMount("ground"), false, false)
        end
        
        local actualIsFlying = self:IsFlyingMount(selectedMount)
        local actualIsAquatic = self:IsAquaticMount(selectedMount)
        
        self.pendingMount = selectedMount
        self.pendingMountType = actualIsFlying and "flying" or (actualIsAquatic and "aquatic" or "ground")
        
        if selectedMount == self.lastFlyingMount or self.lastGroundMount or self.lastAquaticMount then
            C_Timer.After(0.3, function()
                C_MountJournal.SummonByID(selectedMount)
            end)
            return
        end

        C_MountJournal.SummonByID(selectedMount)
    else
        if IsIndoors() then
            print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "You are indoors, no mounts available."))
        else
            print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "You have no suitable favorite mounts available."))
        end
    end
end

-- Toggle favorite function
function LithStable:ToggleFavorite()
    local selectedMountIndex = MountJournal.selectedMountID
    if not selectedMountIndex then
        print("No mount selected")
        return
    end

    local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(selectedMountIndex)
    
    if mountID then
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
            
            MountJournal_UpdateMountList()
            print(format('|cFF8000FF%s|r|cffffffff%s|r %s is now %s favorite', 'Lith', 'Stable:', creatureName, newFavoriteStatus and "a" or "not a"))
        end
    else
        print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Could not toggle favorite status for this mount."))
    end
end

-- Event frame for spell learning

local spellLearnFrame = CreateFrame("Frame")
if WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
    spellLearnFrame:RegisterEvent("LEARNED_SPELL_IN_TAB") 
    spellLearnFrame:SetScript("OnEvent", function(self, event, newSpellID)
    LithStable:UpdateSpellCache(newSpellID)
    end)
end
if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then    
    spellLearnFrame:RegisterEvent("SPELLS_CHANGED")
    spellLearnFrame:SetScript("OnEvent", function()
        LithStable:NotifySpellStateChanged()
    end)
end


local mountEventFrame = CreateFrame("Frame")
mountEventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
mountEventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mountEventFrame:RegisterEvent("COMPANION_UPDATE")

mountEventFrame:SetScript("OnEvent", function(self, event)

     if not LithStable.db or not LithStable.db.char then return end

     if event == "COMPANION_UPDATE" then
         -- Initialize favorites table if it doesn't exist
        if not LithStable.db.char.favorites then
            LithStable.db.char.favorites = {}
        end
        if not LithStable.db.char.favorites.mounts then
            LithStable.db.char.favorites.mounts = {}
        end
        
        for i = 1, C_MountJournal.GetNumMounts() do
            local _, _, _, _, _, _, isFavorite, _, _, _, _, mountID = C_MountJournal.GetMountInfoByID(C_MountJournal.GetDisplayedMountID(i))
            if mountID then
                LithStable.db.char.favorites.mounts[mountID] = isFavorite or nil
            end
        end
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        if IsMounted() and LithStable.pendingMount then
            local activeMount = nil
            for i = 1, C_MountJournal.GetNumMounts() do
                local _, _, _, isActive, _, _, _, _, _, _, _, mountID = C_MountJournal.GetMountInfoByID(C_MountJournal.GetDisplayedMountID(i))
                if isActive then
                    activeMount = mountID
                    break
                end
            end
            
            if activeMount == LithStable.pendingMount then
                local isFlying = LithStable:IsFlyingMount(LithStable.pendingMount)
                local isAquatic = LithStable:IsAquaticMount(LithStable.pendingMount)
                -- Always save to character specific state
                LithStable:SetLastMount(isFlying and "flying" or isAquatic and "aquatic" or "ground", LithStable.pendingMount)
            end
        end
        
        LithStable.pendingMount = nil
        LithStable.pendingMountType = nil
    end
end)
