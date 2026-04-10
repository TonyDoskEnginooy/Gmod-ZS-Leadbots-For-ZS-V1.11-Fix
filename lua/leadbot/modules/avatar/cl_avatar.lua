local meta = FindMetaTable("Panel")
local oldSetPlayer = meta.SetPlayer

local disabledGamemodes = {
    assassins = true
}

local deathSequences = {
    "death_01",
    "death_02",
    "death_03",
    "death_04"
}

local whiteColor = Color(255, 255, 255)

local function ShouldUseLeadBotAvatar(ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        return false
    end

    if disabledGamemodes[engine.ActiveGamemode()] then
        return false
    end

    if not ply:IsBot() then
        return false
    end

    local avatarModel = ply:GetNWString("LeadBot_AvatarModel", "")
    return avatarModel ~= "" and avatarModel ~= "none"
end

local function ClearLeadBotAvatar(panel)
    if IsValid(panel.LeadBotBackground) then
        panel.LeadBotBackground:Remove()
    end

    if IsValid(panel.LeadBotModelPanel) then
        panel.LeadBotModelPanel:Remove()
    end

    panel.LeadBotBackground = nil
    panel.LeadBotModelPanel = nil
end

local function SetupAvatarCamera(modelPanel, ent, sequenceName)
    local attachmentId = ent:LookupAttachment("eyes")
    if attachmentId <= 0 then
        return
    end

    local attachment = ent:GetAttachment(attachmentId)
    if not attachment then
        return
    end

    if sequenceName == "death_05" then
        modelPanel:SetFOV(27)
        modelPanel:SetCamPos(attachment.Pos + attachment.Ang:Forward() * 36)
        modelPanel:SetLookAt(attachment.Pos - Vector(0, 0, 3))
    else
        modelPanel:SetFOV(23)
        modelPanel:SetCamPos(attachment.Pos + attachment.Ang:Forward() * 36 + attachment.Ang:Up() * 2)
        modelPanel:SetLookAt(attachment.Pos - Vector(0, 0, 1))
    end
end

function meta:SetPlayer(ply, size)
    ClearLeadBotAvatar(self)

    if not ShouldUseLeadBotAvatar(ply) then
        return oldSetPlayer(self, ply, size)
    end

    oldSetPlayer(self, NULL, size)

    local background = vgui.Create("DPanel", self)
    background:Dock(FILL)
    background:SetMouseInputEnabled(false)

    function background:Paint(w, h)
        draw.RoundedBox(0, 0, 0, w, h, whiteColor)
    end

    self.LeadBotBackground = background

    local modelPanel = vgui.Create("DModelPanel", self)
    modelPanel:Dock(FILL)
    modelPanel:SetModel("models/player.mdl")
    modelPanel:SetMouseInputEnabled(false)
    modelPanel.Player = ply
    modelPanel.SequenceName = table.Random(deathSequences)
    modelPanel.SequenceCycle = math.Rand(
        0.025,
        (modelPanel.SequenceName == "death_04" and 0.06)
        or (modelPanel.SequenceName == "death_01" and 0.3)
        or 0.1
    )

    function modelPanel:LayoutEntity(ent)
        local player = self.Player
        if not IsValid(player) or not player:IsPlayer() or not IsValid(ent) then
            return
        end

        local avatarModel = player:GetNWString("LeadBot_AvatarModel", player:GetModel())
        if avatarModel == "" or avatarModel == "none" then
            avatarModel = player:GetModel()
        end

        if self.ModelCache ~= avatarModel then
            self.ModelCache = avatarModel
            self:SetModel(avatarModel)

            ent = self:GetEntity()
            if not IsValid(ent) then
                return
            end

            ent:SetRenderMode(RENDERMODE_TRANSALPHA)
            ent:SetLOD(0)

            ent.Player = player
            function ent:GetPlayerColor()
                if not IsValid(self.Player) then
                    return Vector(1, 1, 1)
                end

                return self.Player:GetNWVector("LeadBot_AvatarColor", self.Player:GetPlayerColor())
            end

            local sequenceId = ent:LookupSequence(self.SequenceName or "")
            if sequenceId < 0 then
                sequenceId = ent:LookupSequence("menu_walk")
            end

            if sequenceId >= 0 then
                ent:SetSequence(sequenceId)
                ent:SetCycle(self.SequenceCycle)
            end

            SetupAvatarCamera(self, ent, self.SequenceName)
        end

        local alpha = 255
        local parent = self:GetParent()
        local container = IsValid(parent) and parent:GetParent() or nil

        if IsValid(container) then
            alpha = container:GetAlpha()
        end

        if not self.RenderColor or self.RenderColor.a ~= alpha then
            self.RenderColor = Color(255, 255, 255, alpha)
        end

        ent:SetColor(self.RenderColor)
    end

    self.LeadBotModelPanel = modelPanel
end