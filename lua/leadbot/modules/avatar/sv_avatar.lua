local oldAddBot = LeadBot.AddBotOverride

function LeadBot.AddBotOverride(bot)
    if isfunction(oldAddBot) then
        oldAddBot(bot)
    end

    timer.Simple(0, function()
        if not IsValid(bot) then
            return
        end

        local avatarModel = bot:GetModel()

        if bot.LBGetModel then
            local translatedModel = player_manager.TranslatePlayerModel(bot:LBGetModel())
            if isstring(translatedModel) and translatedModel ~= "" then
                avatarModel = translatedModel
            end
        end

        local avatarColor = Vector(1, 1, 1)
        if bot.LBGetColor then
            avatarColor = bot:LBGetColor()
        end

        bot:SetNWString("LeadBot_AvatarModel", avatarModel)
        bot:SetNWVector("LeadBot_AvatarColor", avatarColor)
    end)
end