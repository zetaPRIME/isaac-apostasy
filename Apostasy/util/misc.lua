local util = { }

function util.playerDPS(player, useMultishot)
    local ms = 1
    if useMultishot then ms = util.playerMultishot(player) end
    local fr = 30 / (player.MaxFireDelay + 1)
    return player.Damage * fr * ms
end

do
    local _baseMs
    
    if REPENTOGON then
        _baseMs = function(player)
            local wt = WeaponType.WEAPON_TEARS
            return player:GetMultiShotParams(wt):GetNumTears()
        end
    else
        _baseMs = function() return 1 end -- TODO: non dummy
    end
    
    function util.playerMultishot(player)
        local ms = _baseMs(player)
        if player:HasWeaponType(WeaponType.WEAPON_MONSTROS_LUNGS) then
            ms = 14 + math.floor((ms-1) * 2.4) -- lung calc is done afterwards
        end
        return ms
    end
end


return util
