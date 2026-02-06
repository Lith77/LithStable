local addonName, LithStable = ...

-- Function to initialize UI elements
function LithStable:InitializeUI()
    if not MountJournal then print("MountJournal not found") return end
    --print("InitializeUI LithStable")

    -- Random Favorite Mount Button
    local randomButton = CreateFrame("Button", "LithStableRandomMountButton", MountJournal, "UIPanelButtonTemplate")
    randomButton:SetSize(32, 32)
    randomButton:SetPoint("TOPRIGHT", MountJournal, "TOPRIGHT", -8, -25)
    
    local randomButtonTexture = randomButton:CreateTexture(nil, "ARTWORK")
    randomButtonTexture:SetTexture("Interface\\AddOns\\LithStable\\images\\icon-summon.tga")
    randomButtonTexture:SetAllPoints(randomButton)
    randomButton:SetNormalTexture(randomButtonTexture)
    
    randomButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    randomButton:SetScript("OnClick", function() LithStable:SummonRandomMount(nil, false) end)
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
    
    local favoriteButtonTexture = favoriteButton:CreateTexture(nil, "ARTWORK")
    favoriteButtonTexture:SetTexture("Interface\\AddOns\\LithStable\\images\\icon-fav.tga")
    favoriteButtonTexture:SetAllPoints(favoriteButton)
    favoriteButton:SetNormalTexture(favoriteButtonTexture)
    
    favoriteButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    favoriteButton:SetScript("OnClick", function() LithStable:ToggleFavorite() end)
    favoriteButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Toggle selected mount as favorite")
        GameTooltip:Show()
    end)
    favoriteButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

-- Hook the UI initialization
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if MountJournal then
        print("|cFF8000FFLith|r|cffffffffStable|r: |cFFBCCF02loaded")
        LithStable:InitializeUI()
        self:UnregisterAllEvents()
    end
end)
