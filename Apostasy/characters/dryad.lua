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

local function clampFireAngle(vec)
    if math.abs(vec.Y) >= math.abs(vec.X) then -- vertically firing
        return Vector(0, vec.Y):Normalized()
    end
    return Vector(vec.X, 0):Normalized()
end

function dryad:DoFireBolt_(player)
    local ad = self:ActiveData(player)
    local c = ad.controls
    
    local t = player:FireTear(player.Position, Vector.Zero)
    t:ChangeVariant(TearVariant.NAIL)
    local spd = math.min(player.ShotSpeed * 48, 56)
    local fireDir = c.fireDir
    fireDir = clampFireAngle(fireDir)
    t:AddVelocity(fireDir * spd)
    
    -- we set our scales up manually to give a good hitbox size for the projectile speed
    t.Scale = 2
    t.SpriteScale = Vector(0.5, 0.5)
    
    t.Height = -6
    t.FallingAcceleration = 0
    t.FallingSpeed = -0.25
    
    Apostasy:QueueUpdateRoutine(function()
        coroutine.yield()
        while not t:IsDead() do
            coroutine.yield()
        end
        if not t:Exists() then return end
        
        --local b = Isaac.Spawn(EntityType.ENTITY_BOMB, player:GetBombVariant(TearFlags.TEAR_NORMAL, false), 0, t.Position - t.Velocity, Vector.Zero, player):ToBomb()
        --b.Flags = player:GetBombFlags() b.Visible = false b:SetExplosionCountdown(0)
    end)
end

function dryad:GetBoltsPerTap(player)
    -- calculate fire rate
    local fr = 30 / (player.MaxFireDelay + 1)
    
    return math.max(1, math.min(math.floor(fr + 0.5), 30))
end

-- this is the instant action of setting a reloaded magazine
function dryad:Reload(player)
    
end

function dryad:HandleCrossbowSprite(player)
    local ad = self:ActiveData(player)
    
    local spr = ad.crossbowSprite
    if not spr or not spr:Exists() or spr:IsDead() then
        --print "new crossbow"
        spr = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, 0, player.Position, Vector.Zero, nil and player):ToEffect()
        ad.crossbowSprite = spr
        
        spr.SpriteScale = Vector(0.5, 0.5)
        spr.DepthOffset = 0
    end
    
    spr:SetTimeout(2)
    --spr.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
    local fd = ad.controls.fireDir:Normalized()
    
    if not ad.crossbowDir then ad.crossbowDir = fd end
    ad.crossbowDir:Lerp(fd, 0.5)
    ad.crossbowDir:Normalize()
    
    local np = (ad.crossbowDir * (28 - ad.kickback*0.75)) --* Vector(1, 3/4)
    spr.Position = player.Position + np
    
    if ad.kickback > 0 then
        ad.kickback = math.max(0, ad.kickback - 1)
    end
end

-- -- -- -- -- --- --- --- --- -- -- -- -- --
-- -- -- -- -- callbacks below -- -- -- -- --
-- -- -- -- -- --- --- --- --- -- -- -- -- --

function dryad:InitActiveData(player, ad)
    ad.kickback = 0
    
    ad.crFiring = coroutine.create(self.FiringBehavior)
    coroutine.resume(ad.crFiring, self, player)
end

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
    
    -- TODO: reload key
    
    coroutine.resume(ad.crFiring)
    
    if c.bombP then
        player:AddBombs(1)
    end
    
    self:HandleCrossbowSprite(player)
end

function dryad:FiringBehavior(player)
    local ad = self:ActiveData(player)
    coroutine.yield() -- end lead-in so we're in update
    
    local states = { }
    
    local function enterState(n)
        if not states[n] then return end
        ad.firingState = n
        states[n]()
        ad.firingState = nil
    end
    
    local buffered = false
    local function chkBuf()
        if ad.controls.fireP then buffered = true end
    end
    local function waitInterp()
        while player:HasEntityFlags(EntityFlag.FLAG_INTERPOLATION_UPDATE) do coroutine.yield() end
    end
    
    function states.charging()
        while ad.controls.fire do
            coroutine.yield()
        end
        enterState "fire"
    end
    
    function states.fire()
        local nf, i = self:GetBoltsPerTap(player)
        
        for i = 1, nf do
            ad.kickback = 5
            player.FireDelay = player.MaxFireDelay
            self:DoFireBolt_(player)
            enterState "cooldown"
        end
    end
    
    function states.cooldown()
        while player.FireDelay > 0 do
            coroutine.yield()
            chkBuf()
            if not player:HasEntityFlags(EntityFlag.FLAG_INTERPOLATION_UPDATE) then
                player.FireDelay = player.FireDelay - 1
            end
        end
    end
    
    while true do -- main loop
        -- waiting for fire input
        chkBuf()
        if buffered and not player:HasEntityFlags(EntityFlag.FLAG_INTERPOLATION_UPDATE) then
            buffered = false
            if not ad.controls.fire then
                enterState "fire"
            else -- charge
                enterState "charging"
            end
        end
        
        coroutine.yield()
    end
end

function dryad:OnCheckInput(player, hook, btn)
    if btn == ButtonAction.ACTION_BOMB and hook == InputHook.IS_ACTION_TRIGGERED then
        return false -- disable normal bomb placement while retaining counter
    end
end
