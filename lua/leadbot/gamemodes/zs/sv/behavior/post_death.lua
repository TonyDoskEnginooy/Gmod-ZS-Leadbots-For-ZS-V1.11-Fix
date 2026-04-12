local TORSO_ZOMBIE_CLASS = 9

local function GetSecondWindTimerName(bot)
    return bot:UniqueID() .. "secondwind"
end

function LeadBot.PostDeath(bot)
    if not IsValid(bot) or not bot:IsBot() then
        return
    end

    if not bot.LeadBot_WasZombieBeforeDeath then
        return
    end

    -- Second wind should revive the bot in the same class it had before falling.
    if not timer.Exists(GetSecondWindTimerName(bot)) then
        return
    end

    local zombieClass = bot:GetZombieClass()
    bot.LeadBot_PreserveZombieClass = zombieClass
end