local ADDON_NAME, addon = ...
local FirstNames = FirstNames or {}
_G.FirstNames = FirstNames

-- Key binding strings for Game Menu -> Key Bindings -> AddOns
_G.BINDING_HEADER_FIRSTNAMES = "First Names"
_G.BINDING_NAME_FIRSTNAMES_TOGGLE = "Toggle Last Names"

-- Default settings
local defaultDB = {
    hideLastNames = true,            -- Master toggle: true = hide last names, false = show last names
    hideInChat = true,               -- Hide last names in chat window
    hideAboveCharacters = true,      -- Hide last names above characters (Nameplates)
    hideOnUnitFrames = true,         -- Hide last names on Target, Focus, Player, Party, Raid frames
    enableFriendlyNameplates = true, -- Enable friendly nameplates in Name-Only mode for overhead names
    nameplateHeightOffset = 0,       -- Vertical height offset for nameplates above characters
}

-- Cache of known player names to assist in stripping from plain-text chat/system messages
FirstNames.knownPlayers = {}

-- Utility: Chat print
function FirstNames:Print(msg)
    local prefix = "|cff00c0ffFirstNames:|r "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(msg))
end

-- Check conditions
function FirstNames:IsActive()
    return FirstNamesDB and FirstNamesDB.hideLastNames
end

function FirstNames:ShouldHideInChat()
    return self:IsActive() and (FirstNamesDB.hideInChat ~= false)
end

function FirstNames:ShouldHideAboveCharacters()
    return self:IsActive() and (FirstNamesDB.hideAboveCharacters ~= false)
end

function FirstNames:ShouldHideOnUnitFrames()
    return self:IsActive() and (FirstNamesDB.hideOnUnitFrames ~= false)
end

FirstNames.knownPlayers = {}
FirstNames.firstToFull = {}

-- Register a player full name in the cache and maintain first-to-full mapping
function FirstNames:RegisterPlayer(fullName)
    if not fullName or type(fullName) ~= "string" or not fullName:find(" ") then
        return
    end
    -- Clean any realm or link info
    local clean = fullName:match("^([^%s]+%s+[^%s%-]+)")
    if clean then
        local first = clean:match("^([^%s]+)")
        if first and first ~= clean then
            self.knownPlayers[clean] = first
            self.firstToFull[first] = clean
            self.firstToFull[first:lower()] = clean
        end
    end
end

-- Resolve a first name (or target/mouseover/focus) to their full name
function FirstNames:GetFullName(name)
    if not name or type(name) ~= "string" then return nil end
    if name:find(" ") then return name end

    -- Check current target
    if UnitExists("target") and IsPlayerUnit("target") then
        local tName = UnitName("target")
        if tName and tName:find(" ") and tName:match("^([^%s]+)") == name then
            self:RegisterPlayer(tName)
            return tName
        end
    end

    -- Check mouseover
    if UnitExists("mouseover") and IsPlayerUnit("mouseover") then
        local mName = UnitName("mouseover")
        if mName and mName:find(" ") and mName:match("^([^%s]+)") == name then
            self:RegisterPlayer(mName)
            return mName
        end
    end

    -- Check focus
    if UnitExists("focus") and IsPlayerUnit("focus") then
        local fName = UnitName("focus")
        if fName and fName:find(" ") and fName:match("^([^%s]+)") == name then
            self:RegisterPlayer(fName)
            return fName
        end
    end

    return self.firstToFull[name] or self.firstToFull[name:lower()]
end

-- Core name stripper:
-- In WoW Forever, character names contain at most 1 space separating first and last name.
-- e.g. "John Doe" -> "John"
--      "John Doe-Realm" -> "John-Realm"
--      "John Doe (*)" -> "John (*)"
--      "John" -> "John"
function FirstNames:StripLastName(name)
    if not name or type(name) ~= "string" or not name:find(" ") then
        return name
    end

    -- Case 1: "FirstName LastName-Realm"
    local first, last, realm = name:match("^([^%s]+)%s+([^%s%-]+)(%-.*)$")
    if first and last and realm then
        return first .. realm
    end

    -- Case 2: "FirstName LastName (*)"
    local first2, last2, rest = name:match("^([^%s]+)%s+([^%s%*]+)(%s*%(%*.*)$")
    if first2 and last2 and rest then
        return first2 .. rest
    end

    -- Case 3: "FirstName LastName"
    local first3, last3 = name:match("^([^%s]+)%s+([^%s]+)$")
    if first3 and last3 then
        return first3
    end

    -- Fallback: take everything up to the first space
    local firstOnly = name:match("^([^%s]+)")
    return firstOnly or name
end

-- Strips last name from formatted display strings (e.g. "[|cff0070ddJohn Doe|r]", "[John Doe-Realm]")
function FirstNames:StripLastNameFromDisplay(text)
    if not text or type(text) ~= "string" or not text:find(" ") then
        return text
    end

    local outerColor = ""
    local outerReset = ""
    local openBracket = ""
    local closeBracket = ""
    local innerColor = ""
    local innerReset = ""
    local body = text

    -- Outer color (|cxxxxxxxx ... |r)
    local c1, r1 = body:match("^(|c%x%x%x%x%x%x%x%x)(.*)$")
    if c1 then
        outerColor = c1
        body = r1
    end
    local b1, cr1 = body:match("^(.*)(|r)$")
    if cr1 then
        body = b1
        outerReset = cr1
    end

    -- Brackets [ ... ]
    local ob, r2 = body:match("^([%[\(])(.*)$")
    if ob then
        openBracket = ob
        body = r2
    end
    local b2, cb = body:match("^(.*)([%]\)])$")
    if cb then
        body = b2
        closeBracket = cb
    end

    -- Inner color (|cxxxxxxxx ... |r)
    local c2, r3 = body:match("^(|c%x%x%x%x%x%x%x%x)(.*)$")
    if c2 then
        innerColor = c2
        body = r3
    end
    local b3, cr2 = body:match("^(.*)(|r)$")
    if cr2 then
        body = b3
        innerReset = cr2
    end

    local stripped = self:StripLastName(body)
    return outerColor .. openBracket .. innerColor .. stripped .. innerReset .. closeBracket .. outerReset
end

-- Helper to check if a unit is a player
local function IsPlayerUnit(unit)
    if not unit then return false end
    if UnitIsPlayer(unit) then return true end
    local guid = UnitGUID(unit)
    return guid and guid:sub(1, 6) == "Player"
end

--------------------------------------------------------------------------------
-- Chat Window Processing
--------------------------------------------------------------------------------

-- Process player links in chat messages:
-- Transforms: |Hplayer:John Doe:12:CHANNEL|h[John Doe]|h
-- Into:       |Hplayer:John Doe:12:CHANNEL|h[John]|h
-- The underlying hyperlink target is untouched so whisper / inspect / menu still works!
function FirstNames:ProcessChatLine(text)
    if not text or type(text) ~= "string" then
        return text
    end

    -- Process player hyperlinks: only change the DISPLAY text between |h...|h
    -- The |Hplayer:TargetName:...|h prefix is left intact so clicking to whisper uses the real name!
    if text:find("|Hplayer:") then
        text = text:gsub("(|Hplayer:([^|:]+)([^|]*)|h)(.-)(|h)", function(header, target, linkData, linkText, close)
            if target and target:find(" ") then
                FirstNames:RegisterPlayer(target)
                local cleanLinkText = FirstNames:StripLastNameFromDisplay(linkText)
                return header .. cleanLinkText .. close
            end
            return header .. linkText .. close
        end)
    end

    -- Protect all hyperlinks (|H...|h...|h) before replacing full names in the rest of the text
    -- This prevents replacing the target inside |Hplayer:FirstName LastName:... with FirstName!
    if text:find("|H") then
        local links = {}
        local count = 0
        text = text:gsub("(|H.-|h.-|h)", function(link)
            count = count + 1
            local token = "\001" .. count .. "\002"
            links[token] = link
            return token
        end)

        for fullName, firstName in pairs(self.knownPlayers) do
            if text:find(fullName, 1, true) then
                text = text:gsub(fullName, firstName)
            end
        end

        for token, link in pairs(links) do
            text = text:gsub(token, link)
        end
    else
        for fullName, firstName in pairs(self.knownPlayers) do
            if text:find(fullName, 1, true) then
                text = text:gsub(fullName, firstName)
            end
        end
    end

    return text
end

-- Ensure whispering always uses the player's full name
if type(_G.ChatFrame_SendTell) == "function" then
    local orig_ChatFrame_SendTell = ChatFrame_SendTell
    ChatFrame_SendTell = function(name, chatFrame)
        if name and type(name) == "string" and not name:find(" ") then
            local full = FirstNames:GetFullName(name)
            if full then
                name = full
            end
        end
        return orig_ChatFrame_SendTell(name, chatFrame)
    end
end

-- Ensure /w or /whisper automatically expands to full name
if type(_G.ChatFrame_OpenChat) == "function" then
    local orig_ChatFrame_OpenChat = ChatFrame_OpenChat
    ChatFrame_OpenChat = function(text, chatFrame)
        if text and type(text) == "string" then
            local prefix, target, rest = text:match("^(/%w+)%s+([^%s]+)%s*(.*)$")
            if prefix and target and not target:find(" ") then
                local pLower = prefix:lower()
                if pLower == "/w" or pLower == "/whisper" or pLower == "/tell" or pLower == "/t" then
                    local full = FirstNames:GetFullName(target)
                    if full then
                        text = prefix .. " " .. full .. " " .. rest
                    end
                end
            end
        end
        return orig_ChatFrame_OpenChat(text, chatFrame)
    end
end

-- ChatFrame AddMessage Hook: Intercepts all chat lines right before display
local function HookChatFrameAddMessage(chatFrame)
    if not chatFrame or chatFrame.fnAddMessageHooked then return end
    chatFrame.fnAddMessageHooked = true

    local origAddMessage = chatFrame.AddMessage
    chatFrame.AddMessage = function(self, text, r, g, b, id, ...)
        if text and FirstNames:ShouldHideInChat() then
            text = FirstNames:ProcessChatLine(text)
        end
        return origAddMessage(self, text, r, g, b, id, ...)
    end
end

-- Hook all existing and future chat frames
local function InitChatHooks()
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local cf = _G["ChatFrame" .. i]
        if cf then HookChatFrameAddMessage(cf) end
    end

    if type(_G.FCF_OpenTemporaryWindow) == "function" then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            for i = 1, NUM_CHAT_WINDOWS or 10 do
                local cf = _G["ChatFrame" .. i]
                if cf then HookChatFrameAddMessage(cf) end
            end
        end)
    end

    -- Event filter for CHAT_MSG_* events to catch author names and system messages
    local function GenericChatFilter(self, event, message, sender, ...)
        if not FirstNames:ShouldHideInChat() then
            return false, message, sender, ...
        end

        if sender and sender:find(" ") then
            FirstNames:RegisterPlayer(sender)
        end

        -- For emote messages where message begins with the sender's full name:
        if (event == "CHAT_MSG_EMOTE" or event == "CHAT_MSG_TEXT_EMOTE") and sender and sender:find(" ") then
            local firstName = FirstNames:StripLastName(sender)
            if message and message:find("^" .. sender) then
                message = message:gsub("^" .. sender, firstName, 1)
            end
        end

        -- Filter known players in system and achievement messages
        if event == "CHAT_MSG_SYSTEM" or event == "CHAT_MSG_ACHIEVEMENT" or event == "CHAT_MSG_GUILD_ACHIEVEMENT" then
            for fullName, firstName in pairs(FirstNames.knownPlayers) do
                if message and message:find(fullName, 1, true) then
                    message = message:gsub(fullName, firstName)
                end
            end
        end

        return false, message, sender, ...
    end

    local chatEvents = {
        "CHAT_MSG_SAY", "CHAT_MSG_YELL",
        "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
        "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
        "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
        "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
        "CHAT_MSG_SYSTEM", "CHAT_MSG_ACHIEVEMENT", "CHAT_MSG_GUILD_ACHIEVEMENT",
        "CHAT_MSG_LOOT",
    }

    for _, event in ipairs(chatEvents) do
        ChatFrame_AddMessageEventFilter(event, GenericChatFilter)
    end
end

--------------------------------------------------------------------------------
-- Nameplates ("Above Characters")
--------------------------------------------------------------------------------

-- Ensure friendly nameplates are active in headline (name-only) mode
-- By default in WoW, friendly player names above heads are 3D engine raster text.
-- Enabling nameplateShowFriends + nameplateShowOnlyNames turns them into clean nameplates
-- (without healthbars) so that addons can modify the text!
function FirstNames:EnsureNameplateCVars()
    if InCombatLockdown() then return end
    if FirstNamesDB and FirstNamesDB.enableFriendlyNameplates ~= false then
        if SetCVar then
            SetCVar("nameplateShowFriends", "1")
            SetCVar("nameplateShowOnlyNames", "1")
        end
    end
end

-- Apply user-configured height offset to a nameplate
function FirstNames:ApplyNameplateHeight(nameplate)
    if not nameplate then return end
    local offset = (FirstNamesDB and FirstNamesDB.nameplateHeightOffset) or 0
    local unitFrame = nameplate.UnitFrame or nameplate
    if not unitFrame then return end

    -- NEVER call :GetPoint() or reposition unitFrame directly (it is a secure/restricted Button in 3D world space).
    -- Instead, adjust the visual FontString(s) representing the player name text.
    local fontStrings = self:GetNameFontStrings(unitFrame)
    for _, fs in ipairs(fontStrings) do
        if offset ~= 0 then
            if not fs.fnOrigPoint then
                local ok, point, relTo, relPoint, x, y = pcall(fs.GetPoint, fs, 1)
                if ok and point then
                    fs.fnOrigPoint = {
                        point = point,
                        relTo = relTo or unitFrame,
                        relPoint = relPoint or point,
                        x = x or 0,
                        y = y or 0,
                    }
                else
                    fs.fnOrigPoint = {
                        point = "BOTTOM",
                        relTo = unitFrame,
                        relPoint = "BOTTOM",
                        x = 0,
                        y = 0,
                    }
                end
            end
            local orig = fs.fnOrigPoint
            pcall(function()
                fs:ClearAllPoints()
                fs:SetPoint(orig.point, orig.relTo, orig.relPoint, orig.x, orig.y + offset)
            end)
            fs.fnOffsetApplied = true
        elseif fs.fnOffsetApplied and fs.fnOrigPoint then
            local orig = fs.fnOrigPoint
            pcall(function()
                fs:ClearAllPoints()
                fs:SetPoint(orig.point, orig.relTo, orig.relPoint, orig.x, orig.y)
            end)
            fs.fnOffsetApplied = nil
        end
    end
end

-- Refresh height offsets on all active nameplates in the world
function FirstNames:RefreshAllNameplateHeights()
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            self:ApplyNameplateHeight(np)
        end
    end
end

-- Recursively finds all name FontStrings on a nameplate or unit frame
function FirstNames:GetNameFontStrings(frame)
    local list = {}
    local seen = {}

    local function addFS(fs)
        if fs and fs.SetText and not seen[fs] then
            seen[fs] = true
            table.insert(list, fs)
        end
    end

    if not frame then return list end

    addFS(frame.name)
    addFS(frame.Name)
    addFS(frame.nameText)
    addFS(frame.unitName)
    addFS(frame.actorName)

    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:IsObjectType("FontString") then
                local objName = region:GetName()
                if objName and (objName:find("Name") or objName:find("name")) then
                    addFS(region)
                end
            end
        end
    end

    if frame.UnitFrame and frame.UnitFrame ~= frame then
        local sub = self:GetNameFontStrings(frame.UnitFrame)
        for _, fs in ipairs(sub) do addFS(fs) end
    end

    return list
end

-- Helper to determine the unit token for a nameplate
local function GetNameplateUnit(nameplate, unitToken)
    if unitToken and UnitExists(unitToken) then return unitToken end
    if not nameplate then return nil end
    local u = nameplate.namePlateUnitToken or (nameplate.UnitFrame and (nameplate.UnitFrame.unit or nameplate.UnitFrame.displayedUnit)) or nameplate.unit or nameplate.displayedUnit
    if u and UnitExists(u) then return u end
    return nil
end

-- Hook SetText on a nameplate FontString so Blizzard or other addons cannot overwrite it
function FirstNames:HookNameplateFontString(fs, nameplate)
    if not fs or fs.fnHooked then return end
    fs.fnHooked = true

    hooksecurefunc(fs, "SetText", function(self, text)
        if self.fnUpdating or not FirstNames:ShouldHideAboveCharacters() then return end
        if text and type(text) == "string" and text:find(" ") then
            local unit = GetNameplateUnit(nameplate)
            -- STRICT: MUST be a verified player character! Never modify NPCs!
            if unit and IsPlayerUnit(unit) then
                local firstName = FirstNames:StripLastName(text)
                if firstName and firstName ~= text then
                    self.fnUpdating = true
                    self:SetText(firstName)
                    self.fnUpdating = nil
                end
            end
        end
    end)
end

-- Process an individual nameplate
function FirstNames:ProcessNameplate(nameplate, unitToken)
    if not nameplate then return end
    local unit = GetNameplateUnit(nameplate, unitToken)
    -- STRICT: If the unit is NOT a verified player character, leave it completely alone!
    if not unit or not IsPlayerUnit(unit) then
        return
    end

    local unitFrame = nameplate.UnitFrame or nameplate
    local fontStrings = self:GetNameFontStrings(unitFrame)
    for _, fs in ipairs(fontStrings) do
        self:HookNameplateFontString(fs, nameplate)
        if self:ShouldHideAboveCharacters() then
            local text = fs:GetText()
            if text and type(text) == "string" and text:find(" ") then
                self:RegisterPlayer(text)
                local firstName = self:StripLastName(text)
                if firstName and firstName ~= text then
                    fs.fnUpdating = true
                    fs:SetText(firstName)
                    fs.fnUpdating = nil
                end
            end
        elseif text and FirstNamesDB and not FirstNamesDB.hideLastNames then
            -- Toggled on: restore full name if known
            local full = GetUnitName(unit, true) or UnitName(unit)
            if full and fs:GetText() ~= full then
                fs.fnUpdating = true
                fs:SetText(full)
                fs.fnUpdating = nil
            end
        end
    end

    self:ApplyNameplateHeight(nameplate)
end

-- Hook CompactUnitFrame_UpdateName (handles Blizzard default nameplates and raid frames)
if type(_G.CompactUnitFrame_UpdateName) == "function" then
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        if not frame then return end
        if frame.unit and frame.unit:find("nameplate") then
            FirstNames:ProcessNameplate(frame, frame.unit)
        elseif FirstNames:ShouldHideOnUnitFrames() and frame.unit and IsPlayerUnit(frame.unit) then
            local rawName = GetUnitName(frame.unit, true) or UnitName(frame.unit)
            local fs = frame.name or frame.Name
            if rawName and rawName:find(" ") and fs then
                FirstNames:RegisterPlayer(rawName)
                local firstName = FirstNames:StripLastName(rawName)
                if firstName and fs:GetText() ~= firstName then
                    fs.fnUpdating = true
                    fs:SetText(firstName)
                    fs.fnUpdating = nil
                end
            end
        end
    end)
end

-- Hook nameplate events
local nameplateWatcher = CreateFrame("Frame")
nameplateWatcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
nameplateWatcher:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
nameplateWatcher:RegisterEvent("UNIT_NAME_UPDATE")
nameplateWatcher:SetScript("OnEvent", function(self, event, unit)
    if (event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_NAME_UPDATE") and unit then
        local nameplate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate then
            FirstNames:ProcessNameplate(nameplate, unit)
        end
    end
end)

-- Periodic scanner (every 0.5s) to guarantee visible nameplates never miss an update
C_Timer.NewTicker(0.5, function()
    if not FirstNames:ShouldHideAboveCharacters() then return end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            FirstNames:ProcessNameplate(np)
        end
    end
end)

--------------------------------------------------------------------------------
-- Unit Frames (Target, Focus, Player, TargetOfTarget, Party)
--------------------------------------------------------------------------------

local function HookUnitFrameName(fontString, unitToken)
    if not fontString or fontString.fnHooked then return end
    fontString.fnHooked = true

    hooksecurefunc(fontString, "SetText", function(self, text)
        if self.fnUpdating or not FirstNames:ShouldHideOnUnitFrames() then return end
        if text and type(text) == "string" and text:find(" ") then
            if IsPlayerUnit(unitToken) then
                FirstNames:RegisterPlayer(text)
                local firstName = FirstNames:StripLastName(text)
                if firstName and firstName ~= text then
                    self.fnUpdating = true
                    self:SetText(firstName)
                    self.fnUpdating = nil
                end
            end
        end
    end)
end

local function InitUnitFrameHooks()
    -- Target Frame
    if TargetFrame and TargetFrame.name then
        HookUnitFrameName(TargetFrame.name, "target")
    end
    if TargetFrameTextureFrameName then
        HookUnitFrameName(TargetFrameTextureFrameName, "target")
    end
    if TargetFrame and type(TargetFrame.Update) == "function" then
        hooksecurefunc(TargetFrame, "Update", function(self)
            if not FirstNames:ShouldHideOnUnitFrames() then return end
            if TargetFrame.name and IsPlayerUnit("target") then
                local name = UnitName("target")
                if name and name:find(" ") then
                    TargetFrame.name:SetText(FirstNames:StripLastName(name))
                end
            end
        end)
    elseif type(_G.TargetFrame_Update) == "function" then
        hooksecurefunc("TargetFrame_Update", function(self)
            if not FirstNames:ShouldHideOnUnitFrames() then return end
            if TargetFrame and TargetFrame.name and IsPlayerUnit("target") then
                local name = UnitName("target")
                if name and name:find(" ") then
                    TargetFrame.name:SetText(FirstNames:StripLastName(name))
                end
            end
        end)
    end

    -- Focus Frame
    if FocusFrame and FocusFrame.name then
        HookUnitFrameName(FocusFrame.name, "focus")
    end
    if FocusFrameTextureFrameName then
        HookUnitFrameName(FocusFrameTextureFrameName, "focus")
    end
    if FocusFrame and type(FocusFrame.Update) == "function" then
        hooksecurefunc(FocusFrame, "Update", function(self)
            if not FirstNames:ShouldHideOnUnitFrames() then return end
            if FocusFrame.name and IsPlayerUnit("focus") then
                local name = UnitName("focus")
                if name and name:find(" ") then
                    FocusFrame.name:SetText(FirstNames:StripLastName(name))
                end
            end
        end)
    elseif type(_G.FocusFrame_Update) == "function" then
        hooksecurefunc("FocusFrame_Update", function(self)
            if not FirstNames:ShouldHideOnUnitFrames() then return end
            if FocusFrame and FocusFrame.name and IsPlayerUnit("focus") then
                local name = UnitName("focus")
                if name and name:find(" ") then
                    FocusFrame.name:SetText(FirstNames:StripLastName(name))
                end
            end
        end)
    end

    -- Player Frame
    if PlayerFrame and PlayerFrame.name then
        HookUnitFrameName(PlayerFrame.name, "player")
        hooksecurefunc(PlayerFrame.name, "SetText", function(self, text)
            if self.fnUpdating or not FirstNames:ShouldHideOnUnitFrames() then return end
            if text and text:find(" ") then
                local first = FirstNames:StripLastName(text)
                if first and first ~= text then
                    self.fnUpdating = true
                    self:SetText(first)
                    self.fnUpdating = nil
                end
            end
        end)
    end

    -- Target of Target
    if TargetFrameToT and TargetFrameToTTextureFrameName then
        HookUnitFrameName(TargetFrameToTTextureFrameName, "targettarget")
    end

    -- Focus of Target
    if FocusFrameToT and FocusFrameToTTextureFrameName then
        HookUnitFrameName(FocusFrameToTTextureFrameName, "focustarget")
    end

    -- Party Frames
    for i = 1, 4 do
        local partyName = _G["PartyMemberFrame" .. i .. "Name"]
        if partyName then
            HookUnitFrameName(partyName, "party" .. i)
        end
    end
end

--------------------------------------------------------------------------------
-- Frame Refresh (when toggled)
--------------------------------------------------------------------------------

function FirstNames:RefreshAllFrames()
    -- Target
    if TargetFrame and TargetFrame:IsShown() and UnitExists("target") then
        local name = UnitName("target")
        if name then
            local displayText = (self:ShouldHideOnUnitFrames() and IsPlayerUnit("target")) and self:StripLastName(name) or name
            if TargetFrame.name then TargetFrame.name:SetText(displayText) end
            if TargetFrameTextureFrameName then TargetFrameTextureFrameName:SetText(displayText) end
        end
    end

    -- Focus
    if FocusFrame and FocusFrame:IsShown() and UnitExists("focus") then
        local name = UnitName("focus")
        if name then
            local displayText = (self:ShouldHideOnUnitFrames() and IsPlayerUnit("focus")) and self:StripLastName(name) or name
            if FocusFrame.name then FocusFrame.name:SetText(displayText) end
            if FocusFrameTextureFrameName then FocusFrameTextureFrameName:SetText(displayText) end
        end
    end

    -- Player
    if PlayerFrame and PlayerFrame.name then
        local name = UnitName("player")
        if name then
            local displayText = (self:ShouldHideOnUnitFrames()) and self:StripLastName(name) or name
            PlayerFrame.name:SetText(displayText)
        end
    end

    -- Nameplates
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, np in ipairs(C_NamePlate.GetNamePlates()) do
            self:ProcessNameplate(np)
            self:ApplyNameplateHeight(np)
        end
    end

    -- Compact Raid / Party Frames
    if CompactRaidFrameContainer and CompactRaidFrameContainer_ApplyToFrames then
        CompactRaidFrameContainer_ApplyToFrames(CompactRaidFrameContainer, "normal", CompactUnitFrame_UpdateName)
    end
end

--------------------------------------------------------------------------------
-- Toggle Function (called by Keybind & Slash Command)
--------------------------------------------------------------------------------

function FirstNames:ToggleLastNames()
    FirstNamesDB.hideLastNames = not FirstNamesDB.hideLastNames

    if FirstNamesDB.hideLastNames then
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
        self:Print("Last names are now |cffff5555[HIDDEN]|r (showing first names only).")
    else
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        end
        self:Print("Last names are now |cff00ff00[SHOWN]|r (full names visible).")
    end

    -- Refresh Options panel if open
    if self.RefreshOptionsUI then
        self:RefreshOptionsUI()
    end

    -- Refresh all visible frames
    self:RefreshAllFrames()
end

--------------------------------------------------------------------------------
-- Keybinding Management
--------------------------------------------------------------------------------

function FirstNames:GetBoundKeyText()
    local key = GetBindingKey("FIRSTNAMES_TOGGLE")
    return key
end

function FirstNames:SetKeybind(newKey)
    if InCombatLockdown() then
        self:Print("Cannot change key bindings while in combat.")
        return false
    end

    -- Clear all existing keys bound to FIRSTNAMES_TOGGLE
    local existingKeys = { GetBindingKey("FIRSTNAMES_TOGGLE") }
    for _, k in ipairs(existingKeys) do
        SetBinding(k)
    end

    if newKey and newKey ~= "" then
        local prevAction = GetBindingAction(newKey)
        SetBinding(newKey, "FIRSTNAMES_TOGGLE")
        if prevAction and prevAction ~= "" and prevAction ~= "FIRSTNAMES_TOGGLE" then
            local prevName = _G["BINDING_NAME_" .. prevAction] or prevAction
            self:Print(newKey .. " was unbound from " .. prevName .. ".")
        end
        self:Print("Toggle keybind set to: |cff00ff00" .. newKey .. "|r")
    else
        self:Print("Toggle keybind cleared.")
    end

    local set = GetCurrentBindingSet and GetCurrentBindingSet()
    if set and SaveBindings then
        SaveBindings(set)
    end

    if self.RefreshKeybindButton then
        self:RefreshKeybindButton()
    end

    return true
end

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------

SLASH_FIRSTNAMES1 = "/firstnames"
SLASH_FIRSTNAMES2 = "/fn"
SlashCmdList["FIRSTNAMES"] = function(msg)
    local cmd = msg and msg:trim():lower() or ""

    if cmd == "toggle" or cmd == "t" then
        FirstNames:ToggleLastNames()
    elseif cmd == "status" or cmd == "s" then
        local status = FirstNames:IsActive() and "|cffff5555[HIDDEN]|r" or "|cff00ff00[SHOWN]|r"
        local key = FirstNames:GetBoundKeyText() or "None"
        FirstNames:Print("Status: Last names are " .. status .. " | Keybind: |cffffff00" .. key .. "|r")
    elseif cmd == "help" or cmd == "?" then
        FirstNames:Print("Commands:")
        print("  |cff00c0ff/fn|r - Open options window")
        print("  |cff00c0ff/fn toggle|r - Toggle last names on/off")
        print("  |cff00c0ff/fn status|r - Check current status and keybind")
        print("  |cff00c0ff/fn help|r - Show this help")
    else
        if FirstNames.OpenOptions then
            FirstNames:OpenOptions()
        else
            FirstNames:ToggleLastNames()
        end
    end
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Initialize SavedVariables
        FirstNamesDB = FirstNamesDB or {}
        for k, v in pairs(defaultDB) do
            if FirstNamesDB[k] == nil then
                FirstNamesDB[k] = v
            end
        end

        InitChatHooks()
        InitUnitFrameHooks()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Register current player name
        local myName = UnitName("player")
        if myName and myName:find(" ") then
            FirstNames:RegisterPlayer(myName)
        end
        FirstNames:EnsureNameplateCVars()
        FirstNames:RefreshAllFrames()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitExists("target") and IsPlayerUnit("target") then
            local targetName = UnitName("target")
            if targetName and targetName:find(" ") then
                FirstNames:RegisterPlayer(targetName)
                if FirstNames:ShouldHideOnUnitFrames() and TargetFrame and TargetFrame.name then
                    TargetFrame.name:SetText(FirstNames:StripLastName(targetName))
                end
            end
        end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        if UnitExists("focus") and IsPlayerUnit("focus") then
            local focusName = UnitName("focus")
            if focusName and focusName:find(" ") then
                FirstNames:RegisterPlayer(focusName)
                if FirstNames:ShouldHideOnUnitFrames() and FocusFrame and FocusFrame.name then
                    FocusFrame.name:SetText(FirstNames:StripLastName(focusName))
                end
            end
        end
    end
end)
