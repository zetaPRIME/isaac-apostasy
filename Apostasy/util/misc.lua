local util = { }

function util.playerDPS(player, useMultishot)
    local ms = 1
    if useMultishot then ms = util.playerMultishot(player) end
    local fr = 30 / (player.MaxFireDelay + 1)
    return player.Damage * fr * ms
end

if REPENTOGON then
    function util.playerMultishot(player)
        return player:GetMultiShotParams(WeaponType.WEAPON_TEARS):GetNumTears()
    end
else
    function util.playerMultishot() return 1 end -- TODO: non dummy
end

return util
