if (select(2, UnitClass("player"))) ~= "PALADIN" then return end

local myName = (...)
local _

local seals = {
    31892, -- blood
    348704, -- corruption
    20164, -- justice
    20165, -- light
    20154, -- righteousness
    21082, -- crusader
    348701, -- martyr
    31801, -- vengeance
    20166, -- wisdom
    27170, -- command
}

local nameIsSeal = {} -- populated on SPELLS_CHANGED

local OPTIONS -- populated from acedb

local IN_COMBAT = false

local barframe = CreateFrame("Frame", "SealBarFrame", UIParent)
barframe:SetMovable(true)
barframe:SetUserPlaced(false)
local barbg = barframe:CreateTexture(nil, "BACKGROUND")
barbg:SetAllPoints()
barbg:SetHorizTile(true)
barbg:SetVertexColor(0,.3,0)
local barfg = barframe:CreateTexture(nil, "ARTWORK")
barfg:SetPoint("TOPLEFT")
barfg:SetPoint("BOTTOMLEFT")
barfg:SetHorizTile(true)
barfg:SetVertexColor(0,.8,0)
local icon1frame = CreateFrame("Frame", nil, barframe)
icon1frame:SetPoint("RIGHT", barframe, "LEFT")
local icon1tex = icon1frame:CreateTexture(nil, "ARTWORK")
icon1tex:SetPoint("CENTER")
local icon2frame = CreateFrame("Frame", nil, barframe)
icon2frame:SetPoint("RIGHT", icon1frame, "LEFT")
local icon2tex = icon2frame:CreateTexture(nil, "ARTWORK")
icon2tex:SetAllPoints()
local moveframe = CreateFrame("Frame", nil, barframe)
moveframe:Hide()
moveframe:SetIgnoreParentAlpha(true)
moveframe:SetPoint("LEFT", icon2frame, "LEFT")
moveframe:SetPoint("TOP", barframe, "TOP")
moveframe:SetPoint("BOTTOM", barframe, "BOTTOM")
moveframe:SetPoint("RIGHT", barframe, "RIGHT")
moveframe:SetMouseClickEnabled(true)
moveframe:SetScript("OnMouseDown", function(_,b)
    if b == "LeftButton" then
        barframe:StartMoving()
        barframe:SetUserPlaced(false)
    elseif b == "RightButton" then
        moveframe:Hide()
        _G.SlashCmdList.SEALBAR()
    end
end)
moveframe:SetScript("OnMouseUp", function(_,b)
    if b ~= "LeftButton" then return end
    barframe:StopMovingOrSizing()
    OPTIONS.point, _, OPTIONS.relativeTo, OPTIONS.x, OPTIONS.y = barframe:GetPoint(1)
end)
local movebg = moveframe:CreateTexture(nil, "BACKGROUND")
movebg:SetAllPoints()
movebg:SetAlpha(.7)
movebg:SetColorTexture(.3,.3,1)
local movetext = moveframe:CreateFontString(nil, "ARTWORK")
movetext:SetAllPoints()
movetext:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
movetext:SetTextColor(1,1,1)
movetext:SetText("Left-click to move; Right-click to lock")

local UnitBuff = UnitBuff
local function FindSeals()
    local idx = 1
    local iconF, durationF, expireF
    while true do
        local name, icon, count, debuffType, duration, expirationTime = UnitBuff("player", idx)
        if not name then return iconF, durationF, expireF end
        if nameIsSeal[name] then
            if not iconF then
                iconF, durationF, expireF = icon, duration, expirationTime
            else
                if expirationTime < expireF then
                    return iconF, durationF, expireF, icon, duration, expirationTime
                else
                    return icon, duration, expirationTime, iconF, durationF, expireF
                end
            end
        end
        idx = idx + 1
    end
end

local timerupdate = CreateFrame("Frame")
timerupdate:Hide()
local GetTime, cos, _12pi = GetTime, math.cos, math.pi*12
local timerexpiry, timerduration
local function RedrawBar()
    local remaining = timerexpiry and max((timerexpiry - GetTime())/timerduration, 0) or 0
    local widthRemaining = OPTIONS.fill and (1-remaining) or remaining
    if remaining <= 0 then
        barfg:Hide()
    else
        barfg:SetWidth(remaining*OPTIONS.width)
        barfg:Show()
    end
    
    local r,g,b,a,s = 0,0,1,1,1
    if remaining <= OPTIONS.lowThreshold then
        r,g,b = 1,0,0
        a = OPTIONS.icLowAlpha
        if IN_COMBAT and OPTIONS.icPulseLow then
            local relative = (remaining/OPTIONS.lowThreshold)
            s = ((cos(relative*_12pi)-5)/-4)
        end
    elseif remaining >= OPTIONS.highThreshold then
        r,g,b = 0,1,0
        a = OPTIONS.icHighAlpha
    else
        local relProgress = (remaining - OPTIONS.lowThreshold) / (OPTIONS.highThreshold - OPTIONS.lowThreshold)
        if relProgress <= 0.5 then
            r,g,b = 1,(2*relProgress),0
        else
            r,g,b = (2*(1-relProgress)),1,0
        end
        a = (OPTIONS.icLowAlpha + relProgress*(OPTIONS.icHighAlpha - OPTIONS.icLowAlpha))
    end
    
    if not IN_COMBAT then
        if remaining > 0 then
            a = OPTIONS.oocSealAlpha
        else
            a = OPTIONS.oocNoneAlpha
        end
    end
    
    barbg:SetVertexColor(r*.3,g*.3,b*.3)
    barfg:SetVertexColor(r,g,b)
    barframe:SetAlpha(a)
    icon1tex:SetScale(s)
end
timerupdate:SetScript("OnUpdate", RedrawBar)

local function UpdateBar()
    local icon1, duration1, expire1, icon2, duration2, expire2 = FindSeals()
    if not icon1 then
        icon2tex:Hide()
        icon1tex:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark")
        timerupdate:Hide()
        timerexpiry = nil
        RedrawBar()
        return
    end

    icon1tex:SetTexture(icon1)
    timerexpiry = expire1
    timerduration = duration1
    timerupdate:Show()
    RedrawBar()
    
    if not icon2 then
        icon2tex:Hide()
        return
    end
    icon2tex:SetTexture(icon2)
    icon2tex:Show()
end

local __db
local LSM = LibStub("LibSharedMedia-3.0")
local function ApplyVisualOptions()
    barframe:StopMovingOrSizing()
    barframe:SetPoint(OPTIONS.point, UIParent, OPTIONS.relativeTo, OPTIONS.x, OPTIONS.y)
    barframe:SetSize(OPTIONS.width, OPTIONS.height)
    icon1frame:SetSize(OPTIONS.height, OPTIONS.height)
    icon1tex:SetSize(OPTIONS.height, OPTIONS.height)
    icon2frame:SetSize(OPTIONS.height, OPTIONS.height)
    icon2frame[OPTIONS.showTwist and "Show" or "Hide"](icon2frame)
    
    local tex = LSM:Fetch("statusbar", OPTIONS.barTexture)
    barfg:SetTexture(tex)
    barbg:SetTexture(tex)
    
    UpdateBar()
end

local options = {
    name = "SealBar",
    type = "group",
    args = {
        unlock = {
            name  = "Unlock bar",
            desc  = "Show the bar anchor, allowing you to reposition it",
            type  = "execute",
            width = "full",
            order = 1,
            func  = function() moveframe:Show() InterfaceOptionsFrame:Hide() end,
        },
        width = {
            name  = "Bar width",
            type  = "range",
            min   = 1,
          softMax = 800,
          bigStep = 5,
            order = 2,
            get   = function() return OPTIONS.width end,
            set   = function(_,v) OPTIONS.width = v ApplyVisualOptions() end,
        },
        height = {
            name  = "Bar height",
            type  = "range",
            min   = 1,
          softMax = 100,
          bigStep = 1,
            order = 3,
            get   = function() return OPTIONS.height end,
            set   = function(_,v) OPTIONS.height = v ApplyVisualOptions() end,
        },
        tex = {
            name  = "Bar texture",
            type  = "select",
           values = LSM:HashTable("statusbar"),
    dialogControl = "LSM30_Statusbar",
            order = 4,
            get   = function() return OPTIONS.barTexture end,
            set   = function(_,v) OPTIONS.barTexture = v ApplyVisualOptions() end,
        },
        fill = {
            name  = "Fill bar",
            desc  = "Bar starts empty and fills, rather than starting full and draining",
            type  = "toggle",
            order = 5,
            get   = function() return OPTIONS.fill end,
            set   = function(_,v) OPTIONS.fill = v RedrawBar() end,
        },
        twist = {
            name  = "Show twisted seal icon",
            type  = "toggle",
            order = 6,
            get   = function() return OPTIONS.showTwist end,
            set   = function(_,v) OPTIONS.showTwist = v ApplyVisualOptions() end,
        },
        lowThreshold = {
            name  = "Low duration threshold",
            type  = "range",
            min   = 0.01,
            max   = 0.49,
        isPercent = true,
            order = 7,
            get   = function() return OPTIONS.lowThreshold end,
            set   = function(_,v) OPTIONS.lowThreshold = v RedrawBar() end,
        },
        highThreshold = {
            name  = "High duration threshold",
            type  = "range",
            min   = 0.5,
            max   = 1,
        isPercent = true,
            order = 8,
            get   = function() return OPTIONS.highThreshold end,
            set   = function(_,v) OPTIONS.highThreshold = v RedrawBar() end,
        },
        highAlpha = {
            name  = "High duration alpha (in combat)",
            type  = "range",
            min   = 0,
            max   = 1,
        isPercent = true,
            order = 9,
            get  = function() return OPTIONS.icHighAlpha end,
            set  = function(_,v) OPTIONS.icHighAlpha = v RedrawBar() end,
        },
        lowAlpha = {
            name  = "Low duration alpha (in combat)",
            type  = "range",
            min   = 0,
            max   = 1,
        isPercent = true,
            order = 10,
            get   = function() return OPTIONS.icLowAlpha end,
            set   = function(_,v) OPTIONS.icLowAlpha = v RedrawBar() end,
        },
        pulseLow = {
            name  = "Pulse low duration (in combat)",
            type  = "toggle",
            order = 11,
            get   = function() return OPTIONS.icPulseLow end,
            set   = function(_,v) OPTIONS.icPulseLow = v RedrawBar() end,
        },
        noneAlpha = {
            name  = "No seal alpha (out of combat)",
            type  = "range",
            min   = 0,
            max   = 1,
        isPercent = true,
            order = 12,
            get   = function() return OPTIONS.oocNoneAlpha end,
            set   = function(_,v) OPTIONS.oocNoneAlpha = v RedrawBar() end,
        },
        sealAlpha = {
            name  = "With seal alpha (out of combat)",
            type  = "range",
            min   = 0,
            max   = 1,
        isPercent = true,
            order = 13,
            get   = function() return OPTIONS.oocSealAlpha end,
            set   = function(_,v) OPTIONS.oocSealAlpha = v RedrawBar() end,
        },
    },
}

local defaults = {
    point = "CENTER",
    relativeTo = "CENTER",
    x = 0,
    y = 0,
    width = 360,
    height = 20,
    showTwist = true,
    barTexture = "Blizzard",
    fill = false,
    
    lowThreshold = .2,
    highThreshold = .6,
    
    oocNoneAlpha = 0,
    oocSealAlpha = .25,
    
    icHighAlpha = .6,
    icLowAlpha = 1,
    icPulseLow = true,
}

local eventFrame = CreateFrame("Frame")
local eventFrame2 = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_,_,name)
    if name ~= myName then return end
    
    local db = LibStub("AceDB-3.0"):New("SealBar__DB", {profile = defaults})
    local adbDummy = { OnProfileEnable = function() OPTIONS = db.profile ApplyVisualOptions() end }
    db.RegisterCallback(adbDummy, "OnProfileChanged", "OnProfileEnable")
    db.RegisterCallback(adbDummy, "OnProfileCopied", "OnProfileEnable")
    db.RegisterCallback(adbDummy, "OnProfileReset", "OnProfileEnable")
    adbDummy:OnProfileEnable()
    
    local AC, ACD = LibStub("AceConfig-3.0"), LibStub("AceConfigDialog-3.0")
    AC:RegisterOptionsTable("SealBar", options)
    local optionsRef = ACD:AddToBlizOptions("SealBar")
    local optionsRefDummy = { element = optionsRef }
    
    AC:RegisterOptionsTable("SealBar-Profile", LibStub("AceDBOptions-3.0"):GetOptionsTable(db))
    ACD:AddToBlizOptions("SealBar-Profile", "Profiles", "SealBar")
    
    _G.SlashCmdList["SEALBAR"] = function()
        InterfaceOptionsFrame:Show() -- force it to load first
        InterfaceOptionsFrame_OpenToCategory(optionsRef) -- open to our category
        if optionsRef.collapsed then -- expand our sub-categories
            InterfaceOptionsListButton_ToggleSubCategories(optionsRefDummy)
        end
    end
    _G.SLASH_SEALBAR1 = "/sealbar"
    
    eventFrame:UnregisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:SetScript("OnEvent", function()
        for _, spellId in ipairs(seals) do nameIsSeal[(GetSpellInfo(spellId))] = true end
        eventFrame:UnregisterEvent("SPELLS_CHANGED")
        eventFrame:RegisterUnitEvent("UNIT_AURA","player")
        eventFrame2:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame2:RegisterEvent("PLAYER_REGEN_DISABLED")
        IN_COMBAT = InCombatLockdown()
        eventFrame:SetScript("OnEvent", UpdateBar)
        UpdateBar()
    end)
end)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame2:SetScript("OnEvent", function(_,e)
    IN_COMBAT = (e == "PLAYER_REGEN_DISABLED")
    RedrawBar()
end)
