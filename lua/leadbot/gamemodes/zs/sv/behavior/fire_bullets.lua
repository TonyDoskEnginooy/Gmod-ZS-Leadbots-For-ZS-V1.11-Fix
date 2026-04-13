local leadbot_hinfammo = GetConVar("leadbot_hinfammo")

local function ScaleBulletSpread(spread, scale)
    if not spread then
        return nil
    end

    return Vector(spread.x * scale, spread.y * scale, spread.z * scale)
end

local function GetBotSpreadScale(bot, weapon, targetPos)
    local shootSkill = math.max(bot:LBGetshootSkill(), 1)
    local normalizedSkill = math.Clamp((shootSkill - 1) / 7, 0, 1)

    -- Higher base spread and a smaller reward from skill.
    local scale = 1.28 - normalizedSkill * 0.18

    if bot:LBGetsurvSkill() == 1 then
        -- Keep better survivors slightly tighter, but not laser-accurate.
        scale = scale * 0.96
    end

    if targetPos then
        local distanceSqr = bot:GetShootPos():DistToSqr(targetPos)

        if distanceSqr <= 110 * 110 then
            scale = scale * 0.72
        elseif distanceSqr <= 220 * 220 then
            scale = scale * 0.84
        elseif distanceSqr <= 420 * 420 then
            scale = scale * 0.94
        end
    end

    local weaponClass = IsValid(weapon) and weapon:GetClass() or ""

    if weaponClass == "weapon_zs_sweepershotgun" then
        scale = math.max(scale, 0.82)
    elseif weaponClass == "weapon_zs_crossbow" then
        scale = math.max(scale, 0.30)
    else
        scale = math.max(scale, 0.28)
    end

    return scale
end

local function KeepInfiniteAmmoForSurvivors(bot, weapon)
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
    --KeepInfiniteAmmoForSurvivors(bot, weapon)

    if bot:Team() ~= TEAM_SURVIVORS then
        return
    end

    local controller = bot:GetController()
    if not IsValid(controller) or not IsValid(controller.Target) then
        return
    end

    local targetPos = ZSB.Util:GetCombatAimPoint(bot, controller.Target)
    if not targetPos then
        return
    end

    local bulletStart = data.Src or bot:GetShootPos()
    local bulletDir = (targetPos - bulletStart)

    if bulletDir:LengthSqr() <= 0.0001 then
        return
    end

    bulletDir:Normalize()

    local spreadScale = GetBotSpreadScale(bot, weapon, targetPos)

    data.Dir = bulletDir

    if data.Spread then
        data.Spread = ScaleBulletSpread(data.Spread, spreadScale)
    end

    return true
end