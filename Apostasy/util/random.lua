local random = { }

local function rawPercentRoll()
    return (Random() % 10000) * .01
end
local function rawFloatRoll()
    return (Random() % 10000) / 10000
end

function random.rollPercent(chance, luck)
    if type(luck) == "userdata" then luck = luck.Luck end
    
    local roll = rawPercentRoll()
    -- luck weights for advantage/disadvantage in range -10 .. 10
    if luck and math.abs(luck*10) > rawPercentRoll() then
        local roll2 = rawPercentRoll()
        if luck > 0 then roll = math.min(roll, roll2)
        else roll = math.max(roll, roll2) end
    end
    
    if not chance then return roll end
    return chance > roll
end

return random
