-- Cache cvars
local leadbot_cs = GetConVar("leadbot_cs")
local leadbot_knockback = GetConVar("leadbot_knockback")

-- The base ZS gamemode also uses class 1 as the reset/default state for humans.
local DEFAULT_CLASS_ID = 1

local RESET_TO_DEFAULT_CLASSES = {
    [9] = true
}

local ZOMBIE_CLASS_RULES = {
    early = {
        fallback = 1,
        classes = { 1, 5, 6, 7 }
    },
    mid = {
        fallback = 2,
        classes = { 1, 2, 3, 5, 6, 7, 8 }
    },
    late = {
        fallback = 4,
        classes = { 1, 2, 3, 4, 5, 6, 7, 8 },
        weighted = {
            { from = 12, classId = 2 },
            { from = 9, to = 9, classId = 4 }
        }
    }
}

local function GetInfliction()
    local infliction = tonumber(INFLICTION) or 0
    return math.Clamp(infliction, 0, 1)
end

local function GetZombieClassData(classId)
    return ZombieClasses and ZombieClasses[classId] or nil
end

local function CanUseZombieClass(classId)
    local classData = GetZombieClassData(classId)
    return classData ~= nil and GetInfliction() >= (classData.Threshold or 0)
end

local function GetZombieRuleSet()
    local infliction = GetInfliction()

    if infliction <= 0.5 then
        return ZOMBIE_CLASS_RULES.early
    end

    if infliction <= 0.75 then
        return ZOMBIE_CLASS_RULES.mid
    end

    return ZOMBIE_CLASS_RULES.late
end

local function StripHumanWeapons(bot)
    for _, weapon in ipairs(bot:GetWeapons()) do
        local weaponClass = weapon:GetClass()

        if weapons.IsBasedOn(weaponClass, "weapon_zs_base") then
            bot:StripWeapon(weaponClass)
        end
    end
end

local function SetKnockbackEnabled(bot)
    if leadbot_knockback:GetBool() then
        bot:RemoveEFlags(EFL_NO_DAMAGE_FORCES)
    else
        bot:AddEFlags(EFL_NO_DAMAGE_FORCES)
    end
end

local function PickZombieClass(bot)
    local ruleSet = GetZombieRuleSet()
    local currentClass = bot:GetZombieClass()

    -- Keep the original behavior of forcing some special classes back to a safe default.
    if not ruleSet.weighted and RESET_TO_DEFAULT_CLASSES[currentClass] then
        return ruleSet.fallback
    end

    local totalClasses = #ruleSet.classes
    local roll = math.random(1, totalClasses * 2)

    if ruleSet.weighted then
        for _, weightedRule in ipairs(ruleSet.weighted) do
            local maxRoll = weightedRule.to or math.huge

            if roll >= weightedRule.from and roll <= maxRoll then
                if CanUseZombieClass(weightedRule.classId) then
                    return weightedRule.classId
                end

                return ruleSet.fallback
            end
        end

        if RESET_TO_DEFAULT_CLASSES[currentClass] then
            return ruleSet.fallback
        end
    elseif roll > totalClasses then
        return ruleSet.fallback
    end

    local classId = ruleSet.classes[roll]

    if classId and CanUseZombieClass(classId) then
        return classId
    end

    return ruleSet.fallback
end

local function ApplyCounterStrikeZombieHealth(bot)
    timer.Simple(1, function()
        if not IsValid(bot) or bot:Team() ~= TEAM_ZOMBIE then return end

        bot:SetMaxHealth(1000)
        bot:SetHealth(1000)
    end)
end

function LeadBot.Spawn(bot)
    SetKnockbackEnabled(bot)

    local teamId = bot:Team()

    if teamId == TEAM_SURVIVORS then
        -- This is a state reset, not a real survivor class system.
        bot:SetZombieClass(DEFAULT_CLASS_ID)
        return
    end

    if teamId ~= TEAM_ZOMBIE then
        return
    end

    StripHumanWeapons(bot)

    local preservedZombieClass = bot.LeadBot_PreserveZombieClass
    if preservedZombieClass then
        -- Keep special revive classes for a single spawn only.
        bot.LeadBot_PreserveZombieClass = nil
        bot:SetZombieClass(preservedZombieClass)
        return
    end

    if leadbot_cs:GetBool() then
        bot:SetZombieClass(DEFAULT_CLASS_ID)
        ApplyCounterStrikeZombieHealth(bot)
        return
    end

    bot:SetZombieClass(PickZombieClass(bot))
end
