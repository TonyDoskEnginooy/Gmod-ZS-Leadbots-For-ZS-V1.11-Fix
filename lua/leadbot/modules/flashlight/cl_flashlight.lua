net.Receive("leadbot_Flashlight_Request", function()
    local botCount = net.ReadUInt(8)
    if botCount == 0 then return end

    local bots = {}

    for i = 1, botCount do
        bots[i] = net.ReadEntity()
    end

    net.Start("leadbot_Flashlight_Report")
        net.WriteUInt(#bots, 8)
        for _, bot in ipairs(bots) do
            local lightColor = vector_origin

            if IsValid(bot) and bot:IsPlayer() then
                lightColor = render.GetLightColor(bot:EyePos())
            end

            net.WriteEntity(bot)
            net.WriteVector(lightColor)
        end
    net.SendToServer()
end)