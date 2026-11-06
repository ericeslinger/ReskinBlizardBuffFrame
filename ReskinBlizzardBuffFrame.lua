--[[ ReskinBlizzardBuffFrame

Moves and scales Blizzard's own BuffFrame and DebuffFrame, for clients (WoW: Forever)
whose Edit Mode does not expose them. Blizzard's frames keep what addon-drawn aura
displays cannot have under Forever's aura restrictions: tooltips and right-click cancel.

  /rbf                      help
  /rbf unlock | lock        drag the frames by their overlay; lock saves
  /rbf scale <n>            scale both frames (0.5 - 2)
  /rbf buffs <point> <x> <y>   e.g. /rbf buffs TOPRIGHT -10 -40
  /rbf debuffs <point> <x> <y>
  /rbf debuffs follow       anchor the debuffs under the buffs (default)
  /rbf reset                defaults

Positions are relative to UIParent at the given point. The frames are re-anchored
after every SetPoint the game performs on them, so a layout refresh cannot undo it;
nothing is touched during combat (deferred to PLAYER_REGEN_ENABLED).
--]]

local ADDON = ...

local DEFAULTS = {
    scale = 0.9,
    buffs   = { point = "TOPRIGHT", x = -10, y = -40 },
    debuffs = { follow = true, point = "TOPRIGHT", x = -10, y = -140, gap = 12 },
}

local db
local applying = false
local pendingApply = false
local overlays = {}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff3fc9f2RBF|r: " .. tostring(msg))
end

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function Frames()
    return _G.BuffFrame, _G.DebuffFrame
end

-- ---------------------------------------------------------------------------
-- apply
-- ---------------------------------------------------------------------------

local function Apply()
    if InCombatLockdown() then pendingApply = true return end
    local buffs, debuffs = Frames()
    if not buffs then return end
    applying = true
    buffs:SetScale(db.scale)
    buffs:ClearAllPoints()
    buffs:SetPoint(db.buffs.point, UIParent, db.buffs.point, db.buffs.x, db.buffs.y)
    if debuffs then
        debuffs:SetScale(db.scale)
        debuffs:ClearAllPoints()
        if db.debuffs.follow then
            -- hang under the buffs, aligned to the same horizontal edge
            local p = db.buffs.point
            local right = p:find("RIGHT") ~= nil
            debuffs:SetPoint(right and "TOPRIGHT" or "TOPLEFT", buffs,
                right and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -db.debuffs.gap)
        else
            debuffs:SetPoint(db.debuffs.point, UIParent, db.debuffs.point, db.debuffs.x, db.debuffs.y)
        end
    end
    applying = false
end

-- If the game re-anchors the frames (layout refresh, edit mode apply), put them back.
local hooked = {}
local function HookFrame(f)
    if not f or hooked[f] then return end
    hooked[f] = true
    hooksecurefunc(f, "SetPoint", function()
        if applying then return end
        -- run after the game's own anchoring finishes
        C_Timer.After(0, Apply)
    end)
end

-- ---------------------------------------------------------------------------
-- drag overlays
-- ---------------------------------------------------------------------------

local function SavePosition(key, f)
    -- store as the frame's current anchor relative to UIParent, using the
    -- configured point so the frame keeps growing the same direction
    local point = db[key].point
    local scale = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y
    local l, r, t, b = f:GetLeft() * scale, f:GetRight() * scale, f:GetTop() * scale, f:GetBottom() * scale
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    if point:find("LEFT") then x = l elseif point:find("RIGHT") then x = r - W else x = (l + r) / 2 - W / 2 end
    if point:find("TOP") then y = t - H elseif point:find("BOTTOM") then y = b else y = (t + b) / 2 - H / 2 end
    db[key].x, db[key].y = math.floor(x + 0.5), math.floor(y + 0.5)
end

local function Overlay(key, f, label)
    if overlays[key] then return overlays[key] end
    local o = CreateFrame("Frame", ADDON .. key .. "Overlay", UIParent, "BackdropTemplate")
    o:SetFrameStrata("DIALOG")
    o:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    o:SetBackdropColor(0.25, 0.8, 0.95, 0.35)
    o:SetBackdropBorderColor(0.25, 0.8, 0.95, 0.9)
    o:EnableMouse(true)
    o:SetMovable(true)
    o:RegisterForDrag("LeftButton")
    local fs = o:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("CENTER")
    fs:SetText(label)
    o:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self:StartMoving()
    end)
    o:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- move the real frame to the overlay, then re-anchor it from there
        applying = true
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        applying = false
        if key == "debuffs" then db.debuffs.follow = false end
        SavePosition(key, f)
        Apply()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    end)
    o:Hide()
    overlays[key] = o
    return o
end

local function SetUnlocked(on)
    local buffs, debuffs = Frames()
    if not buffs then return end
    local ob = Overlay("buffs", buffs, "Buffs - drag")
    local od = debuffs and Overlay("debuffs", debuffs, "Debuffs - drag")
    if on then
        for _, pair in ipairs({ { ob, buffs }, { od, debuffs } }) do
            local o, f = pair[1], pair[2]
            if o and f then
                o:ClearAllPoints()
                o:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
                o:SetSize(math.max(f:GetWidth(), 120) * f:GetScale(), math.max(f:GetHeight(), 32) * f:GetScale())
                o:Show()
            end
        end
        Print("unlocked - drag the blue boxes, then /rbf lock")
    else
        if ob then ob:Hide() end
        if od then od:Hide() end
        Apply()
        Print("locked")
    end
end

-- ---------------------------------------------------------------------------
-- slash
-- ---------------------------------------------------------------------------

local VALID_POINTS = { TOPLEFT = 1, TOP = 1, TOPRIGHT = 1, LEFT = 1, CENTER = 1, RIGHT = 1, BOTTOMLEFT = 1, BOTTOM = 1, BOTTOMRIGHT = 1 }

local function Help()
    Print("/rbf unlock | lock - drag the frames")
    Print("/rbf scale <0.5-2>")
    Print("/rbf buffs <point> <x> <y>   e.g. /rbf buffs TOPRIGHT -10 -40")
    Print("/rbf debuffs <point> <x> <y> | /rbf debuffs follow")
    Print("/rbf reset")
    Print(("now: scale %.2f, buffs %s %d %d, debuffs %s"):format(db.scale, db.buffs.point, db.buffs.x, db.buffs.y,
        db.debuffs.follow and "follow" or ("%s %d %d"):format(db.debuffs.point, db.debuffs.x, db.debuffs.y)))
end

SLASH_RESKINBLIZZARDBUFFFRAME1 = "/rbf"
SlashCmdList.RESKINBLIZZARDBUFFFRAME = function(msg)
    local args = {}
    for w in (msg or ""):gmatch("%S+") do args[#args + 1] = w end
    local sub = (args[1] or ""):lower()
    if sub == "unlock" then
        SetUnlocked(true)
    elseif sub == "lock" then
        SetUnlocked(false)
    elseif sub == "scale" then
        local n = tonumber(args[2])
        if not n or n < 0.5 or n > 2 then return Help() end
        db.scale = n
        Apply()
        Print("scale " .. n)
    elseif sub == "buffs" or sub == "debuffs" then
        if sub == "debuffs" and (args[2] or ""):lower() == "follow" then
            db.debuffs.follow = true
            Apply()
            return Print("debuffs follow the buffs")
        end
        local point = (args[2] or ""):upper()
        local x, y = tonumber(args[3]), tonumber(args[4])
        if not VALID_POINTS[point] or not x or not y then return Help() end
        db[sub].point, db[sub].x, db[sub].y = point, x, y
        if sub == "debuffs" then db.debuffs.follow = false end
        Apply()
        Print(("%s at %s %d %d"):format(sub, point, x, y))
    elseif sub == "reset" then
        wipe(db)
        CopyDefaults(db, DEFAULTS)
        Apply()
        Print("reset to defaults")
    else
        Help()
    end
end

-- ---------------------------------------------------------------------------
-- init
-- ---------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        ReskinBlizzardBuffFrameDB = ReskinBlizzardBuffFrameDB or {}
        db = ReskinBlizzardBuffFrameDB
        CopyDefaults(db, DEFAULTS)
    elseif event == "PLAYER_ENTERING_WORLD" then
        local buffs, debuffs = Frames()
        if not buffs then
            Print("BuffFrame not found on this client; nothing to do")
            return
        end
        HookFrame(buffs)
        HookFrame(debuffs)
        Apply()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then
            pendingApply = false
            Apply()
        end
    end
end)
