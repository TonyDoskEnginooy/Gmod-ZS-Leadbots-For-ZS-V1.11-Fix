surface.CreateFont("LeadBot_AFK", {
    font = "Roboto",
    size = 34,
    weight = 500
})

surface.CreateFont("LeadBot_AFK2", {
    font = "Roboto",
    size = 30,
    weight = 500
})

local TEXT_COLOR = Color(255, 255, 255, 235)
local OUTLINE_COLOR = Color(0, 0, 0, 255)

local TP_GAMEMODES = {
    sandbox = true,
    darkestdays = true
}

local NO_AFK_CAMERA = {
    assassins = true,
    cavefight = true
}

local tp = false
local lastTP = false
local newAngle = Angle(0, 0, 0)
local scroll = 0
local lastSend = 0
local ang
local lerp = 0
local wasAFK = false

local function GetLocalPlayerSafe()
    local ply = LocalPlayer()

    if not IsValid(ply) then
        return nil
    end

    return ply
end

local function IsLeadBotAFK(ply)
    return IsValid(ply) and ply:GetNWBool("LeadBot_AFK", false)
end

local function ResetAFKCameraState(baseAngle)
    tp = false
    lastTP = false
    scroll = 0
    lerp = 0

    if baseAngle then
        ang = Angle(baseAngle.p, baseAngle.y, 0)
        newAngle = Angle(baseAngle.p, baseAngle.y, 0)
    else
        ang = nil
        newAngle = Angle(0, 0, 0)
    end
end

local function SyncAFKState(isAFK, baseAngle)
    if isAFK and not wasAFK then
        ResetAFKCameraState(baseAngle)
    elseif not isAFK and wasAFK then
        ResetAFKCameraState(baseAngle)
    end

    wasAFK = isAFK
end

hook.Add("HUDPaint", "LeadBot_AFK_HUD", function()
    local ply = GetLocalPlayerSafe()

    if not IsLeadBotAFK(ply) then
        return
    end

    draw.SimpleTextOutlined(
        "You are AFK.",
        "LeadBot_AFK",
        ScrW() / 2,
        ScrH() / 2.85,
        TEXT_COLOR,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_BOTTOM,
        1,
        OUTLINE_COLOR
    )

    draw.SimpleTextOutlined(
        "Press any key to rejoin.",
        "LeadBot_AFK2",
        ScrW() / 2,
        ScrH() / 2.675,
        TEXT_COLOR,
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_BOTTOM,
        1,
        OUTLINE_COLOR
    )
end)

hook.Add("CreateMove", "LeadBot_AFK_CreateMove", function(cmd)
    local ply = GetLocalPlayerSafe()

    if not ply then
        return
    end

    local isAFK = IsLeadBotAFK(ply)
    SyncAFKState(isAFK, ply:EyeAngles())

    if not isAFK then
        return
    end

    if lastSend < CurTime()
        and cmd:GetButtons() ~= 0
        and not cmd:KeyDown(IN_ATTACK)
        and not cmd:KeyDown(IN_WALK)
        and not cmd:KeyDown(IN_SCORE) then
        net.Start("LeadBot_AFK_Off")
        net.SendToServer()
        lastSend = CurTime() + 0.1
    end

    local activeGamemode = engine.ActiveGamemode()

    if cmd:KeyDown(IN_ATTACK) and TP_GAMEMODES[activeGamemode] then
        if not lastTP then
            tp = not tp
            lastTP = true
        end
    else
        lastTP = false
    end

    if input.WasMousePressed(MOUSE_WHEEL_DOWN) then
        scroll = math.Clamp(scroll + 4, -35, 45)
    elseif input.WasMousePressed(MOUSE_WHEEL_UP) then
        scroll = math.Clamp(scroll - 4, -35, 45)
    end

    if tp then
        local pitch = GetConVar("m_pitch"):GetFloat()
        local yaw = GetConVar("m_yaw"):GetFloat()

        newAngle.pitch = math.Clamp(newAngle.pitch + cmd:GetMouseY() * pitch, -90, 90)
        newAngle.yaw = newAngle.yaw - cmd:GetMouseX() * yaw
    end

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetImpulse(0)
    cmd:SetMouseX(0)
    cmd:SetMouseY(0)
end)

hook.Add("InputMouseApply", "LeadBot_AFK_InputMouseApply", function(cmd)
    local ply = GetLocalPlayerSafe()

    if not IsLeadBotAFK(ply) then
        return
    end

    cmd:SetMouseX(0)
    cmd:SetMouseY(0)

    return true
end)

hook.Add("HUDShouldDraw", "LeadBot_AFK_HUDShouldDraw", function(hud)
    if hud ~= "CHudWeaponSelection" then
        return
    end

    local ply = GetLocalPlayerSafe()

    if IsLeadBotAFK(ply) then
        return false
    end
end)

hook.Add("CalcView", "LeadBot_AFK_CalcView", function(ply, origin, angles)
    local isAFK = IsLeadBotAFK(ply)
    SyncAFKState(isAFK, angles)

    if ply:ShouldDrawLocalPlayer() or not isAFK or NO_AFK_CAMERA[engine.ActiveGamemode()] then
        return
    end

    local view = {
        origin = origin,
        angles = angles
    }

    if tp or lerp ~= 0 then
        if tp then
            lerp = math.Clamp(lerp + FrameTime() * 5, 0, 1)
        else
            lerp = math.Clamp(lerp - FrameTime() * 5, 0, 1)
        end

        local pos = ply:EyePos()
        local trace = util.TraceHull({
            start = pos + newAngle:Forward() * Lerp(lerp, 0, -5),
            endpos = pos + newAngle:Forward() * Lerp(lerp, 0, -75 - scroll),
            filter = ply,
            mins = Vector(-8, -8, -8),
            maxs = Vector(8, 8, 8)
        })

        view.origin = trace.HitPos
        view.angles = newAngle
        view.drawviewer = true
    else
        if not ang then
            ang = Angle(angles.p, angles.y, 0)
        end

        ang = LerpAngle(FrameTime() * 16, ang, angles)
        ang = Angle(ang.p, ang.y, 0)
        newAngle = Angle(ang.p, ang.y, 0)

        view.angles = newAngle
    end

    return view
end)

hook.Add("CalcViewModelView", "LeadBot_AFK_CalcViewModelView", function(wep, vm, oldpos, oldang, newpos, newang)
    local ply = GetLocalPlayerSafe()

    if not ply then
        return
    end

    if ply:ShouldDrawLocalPlayer() or not IsLeadBotAFK(ply) or NO_AFK_CAMERA[engine.ActiveGamemode()] then
        return
    end

    if wep.GetViewModelPosition then
        newpos, newang = wep:GetViewModelPosition(newpos, newang)
    end

    if wep.CalcViewModelView then
        newpos, newang = wep:CalcViewModelView(vm, oldpos, oldang, newpos, newang)
    end

    return newpos, newang
end)