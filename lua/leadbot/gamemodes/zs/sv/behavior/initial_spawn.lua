-- Cache cvars
local leadbot_quota = GetConVar("leadbot_quota")
local leadbot_hordes = GetConVar("leadbot_hordes")
local leadbot_mapchanges = GetConVar("leadbot_mapchanges")

function LeadBot.InitialSpawn(bot)
    if leadbot_quota:GetInt() > 1 and leadbot_hordes:GetInt() < 1 then
        bot:SetMaxHealth(1000000)

        if leadbot_mapchanges:GetInt() >= 1 then 
            local fixedPos = ZSB.Map:GetValue("fixedZombieSpawn")

            if fixedPos then
                bot:SetPos(fixedPos)
            end
        end 
    end
end