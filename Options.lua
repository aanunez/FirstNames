local ADDON_NAME, addon = ...
local FirstNames = FirstNames or _G.FirstNames

local panel = CreateFrame("Frame", "FirstNamesOptionsPanel", UIParent)
panel.name = "First Names"

-- Store widgets for easy refreshing
local widgets = {}
local isBindingKey = false

local function CreateCheckbox(parent, name, label, tooltip, onClick)
    local cb = CreateFrame("CheckButton", name, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetHitRectInsets(0, -200, 0, 0)
    local text = _G[cb:GetName() .. "Text"]
    if text then
        text:SetText(label)
        text:SetFontObject("GameFontNormal")
    end
    cb.tooltipText = label
    cb.tooltipRequirement = tooltip
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if onClick then onClick(checked) end
    end)
    return cb
end

local function InitOptionsUI()
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("First Names |cff888888v1.0.0|r")

    -- Subtitle / Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", panel, "RIGHT", -16)
    desc:SetJustifyH("LEFT")
    desc:SetText("Hides character last names across WoW Forever (identified by the single space in character names). Use the options below or bind a key to toggle last names back on.")

    -- Horizontal divider line
    local line1 = panel:CreateLine()
    line1:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    line1:SetThickness(1)
    line1:SetStartPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    line1:SetEndPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -55)

    -- Status Text
    local statusText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    widgets.statusText = statusText

    -- Master Checkbox: Enable Hiding
    local cbMaster = CreateCheckbox(panel, "FirstNamesOpt_Master", "Hide Character Last Names (Master Toggle)",
        "When checked, last names are hidden. When unchecked, full names (first and last) are shown everywhere.",
        function(checked)
            FirstNamesDB.hideLastNames = checked
            FirstNames:RefreshAllFrames()
            FirstNames:RefreshOptionsUI()
        end
    )
    cbMaster:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -12)
    widgets.cbMaster = cbMaster

    -- Specific Checkboxes Container
    local subHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    subHeader:SetPoint("TOPLEFT", cbMaster, "BOTTOMLEFT", 0, -16)
    subHeader:SetText("Visibility Locations:")

    -- Chat Window Checkbox
    local cbChat = CreateCheckbox(panel, "FirstNamesOpt_Chat", "Chat Window",
        "Hide last names in chat messages, player links, whispers, channels, emotes, and system messages.",
        function(checked)
            FirstNamesDB.hideInChat = checked
            FirstNames:RefreshOptionsUI()
        end
    )
    cbChat:SetPoint("TOPLEFT", subHeader, "BOTTOMLEFT", 12, -8)
    widgets.cbChat = cbChat

    -- Above Characters (Nameplates) Checkbox
    local cbNameplates = CreateCheckbox(panel, "FirstNamesOpt_Nameplates", "Above Characters (Nameplates)",
        "Hide last names above player characters in the world when nameplates are displayed.",
        function(checked)
            FirstNamesDB.hideAboveCharacters = checked
            FirstNames:RefreshAllFrames()
            FirstNames:RefreshOptionsUI()
        end
    )
    cbNameplates:SetPoint("TOPLEFT", cbChat, "BOTTOMLEFT", 0, -6)
    widgets.cbNameplates = cbNameplates

    -- Friendly Nameplates Auto-Enable Checkbox
    local cbFriendlyPlates = CreateCheckbox(panel, "FirstNamesOpt_FriendlyPlates", "Auto-Enable Friendly Nameplates (Headline Mode)",
        "Activates friendly player nameplates in Name-Only mode (without health bars). This is required so overhead names become modifiable UI frames instead of unalterable 3D engine text.",
        function(checked)
            FirstNamesDB.enableFriendlyNameplates = checked
            if checked then
                FirstNames:EnsureNameplateCVars()
                FirstNames:RefreshAllFrames()
            end
            FirstNames:RefreshOptionsUI()
        end
    )
    cbFriendlyPlates:SetPoint("TOPLEFT", cbNameplates, "BOTTOMLEFT", 16, -4)
    widgets.cbFriendlyPlates = cbFriendlyPlates

    -- Nameplate Height Offset Slider
    local heightSliderText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    heightSliderText:SetPoint("TOPLEFT", cbFriendlyPlates, "BOTTOMLEFT", 4, -8)
    heightSliderText:SetText("Nameplate Height Offset: 0 (Default)")
    widgets.heightSliderText = heightSliderText

    local heightSlider = CreateFrame("Slider", "FirstNamesOpt_HeightSlider", panel, "OptionsSliderTemplate")
    heightSlider:SetSize(180, 16)
    heightSlider:SetPoint("TOPLEFT", heightSliderText, "BOTTOMLEFT", 0, -8)
    heightSlider:SetOrientation("HORIZONTAL")
    heightSlider:SetMinMaxValues(-60, 120)
    heightSlider:SetValueStep(1)
    heightSlider:SetObeyStepOnDrag(true)
    if heightSlider.Low then heightSlider.Low:SetText("-60") end
    if heightSlider.High then heightSlider.High:SetText("+120") end
    widgets.heightSlider = heightSlider

    local heightResetBtn = CreateFrame("Button", "FirstNamesOpt_HeightResetBtn", panel, "UIPanelButtonTemplate")
    heightResetBtn:SetSize(60, 20)
    heightResetBtn:SetPoint("LEFT", heightSlider, "RIGHT", 16, 0)
    heightResetBtn:SetText("Reset")
    heightResetBtn:SetScript("OnClick", function()
        heightSlider:SetValue(0)
    end)
    widgets.heightResetBtn = heightResetBtn

    heightSlider:SetScript("OnValueChanged", function(self, value, isUserInput)
        value = math.floor(value + 0.5)
        FirstNamesDB.nameplateHeightOffset = value
        local text = (value > 0 and ("+" .. value)) or tostring(value)
        if value == 0 then text = "0 (Default)" end
        if widgets.heightSliderText then
            widgets.heightSliderText:SetText("Nameplate Height Offset: |cff00ff00" .. text .. "|r")
        end
        FirstNames:RefreshAllNameplateHeights()
    end)

    -- Unit Frames Checkbox
    local cbUnitFrames = CreateCheckbox(panel, "FirstNamesOpt_UnitFrames", "Unit Frames (Target, Focus, Player, Party, Raid)",
        "Hide last names on player frames, target frame, focus frame, and group member frames.",
        function(checked)
            FirstNamesDB.hideOnUnitFrames = checked
            FirstNames:RefreshAllFrames()
            FirstNames:RefreshOptionsUI()
        end
    )
    cbUnitFrames:SetPoint("TOPLEFT", heightSlider, "BOTTOMLEFT", -20, -14)
    widgets.cbUnitFrames = cbUnitFrames

    -- Horizontal divider line 2
    local line2 = panel:CreateLine()
    line2:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    line2:SetThickness(1)
    line2:SetStartPoint("TOPLEFT", cbUnitFrames, "BOTTOMLEFT", -12, -14)
    line2:SetEndPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -260)

    -- Keybinding Section Header
    local kbHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    kbHeader:SetPoint("TOPLEFT", cbUnitFrames, "BOTTOMLEFT", -12, -24)
    kbHeader:SetText("Toggle Key Binding")

    local kbDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    kbDesc:SetPoint("TOPLEFT", kbHeader, "BOTTOMLEFT", 0, -6)
    kbDesc:SetPoint("RIGHT", panel, "RIGHT", -16)
    kbDesc:SetJustifyH("LEFT")
    kbDesc:SetText("Click the button below to bind a key to toggle last names on and off. You can also configure this under Game Menu -> Key Bindings -> AddOns -> First Names.")

    -- Keybind Button
    local kbButton = CreateFrame("Button", "FirstNamesOpt_KeybindBtn", panel, "UIPanelButtonTemplate")
    kbButton:SetSize(220, 26)
    kbButton:SetPoint("TOPLEFT", kbDesc, "BOTTOMLEFT", 0, -12)
    widgets.kbButton = kbButton

    -- Unbind Button
    local unbindBtn = CreateFrame("Button", "FirstNamesOpt_UnbindBtn", panel, "UIPanelButtonTemplate")
    unbindBtn:SetSize(90, 26)
    unbindBtn:SetPoint("LEFT", kbButton, "RIGHT", 10, 0)
    unbindBtn:SetText("Clear")
    unbindBtn:SetScript("OnClick", function()
        FirstNames:SetKeybind(nil)
    end)
    widgets.unbindBtn = unbindBtn

    -- Quick Toggle Button
    local toggleNowBtn = CreateFrame("Button", "FirstNamesOpt_ToggleBtn", panel, "UIPanelButtonTemplate")
    toggleNowBtn:SetSize(160, 26)
    toggleNowBtn:SetPoint("TOPLEFT", kbButton, "BOTTOMLEFT", 0, -12)
    toggleNowBtn:SetText("Toggle Last Names Now")
    toggleNowBtn:SetScript("OnClick", function()
        FirstNames:ToggleLastNames()
    end)

    -- Keybinding Capture Logic
    local function StopKeyCapture(btn)
        isBindingKey = false
        btn:EnableKeyboard(false)
        btn:EnableMouseWheel(false)
        btn:UnlockHighlight()
        btn:SetScript("OnKeyDown", nil)
        btn:SetScript("OnMouseWheel", nil)
        FirstNames:RefreshKeybindButton()
    end

    local function StartKeyCapture(btn)
        if InCombatLockdown() then
            FirstNames:Print("Cannot bind keys while in combat.")
            return
        end
        isBindingKey = true
        btn:LockHighlight()
        btn:EnableKeyboard(true)
        btn:EnableMouseWheel(true)
        btn:SetText("|cffffff00Press a key...|r (ESC: cancel)")

        btn:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                StopKeyCapture(self)
                return
            end
            if key == "BACKSPACE" or key == "DELETE" then
                FirstNames:SetKeybind(nil)
                StopKeyCapture(self)
                return
            end

            -- Ignore standalone modifiers
            if key:find("SHIFT") or key:find("CTRL") or key:find("ALT") or key == "UNKNOWN" then
                return
            end

            local combo = key
            if IsShiftKeyDown() then combo = "SHIFT-" .. combo end
            if IsControlKeyDown() then combo = "CTRL-" .. combo end
            if IsAltKeyDown() then combo = "ALT-" .. combo end

            FirstNames:SetKeybind(combo)
            StopKeyCapture(self)
        end)

        btn:SetScript("OnMouseWheel", function(self, delta)
            local key = delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
            local combo = key
            if IsShiftKeyDown() then combo = "SHIFT-" .. combo end
            if IsControlKeyDown() then combo = "CTRL-" .. combo end
            if IsAltKeyDown() then combo = "ALT-" .. combo end

            FirstNames:SetKeybind(combo)
            StopKeyCapture(self)
        end)
    end

    kbButton:SetScript("OnClick", function(self)
        if isBindingKey then
            StopKeyCapture(self)
        else
            StartKeyCapture(self)
        end
    end)

    kbButton:SetScript("OnHide", function(self)
        if isBindingKey then
            StopKeyCapture(self)
        end
    end)

    panel:SetScript("OnShow", function()
        FirstNames:RefreshOptionsUI()
    end)
end

function FirstNames:RefreshKeybindButton()
    if not widgets.kbButton then return end
    local key = self:GetBoundKeyText()
    if isBindingKey then
        widgets.kbButton:SetText("|cffffff00Press a key...|r (ESC: cancel)")
    elseif key and key ~= "" then
        widgets.kbButton:SetText("Key: |cff00ff00" .. key .. "|r")
    else
        widgets.kbButton:SetText("Key: |cff888888Not Bound|r")
    end
end

function FirstNames:RefreshOptionsUI()
    if not FirstNamesDB then return end

    if widgets.statusText then
        local status = self:IsActive() and "|cffff5555[HIDDEN]|r (showing first names only)" or "|cff00ff00[SHOWN]|r (full names visible)"
        widgets.statusText:SetText("Current State: Last names are " .. status)
    end

    if widgets.cbMaster then widgets.cbMaster:SetChecked(FirstNamesDB.hideLastNames ~= false) end
    if widgets.cbChat then widgets.cbChat:SetChecked(FirstNamesDB.hideInChat ~= false) end
    if widgets.cbNameplates then widgets.cbNameplates:SetChecked(FirstNamesDB.hideAboveCharacters ~= false) end
    if widgets.cbFriendlyPlates then widgets.cbFriendlyPlates:SetChecked(FirstNamesDB.enableFriendlyNameplates ~= false) end
    if widgets.heightSlider then
        local offset = FirstNamesDB.nameplateHeightOffset or 0
        widgets.heightSlider:SetValue(offset)
        local text = (offset > 0 and ("+" .. offset)) or tostring(offset)
        if offset == 0 then text = "0 (Default)" end
        if widgets.heightSliderText then
            widgets.heightSliderText:SetText("Nameplate Height Offset: |cff00ff00" .. text .. "|r")
        end
    end
    if widgets.cbUnitFrames then widgets.cbUnitFrames:SetChecked(FirstNamesDB.hideOnUnitFrames ~= false) end

    self:RefreshKeybindButton()
end

-- Open options panel
function FirstNames:OpenOptions()
    if Settings and Settings.OpenToCategory and panel.category then
        Settings.OpenToCategory(panel.category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

-- Initialize UI and register category
InitOptionsUI()

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "First Names")
    Settings.RegisterAddOnCategory(category)
    panel.category = category
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end
