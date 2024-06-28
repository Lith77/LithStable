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

LithStable.SummonRandomMount = function()
    local favoriteMounts = {
        ground = {},
        flying = {}
    }
    local canFly = IsFlyableArea()

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

    local mountList = canFly and (#favoriteMounts.flying > 0 and favoriteMounts.flying or favoriteMounts.ground) or favoriteMounts.ground

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
        
        -- Set up keybinding
        _G.BINDING_HEADER_LITHSTABLE = format('|cFF8000FF%s|r|cffffffff%s|r ', 'Lith', 'Stable: Your random mounts')
        --_G["BINDING_NAME_LITHSTABLERANDOMMOUNT"] = "Summon Random Favorite Mount"
    elseif loadedAddonName == "Blizzard_Collections" then
        -- Random Favorite Mount Button
        local randomButton = CreateFrame("Button", "LithStableRandomMountButton", MountJournal, "UIPanelButtonTemplate")
        randomButton:SetSize(36, 36)
        randomButton:SetPoint("TOPRIGHT", MountJournal, "TOPRIGHT", -7, -25)
        randomButton:SetNormalTexture(236361)
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
        favoriteButton:SetSize(36, 36)
        favoriteButton:SetPoint("BOTTOMRIGHT", MountJournal, "BOTTOMRIGHT", -7, 7)
        favoriteButton:SetNormalTexture(413588)
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

local function SummonRandomMount()
    if LithStable and LithStable.SummonRandomMount then
        LithStable.SummonRandomMount()
    else
        print("LithStable or LithStable.SummonRandomMount is not available")
    end
end
_G.LithStable_SummonRandomMount = SummonRandomMount