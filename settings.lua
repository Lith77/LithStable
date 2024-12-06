local addonName, LithStable = ...

-- Default settings
local defaults = {
    profile = {
        settings = {
            dismountOnly = false,
            reoccurring = false,
            aquaticBackup = false
        }
    },
    char = {
        useSharedSettings = true,
        settings = {
            dismountOnly = false,
            reoccurring = false,
            aquaticBackup = false
        },
        state = {
            lastFlyingMount = nil,
            lastGroundMount = nil,
            lastAquaticMount = nil
        },
        favorites = {
            mounts = {}
        }
    }
}

local function CreateSettingsToggles(self, parent, order)
    local settingsGroup = {
        type = "group",
        name = "",
        inline = true,
        order = order,
        args = {
            sharedSettings = {
                type = "toggle",
                name = "Shared settings",
                desc = "Use settings shared between all characters",
                width = "normal",
                order = 1,
                get = function() return self.db.char.useSharedSettings end,
                set = function(_, value)
                    -- If switching to shared settings, copy current shared settings
                    if value then
                        self.db.char.useSharedSettings = true
                        -- Optionally sync with shared settings immediately
                        -- self.db.char.settings = CopyTable(self.db.profile.settings)
                    else
                        self.db.char.useSharedSettings = false
                        -- Optionally initialize character settings with current settings
                        if value == false then
                            self.db.char.settings = CopyTable(self.db.profile.settings)
                        end
                    end
                end,
            },
            characterSettings = {
                type = "toggle",
                name = "Character specific",
                desc = "Use settings specific to this character",
                width = "normal",
                order = 2,
                get = function() return not self.db.char.useSharedSettings end,
                set = function(_, value)
                    self.db.char.useSharedSettings = not value
                    -- Handle initialization of character settings when switching
                    if value then
                        self.db.char.settings = CopyTable(self.db.profile.settings)
                    end
                end,
            },
        }
    }
    return settingsGroup
end

function LithStable:InitializeSettings()
    -- Create fresh settings if they don't exist
    if not LithStableDB then
        LithStableDB = {
            ["profileKeys"] = {},
            ["profiles"] = {
                ["Default"] = defaults.profile
            },
            ["char"] = {}
        }
    end

    -- Initialize database with defaults
    self.db = LibStub("AceDB-3.0"):New("LithStableDB", defaults, true)

    -- Make sure char data exists
    local charKey = UnitName("player") .. " - " .. GetRealmName()
    LithStableDB.profileKeys[charKey] = "Default"
    
    if not LithStableDB.char[charKey] then
        LithStableDB.char[charKey] = CopyTable(defaults.char)
    end

    -- Register options table
    local options = {
        name = function()
            return "|cFF8000FFLith|r|cffffffffStable|r"
        end,
        handler = LithStable,
        type = "group",
        args = {
            title = {
                order = 0,
                type = "description",
                name = function()
                    -- Add padding to center text vertically with logo
                    return "|TInterface\\AddOns\\LithStable\\images\\lith-logo:50:50:0:0|t"
                end,
                fontSize = "large",
                width = "full",
            },
            generalHeader = {
                type = "header",
                name = "General Settings",
                order = 1,
            },
            generalDescription = {
                type = "description",
                name = "Configure how |cFF8000FFLith|rStable behaves when summoning mounts.",
                order = 2,
                fontSize = "medium",
            },
            settingsType = CreateSettingsToggles(self, options, 3), -- (self, parent, order)
            spacer = {
                type = "description",
                name = " ",  -- Empty spacer for layout alignment
                width = "half",
                order = 3.5,
            },
            mountingHeader = {
                type = "header",
                name = "Mounting Options",
                order = 5,
            },
            dismountDescription = {
                type = "description",
                name = "If checked, using the mount command while mounted will only dismount without summoning a new mount.",
                order = 6,
                fontSize = "medium",
            },
            dismountOnly = {
                type = "toggle",
                name = "If mounted just dismount",
                desc = "If checked, using the mount command while mounted will only dismount without summoning a new mount.",
                width = "full",
                order = 6.1,
                get = function() 
                    return self.db.char.useSharedSettings 
                        and self.db.profile.settings.dismountOnly 
                        or self.db.char.settings.dismountOnly 
                end,
                set = function(_, value)
                    if self.db.char.useSharedSettings then
                        self.db.profile.settings.dismountOnly = value
                    else
                        self.db.char.settings.dismountOnly = value
                    end
                end,
            },
            --[[ --Removed because not all flying mounts can be summoned in water
            aquaticDescription = {
                type = "description",
                name = "If checked, using the mount command while in water will fall back to summon a favorite flying or ground mount if no aquatic mount is available.",
                order = 6.2,
                fontSize = "medium",
            },
            aquaticBackup = {
                type = "toggle",
                name = "Aquatic mount fallback",
                desc = "If checked, using the mount command while in water will fall back to summon a favorite flying or ground mount if no aquatic mount is available.",
                width = "full",
                order = 6.3,
                get = function() 
                    return self.db.char.useSharedSettings 
                        and self.db.profile.settings.aquaticBackup 
                        or self.db.char.settings.aquaticBackup 
                end,
                set = function(_, value)
                    if self.db.char.useSharedSettings then
                        self.db.profile.settings.aquaticBackup = value
                    else
                        self.db.char.settings.aquaticBackup = value
                    end
                    self:UpdateAquaticMountBackup()
                end,
            },]]
            spacer1 = {
                type = "description",
                name = " ",  -- Empty spacer for layout alignment
                width = "half",
                order = 7.5,
            },
            reoccurringDescription = {
                type = "description",
                name = "Using the mount command saves the last used mount for both grounded and flying types. If this option is checked, the last summoned mount check is ignored, allowing the same mount to be summoned again at random, even if no other mount has been summoned in between.",
                order = 8,
                fontSize = "medium",
            },
            reoccurringAllowed = {
                type = "toggle",
                name = "Disabled",
                desc = "Ignoring the check for last used mount.",
                width = "full",
                order = 9,
                get = function() 
                    return self.db.char.useSharedSettings 
                        and self.db.profile.settings.reoccurring 
                        or self.db.char.settings.reoccurring 
                end,
                set = function(_, value)
                    if self.db.char.useSharedSettings then
                        self.db.profile.settings.reoccurring = value
                    else
                        self.db.char.settings.reoccurring = value
                    end
                end,
            },
            reoccurringNOTE = {
                type = "description",
                name = "|cFFFFFF00NOTE:|r If the mount type you are trying to summon only have one favorite, last mount used in that type is ignored regardless of whether the above option is checked or not",
                order = 10,
                fontSize = "medium",
            },
            spacer2 = {
                type = "description",
                name = " ",  -- Empty spacer for layout alignment
                width = "half",
                order = 10.5,
            },
            slashCommandsHeader = {
                type = "header",
                name = "Available Slash Commands",
                order = 11,
            },
            command1 = {
                type = "description",
                name = "|cFFFFFF00/ls debug|r - Prints a list of your Favorite mounts, and your last used Flying and Ground mount",
                order = 12,
                fontSize = "medium",
            },
            command2 = {
                type = "description",
                name = "|cFFFFFF00/ls last|r - Prints a list of your last used Flying and Ground mount",
                order = 13,
                fontSize = "medium",
            },
            command3 = {
                type = "description",
                name = "|cFFFFFF00/ls config|r - Opens the settings window",
                order = 14,
                fontSize = "medium",
            },
            command4 = {
                type = "description",
                name = "|cFFFFFF00/ls flying|r - Summons a Flying mount",
                order = 15,
                fontSize = "medium",
            },
            command5 = {
                type = "description",
                name = "|cFFFFFF00/ls ground|r - Summons a Ground mount",
                order = 16,
                fontSize = "medium",
            },
            command6 = {
                type = "description",
                name = "|cFFFFFF00/ls|r - Summons a mount by auto-selecting",
                order = 17,
                fontSize = "medium",
            },
            command7 = {
                type = "description",
                name = "|cFFFFFF00/ls help|r - Prints this list",
                order = 18,
                fontSize = "medium",
            },
        }
    }

    -- Register in the Interface Options
    local AceConfig = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    
    AceConfig:RegisterOptionsTable(addonName, options)
        -- Create the config panel with consistent layout
    local dialogFrame = AceConfigDialog:AddToBlizOptions(addonName, "|cFF8000FFLith|rStable")
    
    -- Store reference to the panel
    self.optionsFrame = dialogFrame
    
    -- Function to open config
    function self:OpenConfig()
        LibStub("AceConfigDialog-3.0"):Open(addonName)
        --[[if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(self.optionsFrame)
        else
            -- Fallback for Classic/Cataclysm
            ShowUIPanel(InterfaceOptionsFrame)
            InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        end]]
    end


    -- Initialize character favorites if needed
    if not self.db.char.favorites.mounts then
        self.db.char.favorites.mounts = {}
        self:CopyCurrentFavoritesToChar()
    end

    print("|cFF8000FFLith|r|cffffffffStable|r: |cFFBCCF02loaded")
end

-- Helper function to copy current favorites to character-specific list
function LithStable:CopyCurrentFavoritesToChar()
    local favorites = {}
    for i = 1, C_MountJournal.GetNumMounts() do
        local _, _, _, _, _, _, isFavorite, _, _, _, _, mountID = C_MountJournal.GetMountInfoByID(i)
        if mountID and isFavorite then
            favorites[mountID] = true
        end
    end
    self.db.char.favorites.mounts = favorites
end

function LithStable:GetCharacterFavorites()
    return self.db.char.favorites.mounts or {}
end

-- Function to check if a mount is a favorite
function LithStable:IsFavorite(mountID)
    if not mountID then return false end
    
    if self:IsCharacterFavoritesEnabled() then
        local favorites = self:GetCharacterFavorites()
        return favorites[mountID]
    else
        local _, _, _, _, _, _, isFavorite = C_MountJournal.GetMountInfoByID(mountID)
        return isFavorite
    end
end

-- Function to set favorite status
function LithStable:SetFavorite(mountID, isFavorite)
    if not mountID then return end
    
    -- Update our character-specific tracking
    if not self.db.char.favorites.mounts then
        self.db.char.favorites.mounts = {}
    end
    self.db.char.favorites.mounts[mountID] = isFavorite or nil

    -- Update the UI system
    local displayIndex
    for i = 1, C_MountJournal.GetNumDisplayedMounts() do
        local displayedMountID = select(12, C_MountJournal.GetDisplayedMountInfo(i))
        if displayedMountID == mountID then
            displayIndex = i
            break
        end
    end
    
    if displayIndex then
        C_MountJournal.SetIsFavorite(displayIndex, isFavorite)
        MountJournal_UpdateMountList()
    end
end

function LithStable:ShouldDismountOnly()
    if not self.db then return false end
    
    return self.db.char.useSharedSettings 
        and self.db.profile.settings.dismountOnly 
        or self.db.char.settings.dismountOnly
end
