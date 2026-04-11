local function GetSecondWindTimerName(bot)
    return bot:UniqueID() .. "secondwind"
end

function LeadBot.PostDeath(bot)
    if not IsValid(bot) or not bot:IsBot() then
        return
    end

    local wasZombieBeforeDeath = bot.LeadBot_WasZombieBeforeDeath
    bot.LeadBot_WasZombieBeforeDeath = nil

    if not wasZombieBeforeDeath then
        return
    end

    if not timer.Exists(GetSecondWindTimerName(bot)) then
        return
    end

    local zombieClass = bot:GetZombieClass()
    if not zombieClass or zombieClass <= 0 then
        return
    end

    -- Second wind should revive the bot in the same class it had before falling.
    bot.LeadBot_PreserveZombieClass = zombieClass
end