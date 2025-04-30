local Apostasy = _ENV["::Apostasy"]

local rand = Apostasy:require "util.random"

local sfx = SFXManager()



local skullmask = Apostasy:RegisterTrinket("Skull Mask")
skullmask:AddDescription("↑ +0.15 Speed#20% chance to avoid damage while moving quickly#{{Blank}} (10% chance per Luck to roll with advantage)")

function skullmask:OnEvaluateCache(player, cacheFlag)
    if cacheFlag == CacheFlag.CACHE_SPEED then
        player.MoveSpeed = player.MoveSpeed + 0.15
    end
end

function skullmask:OnTakeDamage(e, amount, flags, source, inv)
    local player = e:ToPlayer()
    if flags & DamageFlag.DAMAGE_FAKE > 0 then return end
    
    if player.Velocity:Length() >= 3.5 then
        if rand.rollPercent(20, player) then
            sfx:Play(SoundEffect.SOUND_SWORD_SPIN, 1, 0, false, 1.25)
            sfx:Play(SoundEffect.SOUND_ISAAC_HURT_GRUNT, 0, 3) -- block hurt sound
            player:TakeDamage(1, DamageFlag.DAMAGE_FAKE, source, 20)
            return false
        end
    end
end
