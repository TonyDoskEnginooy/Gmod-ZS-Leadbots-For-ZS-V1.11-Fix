local leadbot_hinfammo = GetConVar("leadbot_hinfammo")

local function KeepInfiniteAmmoForSurvivorBots(bot, weapon)
    if not leadbot_hinfammo:GetBool() then return end
    if bot:Team() ~= TEAM_SURVIVORS then return end

    local maxClip1 = weapon:GetMaxClip1()
    local maxClip2 = weapon:GetMaxClip2()
    local primaryAmmoType = weapon:GetPrimaryAmmoType()
    local secondaryAmmoType = weapon:GetSecondaryAmmoType()

    if maxClip1 > 0 then
        weapon:SetClip1(maxClip1)

        if primaryAmmoType ~= -1 then
            bot:SetAmmo(maxClip1, primaryAmmoType)
        end
    end

    if maxClip2 > 0 then
        weapon:SetClip2(maxClip2)

        if secondaryAmmoType ~= -1 and secondaryAmmoType ~= primaryAmmoType then
            bot:SetAmmo(maxClip2, secondaryAmmoType)
        end
    end
end

function LeadBot.FireBullets(bot, weapon, data)
    KeepInfiniteAmmoForSurvivorBots(bot, weapon)
end