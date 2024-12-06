local addonName, LithStable = ...

-- Debug function for favorites
function LithStable:DebugPrintFavorites()
    print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Favorite Mounts Debug List"))
    print("---------------------------------------")

    local availableMounts = {
        ground = {},
        flying = {},
        aquatic = {}
    }
    local unusableFavorites = {}

    -- Use the same mount collection logic as in SummonRandomMount
    for i = 1, C_MountJournal.GetNumMounts() do
        local name, spellID, _, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(C_MountJournal.GetDisplayedMountID(i))
        if mountID then
            local localUsable, reason = C_MountJournal.GetMountUsabilityByID(mountID, false)
            if isCollected and isFavorite and not shouldHideOnChar then
                local mountTypeStr = self:IsFlyingMount(mountID) and "Flying" or (self:IsAquaticMount(mountID) and "Aquatic" or "Ground")
                if isUsable and localUsable then
                    -- Add to available mounts list
                    local statusStr = "Usable"
                    print(string.format("%s (SpellID: %d): %s, %s", name, spellID, mountTypeStr, statusStr))
                    if self:IsFlyingMount(mountID) then
                        table.insert(availableMounts.flying, name)
                    elseif self:IsAquaticMount(mountID) then
                        table.insert(availableMounts.aquatic, name)
                    else
                        table.insert(availableMounts.ground, name)
                    end
                elseif localUsable then
                    -- Add to unusable favorites
                    table.insert(unusableFavorites, {name = name, reason = reason})
                    print(string.format("%s (SpellID: %d): %s, Not Usable", name, spellID, mountTypeStr))
                    print("Reason:", reason)
                end
            end
        end
    end
    print("---------------------------------------")
    
    -- Print summary
    print("Available Flying Mounts:", #availableMounts.flying)
    if #availableMounts.flying > 0 then
        print("  " .. table.concat(availableMounts.flying, ", "))
    end
    
    print("Available Ground Mounts:", #availableMounts.ground)
    if #availableMounts.ground > 0 then
        print("  " .. table.concat(availableMounts.ground, ", "))
    end

    print("Available Aquatic Mounts:", #availableMounts.aquatic)
    if #availableMounts.aquatic > 0 then
        print("  " .. table.concat(availableMounts.aquatic, ", "))
    end
    
    if #unusableFavorites > 0 then
        print("Unusable Favorite Mounts:", #unusableFavorites)
        for _, mount in ipairs(unusableFavorites) do
            print("  " .. mount.name .. " (" .. mount.reason .. ")")
        end
    end
    
    print("---------------------------------------")
    
    -- Add the last used mounts information
    self:DebugPrintLastMounts()
end

-- Debug function for last used mounts
function LithStable:DebugPrintLastMounts()
    print(format('|cFF8000FF%s|r|cffffffff%s|r %s', 'Lith', 'Stable:', "Last Used Mounts:"))
    print("---------------------------------------")
    
    -- Print last flying mount
    if self.lastFlyingMount then
        local name = C_MountJournal.GetMountInfoByID(self.lastFlyingMount)
        if name then
            local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(self.lastFlyingMount)
            print(string.format("Last Flying Mount: %s (ID: %d, Type: %d)", name, self.lastFlyingMount, mountTypeID))
        end
    else
        print("Last Flying Mount: None")
    end
    
    -- Print last ground mount
    if self.lastGroundMount then
        local name = C_MountJournal.GetMountInfoByID(self.lastGroundMount)
        if name then
            local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(self.lastGroundMount)
            print(string.format("Last Ground Mount: %s (ID: %d, Type: %d)", name, self.lastGroundMount, mountTypeID))
        end
    else
        print("Last Ground Mount: None")
    end
    
    -- Print last aquatic mount
    if self.lastAquaticMount then
        local name = C_MountJournal.GetMountInfoByID(self.lastAquaticMount)
        if name then
            local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(self.lastAquaticMount)
            print(string.format("Last Aquatic Mount: %s (ID: %d, Type: %d)", name, self.lastAquaticMount, mountTypeID))
        end
    else
        print("Last Aquatic Mount: None")
    end
    
    print("---------------------------------------")
end
function LithStable:DebugPrintAnyMount(spellID)
    local mountID = C_MountJournal.GetMountFromSpell(spellID)
    local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, realMountID = C_MountJournal.GetMountInfoByID(mountID)
    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    local localUsable, reason = C_MountJournal.GetMountUsabilityByID(mountID, false)
    print("---------------------------------------")
    if name then
        print(string.format("Mount Name: %s", name))
        print(string.format("Spell ID: %d", spellID))
        print(string.format("Icon: %s", icon))
        print(string.format("Is Active: %s", tostring(isActive)))
        print(string.format("Is Usable: %s", tostring(isUsable)))
        print(string.format("Is localUsable: %s", tostring(localUsable)))
        if not localUsable then
            print(string.format("Reason: %s", reason))
        end
        print(string.format("Source Type: %s", sourceType))
        print(string.format("Is Favorite: %s", tostring(isFavorite)))
        print(string.format("Is Faction Specific: %s", tostring(isFactionSpecific)))
        print(string.format("Faction: %s", faction or "None"))
        print(string.format("Should Hide on Character: %s", tostring(shouldHideOnChar)))
        print(string.format("Is Collected: %s", tostring(isCollected)))
        print(string.format("Mount ID: %d", realMountID))
        print(string.format("MountType ID: %d", mountTypeID))
    else
        print(string.format("|cFF8000FF%s|r|cffffffff%s|r %s", 'Lith', 'Stable:', "No mount information available for the specified mount ID."))
    end
    print("---------------------------------------")
end