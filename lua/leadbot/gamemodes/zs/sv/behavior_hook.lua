hook.Add("InitPostEntity", "ZS_LeadBot_InitPostEntity", function()
    ZSB.InitPostEntity()
end)

hook.Add("PlayerInitialSpawn", "ZS_LeadBot_PlayerInitialSpawn", function(ply)
    if ply:IsLBot() then
        LeadBot.InitialSpawn(ply)
    end
end)

hook.Add("PlayerDisconnected", "ZS_LeadBot_Disconnect", function(ply)
    if ply:IsLBot() then
        LeadBot.Disconnected(ply)
    end
end)

hook.Add("SetupMove", "ZS_LeadBot_SetupMove", function(ply, mv, cmd)
    if ply:IsLBot() then
        LeadBot.SetupMove(ply, cmd, mv)
    end
end)

hook.Add("StartCommand", "ZS_LeadBot_StartCommand", function(ply, cmd)
    if ply:IsLBot() then
        LeadBot.StartCommand(ply, cmd)
    end
end)

hook.Add("PostPlayerDeath", "ZS_LeadBot_PostPlayerDeath", function(ply)
    if ply:IsLBot() then
        LeadBot.PostDeath(ply)
    end
end)

hook.Add("Tick", "LeadBot_Tick", function()    
    LeadBot.Tick()
end)

hook.Add("PlayerSpawn", "ZS_LeadBot_PlayerSpawn", function(ply)    
    if ply:IsLBot() then
        LeadBot.Spawn(ply)
    end
end) 

hook.Add("EntityTakeDamage", "ZS_LeadBot_EntityTakeDamage", function(victim, dmgInfo)
    if victim:IsPlayer() and victim:IsLBot() then
        local aggressor = dmgInfo:GetAttacker()
        local hp = victim:Health()

        LeadBot.TakeDamage(aggressor, victim, hp, dmgInfo)
    end
end)

hook.Add("PlayerDeath", "ZS_LeadBot_PlayerDeath", function(victim, inflictor, attacker)
    if victim:IsLBot() then
        LeadBot.Death(attacker, victim)
    end
end)

hook.Add("EntityFireBullets", "ZS_LeadBot_EntityFireBullets", function(ent, data)
    if ent:IsLBot() then
        local weapon = ent:GetActiveWeapon()

        if IsValid(weapon) then
            LeadBot.FireBullets(ent, weapon, data)
        end
    end
end)