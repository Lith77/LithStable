local addonName, LithStable = ...
LithStable = LibStub("AceAddon-3.0"):NewAddon(LithStable, addonName, "AceConsole-3.0", "AceEvent-3.0")

-- State variables
LithStable.lastFlyingMount = nil
LithStable.lastGroundMount = nil
LithStable.pendingMount = nil
LithStable.pendingMountType = nil

function LithStable:OnInitialize()
    -- Initialize settings
    self:InitializeSettings()

    -- Load last mount states from character saved variables
    self.lastFlyingMount = self.db.char.state.lastFlyingMount
    self.lastGroundMount = self.db.char.state.lastGroundMount

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

function LithStable:HandleSlashCommand(msg)
    local command = string.lower(msg)
    if command == "help" then
        self:printHelp()
    elseif command == "debug" then
        self:DebugPrintFavorites()
    elseif command == "last" then
        self:DebugPrintLastMounts()
    elseif command == "config" or command == "options" then
        self:OpenConfig()
    elseif command == "flying" then
        self:SummonRandomMount("flying", true)
    elseif command == "ground" then
        self:SummonRandomMount("ground", true)
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
        flying = {}
    }
    local canFly = self:CanFlyInCurrentZone()
    local unusableFavorites = {}

    for i = 1, C_MountJournal.GetNumMounts() do
        local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(i)
        if mountID then
            local localUsable, reason = C_MountJournal.GetMountUsabilityByID(mountID, false)
            if isCollected and isFavorite and not shouldHideOnChar then
                if isUsable and localUsable then
                    if self:IsFlyingMount(mountID) then
                        table.insert(favoriteMounts.flying, mountID)
                    else
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

    local mountList
    local isFlying = false
    if rMountType == "flying" and (canFly or forceType) then
        if #favoriteMounts.flying > 0 then
            mountList = favoriteMounts.flying
            isFlying = true
        else
            mountList = favoriteMounts.ground
            print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "No flying mounts available. Summoning a ground mount instead"))
        end
    elseif rMountType == "ground" or (rMountType ~= "flying" and not canFly and not forceType) then
        mountList = favoriteMounts.ground
    else
        if canFly and #favoriteMounts.flying > 0 then
            mountList = favoriteMounts.flying
            isFlying = true
        else
            mountList = favoriteMounts.ground
        end
    end

    if #mountList > 0 then
        local selectedMount, selectedIndex
        if isFlying then
            selectedMount, selectedIndex = self:GetRandomMountExcludingLast(mountList, self:GetLastMount("flying"), true)
        else
            selectedMount, selectedIndex = self:GetRandomMountExcludingLast(mountList, self:GetLastMount("ground"), false)
        end
        
        local actualIsFlying = self:IsFlyingMount(selectedMount)
        
        self.pendingMount = selectedMount
        self.pendingMountType = actualIsFlying and "flying" or "ground"
        if selectedMount == self.lastFlyingMount or self.lastGroundMount then
            C_Timer.After(0.3, function()
                C_MountJournal.SummonByID(selectedMount)
            end)
            return
        end
        C_MountJournal.SummonByID(selectedMount)
    else
        print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "You have no suitable favorite mounts available."))
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
spellLearnFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
spellLearnFrame:SetScript("OnEvent", function(self, event, newSpellID)
    LithStable:UpdateSpellCache(newSpellID)
end)

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
            local _, _, _, _, _, _, isFavorite, _, _, _, _, mountID = C_MountJournal.GetMountInfoByID(i)
            if mountID then
                LithStable.db.char.favorites.mounts[mountID] = isFavorite or nil
            end
        end
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        if IsMounted() and LithStable.pendingMount then
            local activeMount = nil
            for i = 1, C_MountJournal.GetNumMounts() do
                local _, _, _, isActive, _, _, _, _, _, _, _, mountID = C_MountJournal.GetMountInfoByID(i)
                if isActive then
                    activeMount = mountID
                    break
                end
            end
            
            if activeMount == LithStable.pendingMount then
                local isFlying = LithStable:IsFlyingMount(LithStable.pendingMount)
                -- Always save to character specific state
                LithStable:SetLastMount(isFlying and "flying" or "ground", LithStable.pendingMount)
            end
        end
        
        LithStable.pendingMount = nil
        LithStable.pendingMountType = nil
    end
end)
