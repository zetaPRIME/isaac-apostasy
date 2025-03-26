local Apostasy = RegisterMod("Apostasy", 1)
_ENV["::Apostasy"] = Apostasy

local gabrielType = Isaac.GetPlayerTypeByName("Wisp Soul", false) -- Exactly as in the xml. The second argument is if you want the Tainted variant.
local hairCostume = Isaac.GetCostumeIdByPath("gfx/characters/gabriel_hair.anm2") -- Exact path, with the "resources" folder as the root
local stolesCostume = Isaac.GetCostumeIdByPath("gfx/characters/gabriel_stoles.anm2") -- Exact path, with the "resources" folder as the root

function Apostasy:GiveCostumesOnInit(player)
    if player:GetPlayerType() ~= gabrielType then
        return -- End the function early. The below code doesn't run, as long as the player isn't Gabriel.
    end

    player:AddNullCostume(hairCostume)
    player:AddNullCostume(stolesCostume)
end

Apostasy:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, Apostasy.GiveCostumesOnInit)


--------------------------------------------------------------------------------------------------


local game = Game() -- We only need to get the game object once. It's good forever!
local DAMAGE_REDUCTION = 0.6
function Apostasy:HandleStartingStats(player, flag)
    if player:GetPlayerType() ~= gabrielType then
        return -- End the function early. The below code doesn't run, as long as the player isn't Gabriel.
    end

    if flag == CacheFlag.CACHE_DAMAGE then
        -- Every time the game reevaluates how much damage the player should have, it will reduce the player's damage by DAMAGE_REDUCTION, which is 0.6
        player.Damage = player.Damage - DAMAGE_REDUCTION
    end
end

Apostasy:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Apostasy.HandleStartingStats)

function Apostasy:HandleHolyWaterTrail(player)
    if player:GetPlayerType() ~= gabrielType then
        return -- End the function early. The below code doesn't run, as long as the player isn't Gabriel.
    end

    -- Every 4 frames. The percentage sign is the modulo operator, which returns the remainder of a division operation!
    if game:GetFrameCount() % 4 == 0 then
        -- Vector.Zero is the same as Vector(0, 0). It is a constant!
        local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL, 0, player.Position, Vector.Zero, player):ToEffect()
        creep.SpriteScale = Vector(0.5, 0.5) -- Make it smaller!
        creep:Update() -- Update it to get rid of the initial red animation that lasts a single frame.
    end
end

Apostasy:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, Apostasy.HandleHolyWaterTrail)

--------------------------------------------------------------------------------------------------

local TAINTED_GABRIEL_TYPE = Isaac.GetPlayerTypeByName("Wisp Soul", true)
local HOLY_OUTBURST_ID = Isaac.GetItemIdByName("Holy Outburst")
local game = Game()

---@param player EntityPlayer
function Apostasy:TaintedGabrielInit(player)
    if player:GetPlayerType() ~= TAINTED_GABRIEL_TYPE then
        return
    end

    player:SetPocketActiveItem(HOLY_OUTBURST_ID, ActiveSlot.SLOT_POCKET, true)

    local pool = game:GetItemPool()
    pool:RemoveCollectible(HOLY_OUTBURST_ID)
end

Apostasy:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, Apostasy.TaintedGabrielInit)

function Apostasy:HolyOutburstUse(_, _, player)
    local spawnPos = player.Position

    local creep = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.PLAYER_CREEP_HOLYWATER, 0, spawnPos, Vector.Zero, player):ToEffect()
    creep.Scale = 2
    creep:Update()

    return true
end

Apostasy:AddCallback(ModCallbacks.MC_USE_ITEM, Apostasy.HolyOutburstUse, HOLY_OUTBURST_ID)
