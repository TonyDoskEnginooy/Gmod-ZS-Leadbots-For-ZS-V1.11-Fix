ZSB = ZSB or {}
ZSB.SetupMove = ZSB.SetupMove or {}

local SM = ZSB.SetupMove

function SM.DebugBot(bot)
    if not ZSB.DEBUG then return end

    local mins, maxs = bot:GetHull()

    debugoverlay.Text(bot:EyePos(), bot:Nick(), 0.03, false)
    debugoverlay.Box(bot:GetPos(), mins, maxs, 0.03, Color(255, 255, 255, 0))
end

function SM.DebugPath(controller)
    if not ZSB.DEBUG then return end

    controller.Path:Draw()
end
