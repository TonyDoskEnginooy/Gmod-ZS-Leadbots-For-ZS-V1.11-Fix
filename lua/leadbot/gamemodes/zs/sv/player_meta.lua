local player_meta = FindMetaTable("Player")
local oldGetInfo = player_meta.GetInfo

local DEFAULT_COLOR = Vector(0, 0, 0)

local function GetConfigValue(ply, key, defaultValue)
    local cfg = ply.LBConfig
    if not cfg then
        return defaultValue
    end

    local value = cfg[key]
    if value == nil then
        return defaultValue
    end

    return value
end

function player_meta:IsLBot(realBotsOnly)
    if realBotsOnly then
        return self:IsBot()
    end

    return self:IsBot() or (LeadBot and LeadBot.AFKBotOverride and self.Botized) or false
end

function player_meta:LBGetStrategy()
    return GetConfigValue(self, "strategy", 0)
end

function player_meta:LBGetsurvSkill()
    return GetConfigValue(self, "survSkill", 0)
end

function player_meta:LBGetzomSkill()
    return GetConfigValue(self, "zomSkill", 0)
end

function player_meta:LBGetshootSkill()
    return GetConfigValue(self, "shootSkill", 0)
end

function player_meta:LBGetModel()
    return GetConfigValue(self, "model", "kleiner")
end

function player_meta:LBGetColor(isweaponColor)
    if isweaponColor then
        return GetConfigValue(self, "weaponColor", DEFAULT_COLOR)
    end

    return GetConfigValue(self, "color", DEFAULT_COLOR)
end

function player_meta:GetInfo(convar)
    if self:IsBot() or self:IsLBot() then
        if convar == "cl_playermodel" then
            return self:LBGetModel()
        elseif convar == "cl_playercolor" then
            return self:LBGetColor()
        elseif convar == "cl_weaponColor" then
            return self:LBGetColor(true)
        else
            return ""
        end
    end

    return oldGetInfo(self, convar)
end

function player_meta:GetController()
    if not self:IsLBot() then
        return nil
    end

    local controller = self.ControllerBot
    if IsValid(controller) then
        return controller
    end

    controller = ents.Create("leadbot_navigator")
    if not IsValid(controller) then
        return nil
    end

    controller:Spawn()
    self.ControllerBot = controller

    return controller
end