-- Base player meta functions for LeadBot.
-- There are more overrides and additions being done in the module files.

local player_meta = FindMetaTable("Player")
local oldInfo = player_meta.GetInfo

function player_meta:IsLBot(realbotsonly)
    if realbotsonly == true then
        return self:IsBot()
    else
        return self:IsBot() or LeadBot.AFKBotOverride and self.Botized or false
    end
end

function player_meta:LBGetStrategy()
    if self.LeadBot_Config then
        return self.LeadBot_Config[4]
    else
        return 0
    end
end

function player_meta:LBGetSurvSkill()
    if self.LeadBot_Config then
        return self.LeadBot_Config[5]
    else
        return 0
    end
end

function player_meta:LBGetZomSkill()
    if self.LeadBot_Config then
        return self.LeadBot_Config[6]
    else
        return 0
    end
end

function player_meta:LBGetShootSkill()
    if self.LeadBot_Config then
        return self.LeadBot_Config[7]
    else
        return 0
    end
end

function player_meta:LBGetModel()
    if self.LeadBot_Config then
        return self.LeadBot_Config[1]
    else
        return "kleiner"
    end
end

function player_meta:LBGetColor(weapon)
    if self.LeadBot_Config then
        if weapon == true then
            return self.LeadBot_Config[3]
        else
            return self.LeadBot_Config[2]
        end
    else
        return Vector(0, 0, 0)
    end
end

function player_meta:GetInfo(convar)
    if self:IsBot() and self:IsLBot() then
        if convar == "cl_playermodel" then
            return self:LBGetModel() --self.LeadBot_Config[1]
        elseif convar == "cl_playercolor" then
            return self:LBGetColor() --self.LeadBot_Config[2]
        elseif convar == "cl_weaponcolor" then
            return self:LBGetColor(true) --self.LeadBot_Config[3]
        else
            return ""
        end
    else
        return oldInfo(self, convar)
    end
end

function player_meta:GetController()
    if self:IsLBot() then
        local controller = self.ControllerBot

        if not IsValid(controller) then
            controller = ents.Create("leadbot_navigator")
            controller:Spawn()
            controller:SetOwner()
            self.ControllerBot = controller
        end
    
        return controller
    end
end