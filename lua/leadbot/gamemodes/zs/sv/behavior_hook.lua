local function CallLeadBotPlayerHook(ply, fn, ...)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:IsLBot() then
        return
    end

    if type(fn) ~= "function" then
        return
    end

    return fn(ply, ...)
end

hook.Add("InitPostEntity", "ZS_LeadBot_InitPostEntity", function()
    if type(ZSB) == "table" and type(ZSB.InitPostEntity) == "function" then
        return ZSB.InitPostEntity()
    end
end)

hook.Add("PlayerInitialSpawn", "ZS_LeadBot_PlayerInitialSpawn", function(ply)
    return CallLeadBotPlayerHook(ply, LeadBot.InitialSpawn)
end)

hook.Add("PlayerDisconnected", "ZS_LeadBot_Disconnect", function(ply)
    return CallLeadBotPlayerHook(ply, LeadBot.Disconnected)
end)

hook.Add("SetupMove", "ZS_LeadBot_SetupMove", function(ply, mv, cmd)
    return CallLeadBotPlayerHook(ply, LeadBot.SetupMove, cmd, mv)
end)

hook.Add("StartCommand", "ZS_LeadBot_StartCommand", function(ply, cmd)
    return CallLeadBotPlayerHook(ply, LeadBot.StartCommand, cmd)
end)

hook.Add("PostPlayerDeath", "ZS_LeadBot_PostPlayerDeath", function(ply)
    return CallLeadBotPlayerHook(ply, LeadBot.PostDeath)
end)

hook.Add("Tick", "ZS_LeadBot_Tick", function()
    if type(LeadBot) == "table" and type(LeadBot.Tick) == "function" then
        return LeadBot.Tick()
    end
end)

hook.Add("PlayerSpawn", "ZS_LeadBot_PlayerSpawn", function(ply)
    return CallLeadBotPlayerHook(ply, LeadBot.Spawn)
end)

hook.Add("EntityTakeDamage", "ZS_LeadBot_EntityTakeDamage", function(victim, dmgInfo)
    if not IsValid(victim) or not victim:IsPlayer() or not victim:IsLBot() then
        return
    end

    return LeadBot.TakeDamage(dmgInfo:GetAttacker(), victim, victim:Health(), dmgInfo)
end)

hook.Add("PlayerDeath", "ZS_LeadBot_PlayerDeath", function(victim, inflictor, attacker)
    return CallLeadBotPlayerHook(victim, LeadBot.Death, attacker)
end)

hook.Add("EntityFireBullets", "ZS_LeadBot_EntityFireBullets", function(ent, data)
    if not IsValid(ent) or not ent:IsLBot() then
        return
    end

    local weapon = ent:GetActiveWeapon()
    if not IsValid(weapon) then
        return
    end

    return LeadBot.FireBullets(ent, weapon, data)
end)

hook.Add("PostEntityTakeDamage", "ZS_LeadBot_KnifeBloodFeedback", function(victim, dmgInfo, wasDamageTaken)
    if not wasDamageTaken or dmgInfo:GetDamage() <= 0 then
        return
    end

    LeadBot.PostEntityTakeDamage(victim, dmgInfo, wasDamageTaken)
end)