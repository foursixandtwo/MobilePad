local addonName = ...
local f = CreateFrame("Frame", "MobilePadFrame")
local pendingApply = false
local uiFrame = nil
local minimapBtn = nil
local cursorModeActive = false
local DB_VERSION = 12

local PROFILE_LABELS = {
    mobile = "Mobile (8BitDo)",
    xbox   = "Xbox (Split)",
    iphone = "Alt (iPhone)",
}

-- Default bindings:
-- 1 = X (PAD3), 2 = Y (PAD4), 3 = B (PAD2), 4 = A (PAD1)
-- LB = Shift (GamePadEmulateShift = PADLSHOULDER) -> Action Bar 2
-- RB = PADRSHOULDER (SecureHandler) -> Action Bar 3 (1-4)
-- RT = PADRTRIGGER  (SecureHandler) -> Action Bar 3 (9-12) + Camera Zoom (RT + Up/Down)
-- LT = PADLTRIGGER  (SecureHandler) -> Action Bar 1 (5-8) + Action Bar Page (LT + Up/Down)
local DEFAULT_BINDINGS = {
    { cmd = "TARGETNEARESTENEMY",      label = "Target Nearest Enemy",             key = "PADRSTICK" },
    { cmd = "TOGGLEAUTORUN",           label = "Auto-Run (Left Stick)",            key = "PADLSTICK" },
    { cmd = "ACTIONBUTTON1",           label = "Action Bar 1 - Button 1",          key = "PAD3" }, -- X
    { cmd = "ACTIONBUTTON2",           label = "Action Bar 1 - Button 2",          key = "PAD4" }, -- Y
    { cmd = "ACTIONBUTTON3",           label = "Action Bar 1 - Button 3",          key = "PAD2" }, -- B
    { cmd = "ACTIONBUTTON4",           label = "Action Bar 1 - Button 4",          key = "PAD1" }, -- A
    { cmd = "ACTIONBUTTON5",           label = "Action Bar 1 - Button 5",          key = nil },
    { cmd = "ACTIONBUTTON6",           label = "Action Bar 1 - Button 6",          key = nil },
    { cmd = "ACTIONBUTTON7",           label = "Action Bar 1 - Button 7",          key = nil },
    { cmd = "ACTIONBUTTON8",           label = "Action Bar 1 - Button 8",          key = nil },
    { cmd = "MULTIACTIONBAR1BUTTON1",  label = "Action Bar 2 - Button 1 (LB)",     key = "SHIFT-PAD3" }, -- LB + X
    { cmd = "MULTIACTIONBAR1BUTTON2",  label = "Action Bar 2 - Button 2 (LB)",     key = "SHIFT-PAD4" }, -- LB + Y
    { cmd = "MULTIACTIONBAR1BUTTON3",  label = "Action Bar 2 - Button 3 (LB)",     key = "SHIFT-PAD2" }, -- LB + B
    { cmd = "MULTIACTIONBAR1BUTTON4",  label = "Action Bar 2 - Button 4 (LB)",     key = "SHIFT-PAD1" }, -- LB + A
    { cmd = "MULTIACTIONBAR1BUTTON5",  label = "Action Bar 2 - Button 5 (LB)",     key = "SHIFT-PADDLEFT" },
    { cmd = "MULTIACTIONBAR1BUTTON6",  label = "Action Bar 2 - Button 6 (LB)",     key = "SHIFT-PADDUP" },
    { cmd = "MULTIACTIONBAR1BUTTON7",  label = "Action Bar 2 - Button 7 (LB)",     key = "SHIFT-PADDRIGHT" },
    { cmd = "MULTIACTIONBAR1BUTTON12", label = "Action Bar 2 - Button 12 (§)",    key = "SHIFT-PADDDOWN" },
    { cmd = "JUMP",                    label = "Jump (Up / P2)",                   key = "PADDUP" },
    { cmd = "INTERACTTARGET",          label = "Loot / Interact (Down / P1)",      key = "PADDDOWN" },
    { cmd = "OPENALLBAGS",             label = "Open All Bags (Left)",             key = "PADDLEFT" },
    { cmd = "TOGGLEWORLDMAP",          label = "World Map (Right)",                key = "PADDRIGHT" },
    { cmd = "MOBILEPAD_CURSOR",        label = "Cursor Mode (Select / View)",      key = "PADBACK" },
    { cmd = "MOBILEPAD_STANCE",        label = "Berserker / Battle (LB + RB)",     key = "SHIFT-PADRSHOULDER" },
    { cmd = "TOGGLEGAMEMENU",          label = "Escape / Menu (Start / Menu)",     key = "PADFORWARD" },
    { cmd = "TOGGLEQUESTLOG",          label = "Quest Log (Xbox Share)",           key = nil, xboxKey = "PADSOCIAL" },
}

-- Create secure modifier buttons for RB, RT, and LT that work even in combat
local rbModBtn = CreateFrame("Button", "MobilePadRBMod", nil, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
rbModBtn:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(rbModBtn, "OnClick", rbModBtn, [[
    if down then
        self:SetBindingClick(true, "PAD3", "MultiBarBottomRightButton1")
        self:SetBindingClick(true, "PAD4", "MultiBarBottomRightButton2")
        self:SetBindingClick(true, "PAD2", "MultiBarBottomRightButton3")
        self:SetBindingClick(true, "PAD1", "MultiBarBottomRightButton4")
    else
        self:ClearBindings()
    end
]])

local rtModBtn = CreateFrame("Button", "MobilePadRTMod", nil, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
rtModBtn:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(rtModBtn, "OnClick", rtModBtn, [[
    if down then
        self:SetBindingClick(true, "PAD3", "MultiBarBottomRightButton9")
        self:SetBindingClick(true, "PAD4", "MultiBarBottomRightButton10")
        self:SetBindingClick(true, "PAD2", "MultiBarBottomRightButton11")
        self:SetBindingClick(true, "PAD1", "MultiBarBottomRightButton12")
        self:SetBinding(true, "PADDUP", "CAMERAZOOMIN")
        self:SetBinding(true, "PADDDOWN", "CAMERAZOOMOUT")
    else
        self:ClearBindings()
    end
]])

local ltModBtn = CreateFrame("Button", "MobilePadLTMod", nil, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
ltModBtn:RegisterForClicks("AnyDown", "AnyUp")
SecureHandlerWrapScript(ltModBtn, "OnClick", ltModBtn, [[
    if down then
        self:SetBinding(true, "PAD3", "ACTIONBUTTON5")
        self:SetBinding(true, "PAD4", "ACTIONBUTTON6")
        self:SetBinding(true, "PAD2", "ACTIONBUTTON7")
        self:SetBinding(true, "PAD1", "ACTIONBUTTON8")
        self:SetBinding(true, "PADDUP", "PREVIOUSACTIONPAGE")
        self:SetBinding(true, "PADDDOWN", "NEXTACTIONPAGE")
    else
        self:ClearBindings()
    end
]])

-- Button to toggle cursor mode with Select (-) / View
local cursorToggleBtn = CreateFrame("Button", "MobilePadCursorToggle", UIParent, "SecureActionButtonTemplate")
cursorToggleBtn:RegisterForClicks("AnyDown")

-- Combat-safe toggle between Berserker Stance and Battle Stance (LB + RB)
local stanceToggleBtn = CreateFrame("Button", "MobilePadStanceToggle", UIParent, "SecureActionButtonTemplate")
stanceToggleBtn:SetAttribute("type", "macro")
stanceToggleBtn:SetAttribute("macrotext", "/cast [stance:3] Battle Stance; Berserker Stance")
stanceToggleBtn:RegisterForClicks("AnyDown")

-- Clear indicator at top of screen when cursor mode is active
local cursorBadge = CreateFrame("Frame", "MobilePadCursorBadge", UIParent, "BackdropTemplate")
cursorBadge:SetSize(330, 26)
cursorBadge:SetPoint("TOP", UIParent, "TOP", 0, -14)
cursorBadge:SetFrameStrata("HIGH")
cursorBadge:EnableMouse(false)
cursorBadge:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
cursorBadge:SetBackdropColor(0.12, 0.08, 0.0, 0.88)
cursorBadge:SetBackdropBorderColor(1.0, 0.78, 0.1, 0.95)
local cursorBadgeText = cursorBadge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cursorBadgeText:SetPoint("CENTER")
cursorBadgeText:SetText("|cffffcc00CURSOR ACTIVE|r  |cffcccccc(Press Select/View to disable)|r")
cursorBadge:Hide()

-- Quest-item tracker above target portrait
local questBadge = CreateFrame("Frame", "MobilePadQuestBadge", UIParent, "BackdropTemplate")
questBadge:SetSize(130, 28)
questBadge:SetFrameStrata("HIGH")
questBadge:EnableMouse(false)
questBadge:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 12, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
questBadge:SetBackdropColor(0.08, 0.06, 0.02, 0.88)
questBadge:SetBackdropBorderColor(1.0, 0.82, 0.15, 0.95)
local questBadgeIcon = questBadge:CreateTexture(nil, "ARTWORK")
questBadgeIcon:SetSize(14, 14)
questBadgeIcon:SetPoint("TOPLEFT", 6, -6)
questBadgeIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
local questBadgeTitle = questBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
questBadgeTitle:SetPoint("TOPLEFT", questBadgeIcon, "TOPRIGHT", 4, 1)
questBadgeTitle:SetJustifyH("LEFT")
local questBadgeLines = questBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
questBadgeLines:SetPoint("TOPLEFT", questBadgeTitle, "BOTTOMLEFT", 0, -1)
questBadgeLines:SetJustifyH("LEFT")
do
    local fontPath, _, fontFlags = GameFontHighlightSmall:GetFont()
    if fontPath then
        questBadgeTitle:SetFont(fontPath, 9, fontFlags)
        questBadgeLines:SetFont(fontPath, 9, fontFlags)
    end
end
questBadge:Hide()

local questCache = { byTitle = {}, byDesc = {}, built = false }

local function NormalizeObjectiveDesc(text)
    if not text then return nil end
    local clean = text:gsub("^%s*%-+%s*", ""):match("^%s*(.-)%s*$")
    local desc = clean:match("^(.-)%s*:%s*%d+%s*/%s*%d+")
    if not desc then
        desc = clean:match("^%d+%s*/%s*%d+%s+(.+)$")
    end
    return (desc or clean):lower(), clean
end

local function RebuildQuestCache()
    questCache.byTitle = {}
    questCache.byDesc = {}
    questCache.built = true

    if not GetNumQuestLogEntries or not GetQuestLogTitle then return end
    local numEntries = GetNumQuestLogEntries() or 0
    for i = 1, numEntries do
        local title, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
        if not isHeader and title then
            local list = {}
            local numObj = GetNumQuestLeaderBoards and (GetNumQuestLeaderBoards(i) or 0) or 0
            for j = 1, numObj do
                local text, objType, finished = GetQuestLogLeaderBoard(j, i)
                if text then
                    local key = NormalizeObjectiveDesc(text)
                    local entry = { text = text, objType = objType, finished = finished and true or false }
                    table.insert(list, entry)
                    if key and key ~= "" then
                        questCache.byDesc[key] = entry
                    end
                end
            end
            if #list == 0 and questID and C_QuestLog and C_QuestLog.GetQuestObjectives then
                local objs = C_QuestLog.GetQuestObjectives(questID)
                if objs then
                    for _, obj in ipairs(objs) do
                        if obj and obj.text then
                            local key = NormalizeObjectiveDesc(obj.text)
                            local entry = { text = obj.text, objType = obj.type, finished = obj.finished and true or false }
                            table.insert(list, entry)
                            if key and key ~= "" then
                                questCache.byDesc[key] = entry
                            end
                        end
                    end
                end
            end
            questCache.byTitle[title] = list
        end
    end
end

local function CollectTargetQuestInfo()
    if not UnitExists("target") then return nil end
    if UnitIsPlayer("target") and not UnitCanAttack("player", "target") then
        return nil
    end
    if not questCache.built then
        RebuildQuestCache()
    end

    local matched = {}
    local sawAnyTooltipObj = false
    local currentTitle = nil
    local qtType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestTitle
    local qoType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective

    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local data = C_TooltipInfo.GetUnit("target")
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                local text = line and line.leftText
                if text and text ~= "" then
                    if (qtType and line.type == qtType) or questCache.byTitle[text] then
                        currentTitle = text
                    else
                        local normKey, cleanLine = NormalizeObjectiveDesc(text)
                        local cached = normKey and questCache.byDesc[normKey]
                        local isObjLine = (qoType and line.type == qoType) or (cached ~= nil)
                        if isObjLine then
                            sawAnyTooltipObj = true
                            local have, need = cleanLine:match("(%d+)%s*/%s*(%d+)")
                            local done = line.completed and true or (have and need and tonumber(have) >= tonumber(need)) or false
                            if not done then
                                local objType = cached and cached.objType
                                if not objType and not cleanLine:lower():find("slain") then
                                    objType = "item"
                                end
                                table.insert(matched, { text = cleanLine, objType = objType or "quest" })
                            end
                        end
                    end
                end
            end
        end
    end

    if #matched > 0 then
        local hasItem = false
        for _, m in ipairs(matched) do
            if m.objType == "item" then
                hasItem = true
                break
            end
        end
        return { hasItem = hasItem, lines = matched }
    end

    if not sawAnyTooltipObj and C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest and C_QuestLog.UnitIsRelatedToActiveQuest("target") then
        return { hasItem = false, lines = { { text = "Related to active quest", objType = "quest" } } }
    end
    return nil
end

local function UpdateTargetQuestTracker()
    if not MobilePadDB or MobilePadDB.questTracker == false then
        questBadge:Hide()
        return
    end

    local ok, info = pcall(CollectTargetQuestInfo)
    if not ok or not info or not info.lines or #info.lines == 0 then
        questBadge:Hide()
        return
    end

    questBadge:ClearAllPoints()
    local portrait = TargetFrame and (TargetFrame.portrait or _G["TargetFramePortrait"])
    if portrait then
        questBadge:SetPoint("BOTTOM", portrait, "TOP", 0, 5)
    elseif TargetFrame then
        questBadge:SetPoint("BOTTOMRIGHT", TargetFrame, "TOPRIGHT", -14, -8)
    else
        questBadge:SetPoint("TOP", UIParent, "TOP", 0, -48)
    end

    if info.hasItem then
        questBadgeIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
        questBadge:SetBackdropBorderColor(1.0, 0.82, 0.15, 0.95)
        questBadgeTitle:SetText("|cffffd100QUEST ITEM|r")
    else
        questBadgeIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
        questBadge:SetBackdropBorderColor(0.85, 0.85, 0.35, 0.90)
        questBadgeTitle:SetText("|cffffff66QUEST|r")
    end

    local shown = {}
    for i = 1, math.min(#info.lines, 3) do
        table.insert(shown, info.lines[i].text)
    end
    questBadgeLines:SetText(table.concat(shown, "\n"))

    local textW = math.max(questBadgeTitle:GetStringWidth() or 60, questBadgeLines:GetStringWidth() or 60)
    local textH = (questBadgeTitle:GetStringHeight() or 10) + (questBadgeLines:GetStringHeight() or 10)
    questBadge:SetSize(math.max(105, textW + 30), math.max(26, textH + 12))
    questBadge:Show()
end

local MODIFIER_BUTTONS = {
    PADLTRIGGER = true,
    PADRTRIGGER = true,
    PADLSHOULDER = true,
    PADRSHOULDER = true,
}

local function BuildDefaultBindings(profileName)
    local out = {}
    for _, entry in ipairs(DEFAULT_BINDINGS) do
        local k = (profileName == "xbox" and entry.xboxKey ~= nil) and entry.xboxKey or entry.key
        if k then
            out[entry.cmd] = k
        end
    end
    return out
end

local function NormalizeProfileName(profileName)
    if PROFILE_LABELS[profileName] then
        return profileName
    end
    return "mobile"
end

local function ResetProfileToDefaults(profileName)
    profileName = NormalizeProfileName(profileName)
    MobilePadDB.profiles[profileName] = {
        bindings = BuildDefaultBindings(profileName),
    }
end

local function GetActiveBindings()
    local name = NormalizeProfileName(MobilePadDB and MobilePadDB.activeProfile)
    if not MobilePadDB.profiles or not MobilePadDB.profiles[name] then
        ResetProfileToDefaults(name)
    end
    return MobilePadDB.profiles[name].bindings
end

local function InitDB()
    if type(MobilePadDB) ~= "table" then
        MobilePadDB = {}
    end
    if MobilePadDB.enabled == nil then
        MobilePadDB.enabled = true
    end
    if MobilePadDB.autoScale == nil then
        MobilePadDB.autoScale = true
    end
    if MobilePadDB.mobileScale == nil then
        MobilePadDB.mobileScale = 0.78
    end
    if MobilePadDB.questTracker == nil then
        MobilePadDB.questTracker = true
    end
    if not PROFILE_LABELS[MobilePadDB.activeProfile] then
        MobilePadDB.activeProfile = "mobile"
    end
    if type(MobilePadDB.profiles) ~= "table" then
        MobilePadDB.profiles = {}
    end

    -- Migrate any existing v10 bindings to mobile profile
    if type(MobilePadDB.profiles.mobile) ~= "table" then
        if type(MobilePadDB.bindings) == "table" and (MobilePadDB.version or 0) == 10 then
            MobilePadDB.profiles.mobile = { bindings = MobilePadDB.bindings }
            if MobilePadDB.profiles.mobile.bindings["MOBILEPAD_CURSOR"] == nil then
                MobilePadDB.profiles.mobile.bindings["MOBILEPAD_CURSOR"] = "PADBACK"
            end
        else
            ResetProfileToDefaults("mobile")
        end
    end
    for profName in pairs(PROFILE_LABELS) do
        if type(MobilePadDB.profiles[profName]) ~= "table" then
            ResetProfileToDefaults(profName)
        end
    end

    if (MobilePadDB.version or 0) < 12 then
        for _, prof in pairs(MobilePadDB.profiles) do
            if type(prof) == "table" and type(prof.bindings) == "table" and prof.bindings["MOBILEPAD_STANCE"] == nil then
                prof.bindings["MOBILEPAD_STANCE"] = "SHIFT-PADRSHOULDER"
            end
        end
    end

    -- Discard legacy UIParent-anchored minimapPos that could place the button off-minimap
    if type(MobilePadDB.minimapPos) == "table" and (MobilePadDB.minimapPos.dx == nil or MobilePadDB.minimapPos.dy == nil) then
        MobilePadDB.minimapPos = nil
    end

    MobilePadDB.bindings = nil
    MobilePadDB.version = DB_VERSION
end

local function ApplyScale()
    if InCombatLockdown() or not MobilePadDB or not MobilePadDB.autoScale then return end
    local _, physH = GetPhysicalScreenSize()
    if physH and physH <= 800 then
        if MobilePadDB.pcUseUiScale == nil then
            local curUse = GetCVar("useUiScale")
            local cur = tonumber(GetCVar("uiScale"))
            MobilePadDB.pcUseUiScale = (curUse == "1") and "1" or "0"
            if curUse == "1" and cur and cur > 0 then
                MobilePadDB.pcScale = cur
            end
        end
        local target = MobilePadDB.mobileScale or 0.78
        if GetCVar("useUiScale") ~= "1" then
            SetCVar("useUiScale", 1)
        end
        local curScale = tonumber(GetCVar("uiScale")) or 1.0
        if math.abs(curScale - target) > 0.01 then
            SetCVar("uiScale", target)
        end
    else
        local wantUse = MobilePadDB.pcUseUiScale
        if wantUse == "0" or (wantUse == nil and MobilePadDB.pcScale == 1) then
            MobilePadDB.pcUseUiScale = "0"
            if GetCVar("useUiScale") ~= "0" then
                SetCVar("useUiScale", 0)
            end
        elseif wantUse == "1" and MobilePadDB.pcScale then
            if GetCVar("useUiScale") ~= "1" then
                SetCVar("useUiScale", 1)
            end
            local curScale = tonumber(GetCVar("uiScale")) or 1.0
            if math.abs(curScale - MobilePadDB.pcScale) > 0.01 then
                SetCVar("uiScale", MobilePadDB.pcScale)
            end
        elseif GetCVar("useUiScale") == "1" and math.abs((tonumber(GetCVar("uiScale")) or 1.0) - (MobilePadDB.mobileScale or 0.78)) < 0.02 then
            SetCVar("useUiScale", 0)
        end
    end
end

local function ApplyBindings()
    if InCombatLockdown() then
        pendingApply = true
        return
    end

    ClearOverrideBindings(f)

    if not MobilePadDB or MobilePadDB.enabled == false then
        if MobilePadDB and MobilePadDB.prevHardwareCursor ~= nil then
            pcall(SetCVar, "HardwareCursor", MobilePadDB.prevHardwareCursor)
            MobilePadDB.prevHardwareCursor = nil
        end
        pendingApply = false
        if minimapBtn and minimapBtn.UpdateColor then
            minimapBtn.UpdateColor()
        end
        return
    end

    -- Force software cursor so cursor is visible in GamePad mode under Wine/Proton/Moonlight
    if MobilePadDB.prevHardwareCursor == nil then
        MobilePadDB.prevHardwareCursor = GetCVar("HardwareCursor")
    end
    if GetCVar("HardwareCursor") ~= "0" then
        pcall(SetCVar, "HardwareCursor", 0)
    end

    -- LB = Shift; RB, RT, and LT are handled via SecureHandlers above
    if GetCVar("GamePadEmulateShift") ~= "PADLSHOULDER" then
        pcall(SetCVar, "GamePadEmulateShift", "PADLSHOULDER")
    end
    pcall(SetCVar, "GamePadEmulateCtrl", "none")
    pcall(SetCVar, "GamePadEmulateAlt", "none")

    if GetCVar("SoftTargetInteract") ~= "3" then
        pcall(SetCVar, "SoftTargetInteract", 3)
    end
    if GetCVar("autoLootDefault") ~= "1" then
        pcall(SetCVar, "autoLootDefault", 1)
    end
    if GetCVar("GamePadEnable") ~= "1" then
        pcall(SetCVar, "GamePadEnable", 1)
    end
    pcall(SetCVar, "GamePadCursorAutoEnable", 0)
    pcall(SetCVar, "GamePadCursorForTargeting", 0)
    pcall(SetCVar, "GamePadCursorLeftClick", "PAD1")
    pcall(SetCVar, "GamePadCursorRightClick", "PAD3")
    pcall(SetCVar, "GamePadCursorCenteredEmulation", 0)
    pcall(SetCVar, "GamePadCursorCentering", 0)
    pcall(SetCVar, "GamePadCursorAutoDisableSticks", 0)
    pcall(SetCVar, "GamePadCursorAutoDisableJump", 0)

    for cmd, key in pairs(GetActiveBindings()) do
        if key and key ~= "" then
            if cmd == "MOBILEPAD_CURSOR" then
                SetOverrideBindingClick(f, true, key, "MobilePadCursorToggle")
            elseif cmd == "MOBILEPAD_STANCE" then
                SetOverrideBindingClick(f, true, key, "MobilePadStanceToggle")
            else
                SetOverrideBinding(f, true, key, cmd)
            end
        end
    end

    -- Bind RB, RT, and LT to their SecureHandlers
    SetOverrideBindingClick(f, true, "PADRSHOULDER", "MobilePadRBMod")
    SetOverrideBindingClick(f, true, "PADRTRIGGER",  "MobilePadRTMod")
    SetOverrideBindingClick(f, true, "PADLTRIGGER",  "MobilePadLTMod")

    pendingApply = false
    if minimapBtn and minimapBtn.UpdateColor then
        minimapBtn.UpdateColor()
    end
end

local function IsCursorEnabledNow()
    if IsGamePadCursorControlEnabled then
        local ok, res = pcall(IsGamePadCursorControlEnabled)
        if ok then
            return res and true or false
        end
    end
    return cursorModeActive
end

local function UpdateCursorBadge(active)
    cursorModeActive = active and true or false
    if cursorModeActive then
        cursorBadge:Show()
    else
        cursorBadge:Hide()
    end
end

local function SetCursorMode(active, silent)
    active = active and true or false
    if active then
        if GetCVar("HardwareCursor") ~= "0" then
            pcall(SetCVar, "HardwareCursor", 0)
        end
        if IsMouselooking and IsMouselooking() and MouselookStop then
            pcall(MouselookStop)
        end
        if SetGamePadFreeLook then
            pcall(SetGamePadFreeLook, false)
        end
    end

    local ok, err = true, nil
    if SetGamePadCursorControl then
        ok, err = pcall(SetGamePadCursorControl, active)
    else
        ok, err = false, "SetGamePadCursorControl missing"
    end

    local nowEnabled = IsCursorEnabledNow()
    UpdateCursorBadge(nowEnabled)

    if not silent then
        C_Timer.After(0.05, function()
            local laterEnabled = IsCursorEnabledNow()
            UpdateCursorBadge(laterEnabled)
            if active and not laterEnabled then
                local canCur = CanGamePadControlCursor and tostring(CanGamePadControlCursor()) or "?"
                local gpEn = tostring(GetCVar("GamePadEnable") or "?")
                local fl = IsGamePadFreelookEnabled and tostring(IsGamePadFreelookEnabled()) or "?"
                print(string.format(
                    "|cffff5555MobilePad:|r Cursor mode failed to activate (ok=%s, err=%s, now=%s, later=%s, canCursor=%s, gpEnable=%s, freeLook=%s).",
                    tostring(ok), tostring(err), tostring(nowEnabled), tostring(laterEnabled), canCur, gpEn, fl
                ))
            elseif active and laterEnabled then
                print("|cff00ff96MobilePad:|r Cursor ON (move with stick, A=left-click, X=right-click).")
            else
                print("|cff00ff96MobilePad:|r Cursor OFF.")
            end
        end)
    end
end

cursorToggleBtn:SetScript("OnClick", function()
    SetCursorMode(not IsCursorEnabledNow())
end)

local function ToggleUI()
    local ui = CreateConfigUI()
    if ui:IsShown() then
        ui:Hide()
    else
        ui:Show()
    end
end

local function CreateMinimapButton()
    if minimapBtn then return end
    local btn = CreateFrame("Button", "MobilePadMinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetClampedToScreen(true)
    local pos = MobilePadDB and MobilePadDB.minimapPos
    if type(pos) == "table" and pos.dx and pos.dy and math.abs(pos.dx) <= 220 and math.abs(pos.dy) <= 220 then
        btn:SetPoint("CENTER", Minimap, "CENTER", pos.dx, pos.dy)
    else
        btn:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -2, 2)
    end
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self._dragging = true
            self:StartMoving()
        end
    end)
    btn:SetScript("OnDragStop", function(self)
        if not self._dragging then return end
        self._dragging = false
        self:StopMovingOrSizing()
        local bx, by = self:GetCenter()
        local mx, my = Minimap:GetCenter()
        if MobilePadDB and bx and by and mx and my then
            local dx, dy = bx - mx, by - my
            MobilePadDB.minimapPos = { dx = dx, dy = dy }
            self:ClearAllPoints()
            self:SetPoint("CENTER", Minimap, "CENTER", dx, dy)
        end
    end)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\AddOns\\MobilePad\\minimap_icon")

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    btn.UpdateColor = function()
        if MobilePadDB and MobilePadDB.enabled ~= false then
            icon:SetDesaturated(false)
            icon:SetVertexColor(1, 1, 1)
            border:SetVertexColor(1, 1, 1)
        else
            icon:SetDesaturated(true)
            icon:SetVertexColor(0.55, 0.55, 0.55)
            border:SetVertexColor(0.65, 0.65, 0.65)
        end
    end
    btn.UpdateColor()

    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            MobilePadDB.enabled = not MobilePadDB.enabled
            ApplyBindings()
            btn.UpdateColor()
        else
            ToggleUI()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("MobilePad")
        GameTooltip:AddLine("Left-Click: Open settings", 1, 1, 1)
        GameTooltip:AddLine("Right-Click: Toggle on/off", 1, 1, 1)
        GameTooltip:AddLine("Shift+Drag: Move button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    minimapBtn = btn
end

function CreateConfigUI()
    if uiFrame then return uiFrame end

    local frame = CreateFrame("Frame", "MobilePadConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(460, 584)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.TitleText:SetText("MobilePad - Controller Keybindings")

    local enableCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 16, -32)
    enableCheck.text = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableCheck.text:SetPoint("LEFT", enableCheck, "RIGHT", 4, 0)
    enableCheck.text:SetText("Enable MobilePad (does not overwrite keyboard binds)")
    enableCheck:SetScript("OnClick", function(self)
        MobilePadDB.enabled = self:GetChecked() and true or false
        ApplyBindings()
    end)

    local scaleCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    scaleCheck:SetPoint("TOPLEFT", 16, -58)
    scaleCheck.text = scaleCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleCheck.text:SetPoint("LEFT", scaleCheck, "RIGHT", 4, 0)
    scaleCheck.text:SetText("Auto UI Scale on mobile (720p = 0.78, restored on PC)")
    scaleCheck:SetScript("OnClick", function(self)
        MobilePadDB.autoScale = self:GetChecked() and true or false
        ApplyScale()
    end)

    local questCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    questCheck:SetPoint("TOPLEFT", 16, -84)
    questCheck.text = questCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    questCheck.text:SetPoint("LEFT", questCheck, "RIGHT", 4, 0)
    questCheck.text:SetText("Show Quest-item tracker near target")
    questCheck:SetScript("OnClick", function(self)
        MobilePadDB.questTracker = self:GetChecked() and true or false
        UpdateTargetQuestTracker()
    end)

    local profileLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profileLabel:SetPoint("TOPLEFT", 20, -116)
    profileLabel:SetText("Profile:")

    local mobProfBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    mobProfBtn:SetSize(118, 22)
    mobProfBtn:SetPoint("LEFT", profileLabel, "RIGHT", 6, 0)

    local xboxProfBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    xboxProfBtn:SetSize(114, 22)
    xboxProfBtn:SetPoint("LEFT", mobProfBtn, "RIGHT", 4, 0)

    local iphoneProfBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    iphoneProfBtn:SetSize(118, 22)
    iphoneProfBtn:SetPoint("LEFT", xboxProfBtn, "RIGHT", 4, 0)

    local STATUS_DEFAULT_TEXT = "Select = Cursor | LT = Bar 1 (5-8) & Page | RT = Bar 3 & Zoom"
    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 20, -144)
    statusText:SetText(STATUS_DEFAULT_TEXT)

    local scrollFrame = CreateFrame("ScrollFrame", "MobilePadScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -164)
    scrollFrame:SetPoint("BOTTOMRIGHT", -36, 46)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(390, #DEFAULT_BINDINGS * 28 + 10)
    scrollFrame:SetScrollChild(content)

    local listener = CreateFrame("Frame", nil, frame)
    listener:SetAllPoints(UIParent)
    listener:SetFrameStrata("FULLSCREEN_DIALOG")
    listener:EnableKeyboard(true)
    listener:EnableGamePadButton(true)
    listener:EnableMouse(true)
    listener:Hide()

    local activeCmd = nil
    local heldMod = nil

    local function RefreshUI()
        enableCheck:SetChecked(MobilePadDB.enabled)
        scaleCheck:SetChecked(MobilePadDB.autoScale)
        questCheck:SetChecked(MobilePadDB.questTracker ~= false)
        local active = MobilePadDB.activeProfile
        mobProfBtn:SetText((active == "mobile" and "|cff00ff96* " or "") .. PROFILE_LABELS.mobile .. (active == "mobile" and "|r" or ""))
        xboxProfBtn:SetText((active == "xbox" and "|cff00ff96* " or "") .. PROFILE_LABELS.xbox .. (active == "xbox" and "|r" or ""))
        iphoneProfBtn:SetText((active == "iphone" and "|cff00ff96* " or "") .. PROFILE_LABELS.iphone .. (active == "iphone" and "|r" or ""))
        local bindings = GetActiveBindings()
        for _, row in ipairs(frame.rows) do
            local key = bindings[row.cmd]
            row.btn:SetText(key and key ~= "" and key or "|cff888888Unbound|r")
        end
    end
    frame.RefreshUI = RefreshUI

    local function SelectProfile(profileName)
        if InCombatLockdown() then
            print("|cff00ff96MobilePad:|r Cannot switch profiles during combat.")
            return
        end
        MobilePadDB.activeProfile = NormalizeProfileName(profileName)
        if cursorModeActive then
            SetCursorMode(false, true)
        end
        ApplyBindings()
        RefreshUI()
    end

    mobProfBtn:SetScript("OnClick", function() SelectProfile("mobile") end)
    xboxProfBtn:SetScript("OnClick", function() SelectProfile("xbox") end)
    iphoneProfBtn:SetScript("OnClick", function() SelectProfile("iphone") end)

    local function StopListening(newKey)
        listener:Hide()
        heldMod = nil
        if activeCmd and newKey ~= false then
            local bindings = GetActiveBindings()
            if newKey == nil then
                bindings[activeCmd] = nil
            else
                for c, k in pairs(bindings) do
                    if k == newKey then
                        bindings[c] = nil
                    end
                end
                bindings[activeCmd] = newKey
            end
            ApplyBindings()
        end
        activeCmd = nil
        statusText:SetText(STATUS_DEFAULT_TEXT)
        RefreshUI()
    end

    listener:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            StopListening(nil)
        end
    end)

    listener:SetScript("OnMouseDown", function()
        StopListening(false)
    end)

    listener:SetScript("OnGamePadButtonDown", function(_, button)
        if MODIFIER_BUTTONS[button] and not (IsShiftKeyDown() and button ~= "PADLSHOULDER") then
            heldMod = button
            return
        end

        local prefix = ""
        if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
        if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
        if IsAltKeyDown() then prefix = prefix .. "ALT-" end

        if prefix ~= "" then
            StopListening(prefix .. button)
        elseif heldMod then
            StopListening(heldMod .. "-" .. button)
        else
            StopListening(button)
        end
    end)

    listener:SetScript("OnGamePadButtonUp", function(_, button)
        if MODIFIER_BUTTONS[button] and heldMod == button then
            StopListening(button)
        end
    end)

    frame.rows = {}
    for i, entry in ipairs(DEFAULT_BINDINGS) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(390, 26)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 28)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", 4, 0)
        label:SetText(entry.label)

        local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btn:SetSize(165, 22)
        btn:SetPoint("RIGHT", -4, 0)
        btn:SetScript("OnClick", function()
            if InCombatLockdown() then
                print("|cff00ff96MobilePad:|r Cannot change bindings during combat.")
                return
            end
            activeCmd = entry.cmd
            heldMod = nil
            statusText:SetText("|cffffff00Press a controller button for: " .. entry.label .. " (ESC = clear)|r")
            listener:Show()
        end)

        row.cmd = entry.cmd
        row.btn = btn
        table.insert(frame.rows, row)
    end

    local layoutFrame
    local function ToggleLayoutImage()
        if layoutFrame then
            if layoutFrame:IsShown() then
                layoutFrame:Hide()
            else
                layoutFrame:Show()
            end
            return
        end

        local lf = CreateFrame("Frame", "MobilePadLayoutFrame", UIParent, "BasicFrameTemplateWithInset")
        lf:SetSize(740, 520)
        lf:SetPoint("CENTER")
        lf:SetFrameStrata("DIALOG")
        lf:SetMovable(true)
        lf:EnableMouse(true)
        lf:RegisterForDrag("LeftButton")
        lf:SetScript("OnDragStart", lf.StartMoving)
        lf:SetScript("OnDragStop", lf.StopMovingOrSizing)
        table.insert(UISpecialFrames, "MobilePadLayoutFrame")

        lf.TitleText:SetText("MobilePad - Controller Layout")

        local tex = lf:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 12, -30)
        tex:SetPoint("BOTTOMRIGHT", -12, 12)
        tex:SetTexture("Interface\\AddOns\\MobilePad\\controller_layout")
        tex:SetTexCoord(0, 1, 0, 673 / 1024)

        layoutFrame = lf
    end

    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 24)
    resetBtn:SetPoint("BOTTOMLEFT", 16, 14)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        if InCombatLockdown() then
            print("|cff00ff96MobilePad:|r Cannot reset bindings during combat.")
            return
        end
        ResetProfileToDefaults(MobilePadDB.activeProfile)
        ApplyBindings()
        RefreshUI()
    end)

    local imgBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    imgBtn:SetSize(140, 24)
    imgBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
    imgBtn:SetText("Show Layout")
    imgBtn:SetScript("OnClick", ToggleLayoutImage)

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 24)
    closeBtn:SetPoint("BOTTOMRIGHT", -16, 14)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnShow", RefreshUI)
    uiFrame = frame
    return frame
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("UNIT_QUEST_LOG_CHANGED")

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()
    elseif event == "PLAYER_LOGIN" then
        CreateMinimapButton()
        ApplyBindings()
        if GetCVar("threatShowNumeric") ~= "1" then
            pcall(SetCVar, "threatShowNumeric", 1)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, ApplyScale)
        RebuildQuestCache()
        UpdateTargetQuestTracker()
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateTargetQuestTracker()
    elseif event == "QUEST_LOG_UPDATE" or (event == "UNIT_QUEST_LOG_CHANGED" and arg1 == "player") then
        RebuildQuestCache()
        UpdateTargetQuestTracker()
    elseif event == "PLAYER_REGEN_DISABLED" then
        if cursorModeActive then
            SetCursorMode(false, true)
        end
    elseif event == "PLAYER_REGEN_ENABLED" and pendingApply then
        ApplyBindings()
    end
end)

local function SwitchProfileSlash(profileName)
    if InCombatLockdown() then
        print("|cff00ff96MobilePad:|r Cannot switch profiles during combat.")
        return
    end
    profileName = NormalizeProfileName(profileName)
    MobilePadDB.activeProfile = profileName
    if cursorModeActive then
        SetCursorMode(false, true)
    end
    ApplyBindings()
    if uiFrame and uiFrame.RefreshUI then uiFrame.RefreshUI() end
    print("|cff00ff96MobilePad:|r Profile switched to " .. PROFILE_LABELS[profileName] .. ".")
end

SLASH_MOBILEPAD1 = "/mp"
SLASH_MOBILEPAD2 = "/mobilepad"
SlashCmdList["MOBILEPAD"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "off" then
        MobilePadDB.enabled = false
        ApplyBindings()
        print("|cff00ff96MobilePad:|r Disabled (default bindings active).")
    elseif msg == "on" then
        MobilePadDB.enabled = true
        ApplyBindings()
        print("|cff00ff96MobilePad:|r Enabled.")
    elseif msg == "xbox" or msg == "profile xbox" or msg == "profil xbox" then
        SwitchProfileSlash("xbox")
    elseif msg == "iphone" or msg == "alt" or msg == "profile iphone" or msg == "profile alt" then
        SwitchProfileSlash("iphone")
    elseif msg == "cursor" or msg == "mus" then
        SetCursorMode(not IsCursorEnabledNow())
    elseif msg == "quest" then
        MobilePadDB.questTracker = (MobilePadDB.questTracker == false) and true or false
        UpdateTargetQuestTracker()
        if uiFrame and uiFrame.RefreshUI then uiFrame.RefreshUI() end
        print("|cff00ff96MobilePad:|r Quest-item tracker " .. (MobilePadDB.questTracker and "ON." or "OFF."))
    elseif msg == "mobile" or msg == "mobil" or msg == "profile mobile" or msg == "profil mobil" or msg == "profil mobile" then
        SwitchProfileSlash("mobile")
    else
        ToggleUI()
    end
end
