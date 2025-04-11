-- Character: Dryad

local Apostasy = _ENV["::Apostasy"]
local tableUtil = Apostasy:require "util.table"
local color = Apostasy:require "util.color"
local rand = Apostasy:require "util.random"

local itemConfig = Isaac.GetItemConfig()
local game = Game()
local sfx = SFXManager()

local CHARACTER_NAME = "Dryad"
local dryad = Apostasy:RegisterCharacter(CHARACTER_NAME)

local function bflag(fd, fl) return fd & fl == fl end
local function sleep(t)
    if not t or t <= 0 then return end
    local i for i = 1, t do coroutine.yield() end
end



-- -- -- -- -- --- --- --- --- -- -- -- -- --
-- -- -- -- -- callbacks below -- -- -- -- --
-- -- -- -- -- --- --- --- --- -- -- -- -- --

function dryad:OnEffectUpdate(player)
    if player.FireDelay > 0 then
        --print("fire delay", player.FireDelay)
        -- FireDelay *does* count down at effect update rates
    end
    
    local ad = self:ActiveData(player)
    
    
end

function dryad:OnUpdate(player)
    local ad = self:ActiveData(player)
    local c = self:QueryControls(player)
    
    if c.fireP then
        local t = player:FireTear(player.Position, Vector.Zero)
        t:ChangeVariant(TearVariant.NAIL)
        local spd = math.min(player.ShotSpeed * 48, 56)
        t:AddVelocity(c.fireDir * spd)
        
        -- we 
        t.Scale = 2
        t.SpriteScale = Vector(0.5, 0.5)
        
        Apostasy:QueueUpdateRoutine(function()
            coroutine.yield()
            while not t:IsDead() do
                coroutine.yield()
            end
            if not t:Exists() then return end
            --game.BombExplosionEffects(t.Position, player.Damage, player:GetBombFlags(), player)
            
            --local b = Isaac.Spawn(EntityType.ENTITY_BOMB, player:GetBombVariant(TearFlags.TEAR_NORMAL, false), 0, t.Position - t.Velocity, Vector.Zero, player):ToBomb()
            --b.Flags = player:GetBombFlags() b.Visible = false b:SetExplosionCountdown(0)
        end)
    end
    
    if c.bombP then
        player:AddBombs(1)
    end
end

function dryad:OnCheckInput(player, hook, btn)
    if btn == ButtonAction.ACTION_BOMB and hook == InputHook.IS_ACTION_TRIGGERED then
        return false -- disable normal bomb placement while retaining counter
    end
end
