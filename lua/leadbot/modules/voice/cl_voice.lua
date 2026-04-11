local VOICE_ICON = Material("voice/icntlk_pl")
local SHOW_VOICE_ICONS = GetConVar("mp_show_voice_icons")

local meta = FindMetaTable("Player")
local oldVoiceVolume = meta.VoiceVolume
local oldIsSpeaking = meta.IsSpeaking

local function StopBotVoice(ply, token)
    if not IsValid(ply) then return end
    if token ~= nil and ply._LeadBotVoiceToken ~= token then return end
    if not ply.LeadBotIsSpeaking then return end

    ply.LeadBotIsSpeaking = false
    ply.LeadBotVoiceEndTime = 0

    hook.Call("PlayerEndVoice", gmod.GetGamemode(), ply)
end

local function StartBotVoice(ply, duration)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:IsBot() then return end

    ply._LeadBotVoiceToken = (ply._LeadBotVoiceToken or 0) + 1

    local token = ply._LeadBotVoiceToken
    local wasSpeaking = ply.LeadBotIsSpeaking == true

    ply.LeadBotIsSpeaking = true
    ply.LeadBotVoiceEndTime = CurTime() + math.max(duration or 0, 0)

    if not wasSpeaking then
        hook.Call("PlayerStartVoice", gmod.GetGamemode(), ply)
    end

    timer.Simple(math.max(duration or 0, 0.25), function()
        StopBotVoice(ply, token)
    end)
end

net.Receive("botVoiceStart", function()
    local ply = net.ReadEntity()
    local duration = net.ReadFloat()

    StartBotVoice(ply, duration)
end)

hook.Add("PostPlayerDraw", "LeadBot_VoiceIcon", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:IsBot() then return end
    if not ply.LeadBotIsSpeaking then return end
    if not SHOW_VOICE_ICONS or not SHOW_VOICE_ICONS:GetBool() then return end

    local ang = EyeAngles()
    local pos = ply:GetPos() + ply:GetCurrentViewOffset() + Vector(0, 0, 14)

    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, 1)
        surface.SetMaterial(VOICE_ICON)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(-8, -8, 16, 16)
    cam.End3D2D()
end)

function meta:VoiceVolume()
    if not self:IsBot() then
        if oldVoiceVolume then
            return oldVoiceVolume(self)
        end

        return 0
    end

    if self.LeadBotIsSpeaking then
        return 1
    end

    return 0
end

function meta:IsSpeaking()
    if not self:IsBot() then
        if oldIsSpeaking then
            return oldIsSpeaking(self)
        end

        return false
    end

    return self.LeadBotIsSpeaking == true
end
