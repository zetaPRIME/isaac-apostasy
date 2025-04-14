local util = { }

function util.playerDPS(player, useMultishot)
    local ms = 1
    if useMultishot then ms = util.playerMultishot(player) end
    local fr = 30 / (player.MaxFireDelay + 1)
    return player.Damage * fr * ms
end

function util.playerMultishot() return 1 end -- TODO

return util
