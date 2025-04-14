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
        -- TODO: figure out conjoined??
        -- we could take keeper/keeperb into account but we're not using this in a place where that could be relevant yet
        -- (maybe once active items)
        
        _baseMs = function(player)
            local ms = 1
            
            local tt = player:GetCollectibleNum(CollectibleType.COLLECTIBLE_20_20)
            local eye = player:GetCollectibleNum(CollectibleType.COLLECTIBLE_INNER_EYE)
            local spider = player:GetCollectibleNum(CollectibleType.COLLECTIBLE_MUTANT_SPIDER)
            local wiz = player:GetCollectibleNum(CollectibleType.COLLECTIBLE_THE_WIZ)
            
            -- single-copy behaviors
            if eye > 0 and spider > 0 then
                ms = 5
            elseif spider > 0 then
                ms = 4
                if wiz > 0 then ms = ms + 1 end -- first wiz adds two if you don't have eye
            elseif eye > 0 then
                ms = 3
            elseif tt > 0 then
                -- single copy of 20/20 doesn't affect inner eye *or* mutant spider, alone or together
                ms = 2
                if wiz > 0 then ms = ms + 1 end -- first wiz adds two
            end
            
            ms = ms -- account for additional copies
                + math.max(0, wiz) -- ...and also the first copy of Wiz
                + math.max(0, tt-1)
                + math.max(0, eye-1)
                + math.max(0, spider-1) * 2
            
            return math.min(ms, 16)
        end
    end
    
    -- monstro's lung effect is common to both routes
    function util.playerMultishot(player)
        local ms = _baseMs(player)
        if player:HasWeaponType(WeaponType.WEAPON_MONSTROS_LUNGS) then
            ms = 14 + math.floor((ms-1) * 2.4) -- lung calc is done afterwards
        end
        return ms
    end
end


return util
