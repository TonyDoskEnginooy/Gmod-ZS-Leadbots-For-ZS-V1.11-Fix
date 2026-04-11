ZSB = ZSB or {}
ZSB.StartCommand = ZSB.StartCommand or {}

local SC = ZSB.StartCommand

if SC._MapInteractionsLoaded then
    return
end

SC._MapInteractionsLoaded = true

function SC.BreakRotatingDoor(bot, doors)
    if not SC.HasEntries(doors) then return end

    local mapName = game.GetMap()
    if mapName ~= "zs_jail_v1" and mapName ~= "zs_placid" then return end

    local door = doors[math.random(1, #doors)]
    if IsValid(door) and door:GetClass() == "prop_door_rotating" then
        door:Fire("Break", bot, 0)
    end
end

function SC.ToggleMovingBrush(bot, movingBrushes)
    if not SC.HasEntries(movingBrushes) then return end

    local movingBrush = movingBrushes[math.random(1, #movingBrushes)]
    if not IsValid(movingBrush) then return end

    if movingBrush:GetName() ~= "BunkerDoor" then
        movingBrush:Fire("Open", bot, 0)
    else
        movingBrush:Fire("Close", bot, 0)
    end
end

function SC.BreakBreakableSurface(surfaces)
    if not SC.HasEntries(surfaces) then return end

    local surface = surfaces[math.random(1, #surfaces)]
    if IsValid(surface) then
        surface:Fire("Break")
    end
end
