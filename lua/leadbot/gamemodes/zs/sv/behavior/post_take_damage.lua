local function IsKnifeDamageFromSurvivorBot(victim, attacker)
    if not IsValid(victim) or not victim:IsPlayer() or victim:Team() ~= TEAM_ZOMBIE then
        return false
    end

    if not IsValid(attacker) or not attacker:IsPlayer() then
        return false
    end

    if attacker:Team() ~= TEAM_SURVIVORS then
        return false
    end

    local weapon = attacker:GetActiveWeapon()

    return IsValid(weapon) and weapon:GetClass() == "weapon_zs_swissarmyknife"
end

local function GetDamageEffectOrigin(victim, dmgInfo)
    local hitPos = dmgInfo:GetDamagePosition()

    if hitPos and hitPos:LengthSqr() > 0 then
        return hitPos
    end

    return victim:WorldSpaceCenter()
end

local function GetDamageEffectNormal(victim, attacker, dmgInfo)
    local force = dmgInfo:GetDamageForce()

    if force and force:LengthSqr() > 0 then
        return force:GetNormalized()
    end

    if IsValid(attacker) then
        return (victim:WorldSpaceCenter() - attacker:WorldSpaceCenter()):GetNormalized()
    end

    return Vector(0, 0, 1)
end

local function SpawnZombieKnifeBlood(victim, attacker, dmgInfo)
    local effectData = EffectData()
    effectData:SetOrigin(GetDamageEffectOrigin(victim, dmgInfo))
    effectData:SetNormal(GetDamageEffectNormal(victim, attacker, dmgInfo))
    effectData:SetColor(BLOOD_COLOR_RED)
    effectData:SetScale(15)

    util.Effect("BloodImpact", effectData, true, true)
end


function LeadBot.PostEntityTakeDamage(victim, dmgInfo, wasDamageTaken)
    local attacker = dmgInfo:GetAttacker()

    if IsKnifeDamageFromSurvivorBot(victim, attacker) then
        SpawnZombieKnifeBlood(victim, attacker, dmgInfo)
    end
end