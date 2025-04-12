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

local shotTypes = {
    normal = {
        flags = TearFlags.TEAR_NORMAL,
        flagsRem = TearFlags.TEAR_NORMAL,
        
        OnInit = function(tear)
            
        end,
    },
    explosive = {
        flags = TearFlags.TEAR_NORMAL,
        flagsRem = TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING,
        
        OnInit = function(tear)
            
        end,
        OnKill = function(tear)
            
        end,
    }
} for k,v in pairs(shotTypes) do v.id = k end

do
    function dryad:FireShot(player, shotType, dir)
        
    end
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
    t.Visible = false
    
    -- we set our scales up manually to give a good hitbox size for the projectile speed
    t.Scale = 2
    t.SpriteScale = Vector(0.5, 0.5)
    
    t.Height = -6
    t.FallingAcceleration = 0
    t.FallingSpeed = -1
    
    Apostasy:QueueUpdateRoutine(function()
        coroutine.yield()
        t.Visible = true
        while not t:IsDead() do
            coroutine.yield()
        end
        if not t:Exists() then return end
        
        local b = Isaac.Spawn(EntityType.ENTITY_BOMB, player:GetBombVariant(TearFlags.TEAR_NORMAL, false), 0, t.Position - t.Velocity, Vector.Zero, player):ToBomb()
        b.ExplosionDamage = player.Damage
        b.Flags = player:GetBombFlags() b.Visible = false b:SetExplosionCountdown(0)
    end)
end

function dryad:GetBoltsPerTap(player)
    -- calculate fire rate
    local fr = 30 / (player.MaxFireDelay + 1)
    
    return math.max(1, math.min(math.floor(fr/2 + 0.5), 5))
end

-- this is the instant action of setting a reloaded magazine
function dryad:Reload(player)
    local nb = self:GetBoltsPerTap(player)
    local mag = 15 + (nb-1) * 5
    mag = math.ceil(mag/nb)*nb -- always even multiple
    
    local ad = self:ActiveData(player)
    ad.boltsMax = mag
    ad.bolts = mag
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
    local fd = ad.controls.fireDir:Normalized()
    
    if not ad.crossbowDir then ad.crossbowDir = fd end
    if ad.controls.fire then
        --
    elseif player.FireDelay < 0 then
        fd = Vector.FromAngle(player:GetHeadDirection() * 90 + 180)
    end
    
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
    
    self:Reload(player)
    
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
    if c.bombP then
        self:Reload(player)
    end
    
    coroutine.resume(ad.crFiring)
    
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
            if ad.bolts <= 0 then
                sfx:Play(SoundEffect.SOUND_BUTTON_PRESS, 1, 2, false, 1)
                sfx:Play(SoundEffect.SOUND_BONE_BOUNCE, 1, 2, false, 2.5)
                break
            end
            ad.bolts = ad.bolts - 1
            ad.kickback = 5
            self:DoFireBolt_(player)
            sfx:Stop(SoundEffect.SOUND_TEARS_FIRE)
            sfx:Play(SoundEffect.SOUND_SWORD_SPIN, 0.42, 2, false, 2)
            sfx:Play(SoundEffect.SOUND_GFUEL_GUNSHOT, 0.37, 2, false, 1.5)
            enterState "cooldown"
        end
    end
    
    function states.cooldown()
        if player.FireDelay < 0 then player.FireDelay = player.MaxFireDelay end
        while player.FireDelay >= 0 do -- player object does the decrementing
            chkBuf()
            coroutine.yield()
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

function dryad:OnRender(player, offset)
    local ad = self:ActiveData(player)
    local str = ad.bolts .. " / " .. ad.boltsMax
    local scale = 0.5
    local tw = Isaac.GetTextWidth(str) * scale
    local pos = Isaac.WorldToScreen(player.Position + Vector(0, -64))
    Isaac.RenderScaledText(str, pos.X - tw/2, pos.Y, scale, scale, 1, 1, 1, 1)
end

function dryad:OnCheckInput(player, hook, btn)
    if btn == ButtonAction.ACTION_BOMB and hook == InputHook.IS_ACTION_TRIGGERED then
        return false -- disable normal bomb placement while retaining counter
    end
end
