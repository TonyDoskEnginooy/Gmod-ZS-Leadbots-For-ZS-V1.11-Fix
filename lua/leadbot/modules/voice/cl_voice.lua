local VOICE_ICON = Material("voice/icntlk_pl")
local SHOW_VOICE_ICONS = GetConVar("mp_show_voice_icons")

local meta = FindMetaTable("Player")
local oldVoiceVolume = meta.VoiceVolume
local oldIsSpeaking = meta.IsSpeaking

local function StopBotVoice(ply, token)
    if not IsValid(ply) then return end
    if token ~= nil and ply._LeadBotVoiceToken ~= token then return end

    local station = ply.ChattingS
    ply.ChattingS = nil

    hook.Call("PlayerEndVoice", gmod.GetGamemode(), ply)

    if IsValid(station) then
        station:Stop()
    end
end

local function StartBotVoice(ply, soundPath)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:IsBot() then return end
    if IsValid(ply.ChattingS) and ply.ChattingS:GetState() == GMOD_CHANNEL_PLAYING then return end
    if not isstring(soundPath) or soundPath == "" then return end

    ply._LeadBotVoiceToken = (ply._LeadBotVoiceToken or 0) + 1
    local token = ply._LeadBotVoiceToken

    sound.PlayFile("sound/" .. soundPath, "mono", function(station, errCode, errName)
        if not IsValid(ply) then
            if IsValid(station) then
                station:Stop()
            end
            return
        end

        if token ~= ply._LeadBotVoiceToken then
            if IsValid(station) then
                station:Stop()
            end
            return
        end

        if not IsValid(station) then
            ply.ChattingS = nil
            print(string.format("[LeadBot Voice] Failed to play '%s' for %s (error %s: %s)", soundPath, tostring(ply), tostring(errCode), tostring(errName)))
            return
        end

        ply.ChattingS = station

        station:SetPlaybackRate(math.random(95, 105) * 0.01)
        station:Play()

        hook.Call("PlayerStartVoice", gmod.GetGamemode(), ply)

        local duration = station:GetLength()

        if not isnumber(duration) or duration <= 0 then
            duration = SoundDuration(soundPath) or 0
        end

        if duration > 0 then
            timer.Simple(duration, function()
                StopBotVoice(ply, token)
            end)
        end
    end)
end

net.Receive("botVoiceStart", function()
    local ply = net.ReadEntity()
    local soundPath = net.ReadString()

    StartBotVoice(ply, soundPath)
end)

hook.Add("PostPlayerDraw", "LeadBot_VoiceIcon", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:IsBot() then return end
    if not IsValid(ply.ChattingS) then return end
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

    if IsValid(self.ChattingS) then
        return (self.ChattingS:GetLevel() or 0) * 0.6
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

    return IsValid(self.ChattingS)
end