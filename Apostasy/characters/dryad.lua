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

local function roundVec(vec)
    return Vector(math.floor(vec.X + 0.5), math.floor(vec.Y + 0.5))
end

local function dps(player)
    local fr = 30 / (player.MaxFireDelay + 1)
    return player.Damage * fr
end

local shotTypes = {
    normal = {
        speedMult = 48,
        
        variant = TearVariant.NAIL,
        hitboxScale = 2,
        spriteScale = 0.5,
        
        flags = TearFlags.TEAR_NORMAL,
        flagsRem = TearFlags.TEAR_NORMAL,
        
        OnFired = function(self, tear)
            
        end,
    },
    explosive = {
        speedMult = 42,
        
        flags = TearFlags.TEAR_NORMAL,
        flagsRem = TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING | TearFlags.TEAR_HOMING,
        
        OnFired = function(self, tear)
            
        end,
        OnKill = function(self, tear)
            local player = tear.SpawnerEntity:ToPlayer()
            
            local b = Isaac.Spawn(EntityType.ENTITY_BOMB, player:GetBombVariant(TearFlags.TEAR_NORMAL, false), 0, tear.Position - tear.Velocity, Vector.Zero, player):ToBomb()
            b.ExplosionDamage = tear.CollisionDamage
            b.Flags = player:GetBombFlags() b.Visible = false b:SetExplosionCountdown(0)
        end,
    }
} for k,v in pairs(shotTypes) do v.id = k end

do
    local function trt(self, player, tear, shotType)
        coroutine.yield()
        tear.Visible = true
        while not tear:IsDead() do
            coroutine.yield()
        end
        if not tear:Exists() then return end
        
        if shotType.OnKill then shotType.OnKill(self, tear) end
    end
    
    function dryad:FireShot(player, shotType, dir)
        if type(shotType) == "string" then shotType = shotTypes[shotType] end
        if not shotType then return end
        local normal = shotTypes.normal
        
        local t = player:FireTear(player.Position, Vector.Zero)
        t:ChangeVariant(shotType.variant or normal.variant)
        sfx:Stop(SoundEffect.SOUND_TEARS_FIRE) -- no default sound, thanks
        
        -- we set our scales up manually to give a good hitbox size for the projectile speed
        t.Scale = shotType.hitboxScale or normal.hitboxScale
        t.SpriteScale = Vector.One * (shotType.spriteScale or normal.spriteScale)
        
        -- and now we figure out speed
        local spd = math.min(player.ShotSpeed * shotType.speedMult, 56)
        t:AddVelocity(dir * spd)
        t.Visible = false
        
        t.Height = -6
        t.FallingAcceleration = 0
        t.FallingSpeed = -1
        
        if shotType.flagsRem then t:ClearTearFlags(shotType.flagsRem) end
        if shotType.flags then t:AddTearFlags(shotType.flags) end
        t.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_BULLET
        t:AddTearFlags(t.TearFlags) -- kick it
        
        if shotType.OnFired then shotType.OnFired(self, t) end
        Apostasy:QueueUpdateRoutine(trt, self, player, t, shotType)
                
        return t
    end
end

function dryad:GetFireDirection(player)
    local ad = self:ActiveData(player)
    local fireDir = ad.controls.fireDir
    
    -- clamp direction if player doesn't have an analog aim item
    if not player:HasCollectible(CollectibleType.COLLECTIBLE_ANALOG_STICK)
    and not player:HasCollectible(CollectibleType.COLLECTIBLE_MARKED)
    and not player:HasCollectible(CollectibleType.COLLECTIBLE_REVELATION)
    then
        fireDir = clampFireAngle(fireDir)
    end
    return fireDir
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

function dryad:TryPayCosts(player, bolts, mana)
    local ad = self:ActiveData(player)
    if not mana then mana = 0 end
    
    if ad.bolts < bolts then return false end
    
    -- TODO mana cost
    ad.bolts = math.max(0, ad.bolts - bolts)
    return true
end

local spellTypes = {
    wind = {
        
    },
    
    fire = {
        manaCost = 15,
        chargeTime = 20,
        
        goldenManaCost = 5, -- spammable!
        
        noBombManaCost = 40,
        noBombChargeTime = 45,
        
        -- different properties if no bombs
        GetCost = function(self, player, spellType)
            if player:HasGoldenBomb() then return spellType.goldenManaCost end
            if player:GetNumBombs() == 0 then return spellType.noBombManaCost end
            return spellType.manaCost
        end,
        GetChargeTime = function(self, player, spellType)
            if player:GetNumBombs() == 0 and not player:HasGoldenBomb() then return spellType.noBombChargeTime end
            return spellType.chargeTime
        end,
        
        OnCast = function(self, player, spellType)
            local goldenBomb = player:HasGoldenBomb()
            local withBomb = player:GetNumBombs() > 0 or goldenBomb
            if withBomb and not goldenBomb then player:AddBombs(-1) end -- take the cost
            
            local ad = self:ActiveData(player)
            ad.kickback = 15
            
            local t = self:FireShot(player, shotTypes.explosive, self:GetFireDirection(player))
            local dmg = dps(player) * 3
            t.CollisionDamage = dmg
        end,
    },
    
    wood = {
        
    },
} for k, v in pairs(spellTypes) do v.id = k end

function dryad:GetSpellCost(player, spellType)
    if type(spellType) == "string" then spellType = spellTypes[spellType] end
    if not spellType then return 0 end
    
    if spellType.GetCost then return spellType.GetCost(self, player, spellType) end
    return spellType.manaCost or 0
end
function dryad:GetSpellChargeTime(player, spellType)
    if type(spellType) == "string" then spellType = spellTypes[spellType] end
    if not spellType then return 0 end
    
    if spellType.GetChargeTime then return spellType.GetChargeTime(self, player, spellType) end
    return spellType.chargeTime or 30
end
function dryad:GetSpellBolts(player, spellType)
    if type(spellType) == "string" then spellType = spellTypes[spellType] end
    if not spellType then return 0 end
    return spellType.boltCost or 1
end

function dryad:CastSpell(player, spellType)
    if type(spellType) == "string" then spellType = spellTypes[spellType] end
    if not spellType then return end
    
    if spellType.OnCast then spellType.OnCast(self, player, spellType) end
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
    local fd = self:GetFireDirection(player)-- ad.controls.fireDir:Normalized()
    
    if not ad.crossbowDir then ad.crossbowDir = fd end
    if ad.controls.fire then
        --
    elseif player.FireDelay < 0 then
        fd = Vector.FromAngle(player:GetHeadDirection() * 90 + 180)
    end
    
    ad.crossbowDir:Lerp(fd, 0.5)
    ad.crossbowDir:Normalize()
    
    local np = (ad.crossbowDir * (28 - ad.kickback*0.75)) * Vector(1, 3/4)
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
    
    ad.selectedSpell = spellTypes.fire
    
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
        local ct = self:GetSpellChargeTime(player, ad.selectedSpell)
        ad.chargeTime = ct
        ad.charge = 0
        
        while ad.controls.fire do
            waitInterp()
            local fc = ad.charge >= ad.chargeTime
            ad.charge = math.min(ad.charge + 1, ad.chargeTime)
            local kb = 5 * (ad.charge / ad.chargeTime)
            ad.kickback = kb
            if ad.charge >= ad.chargeTime and not fc then
                sfx:Play(SoundEffect.SOUND_SOUL_PICKUP)
            end
            coroutine.yield()
            ad.kickback = kb
        end
        
        if ad.charge >= ad.chargeTime then
            
            self:CastSpell(player, ad.selectedSpell)
            enterState "cooldown"
        else
            enterState "fire"
        end
    end
    
    function states.fire()
        local nf, i = self:GetBoltsPerTap(player)
        
        for i = 1, nf do
            if not self:TryPayCosts(player, 1) then
                sfx:Play(SoundEffect.SOUND_BUTTON_PRESS, 1, 2, false, 1)
                sfx:Play(SoundEffect.SOUND_BONE_BOUNCE, 1, 2, false, 2.5)
                break
            end
            ad.kickback = 5
            self:FireShot(player, shotTypes.normal, self:GetFireDirection(player))
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

local fntNum = Font() fntNum:Load("font/pftempestasevencondensed.fnt")
local fntSmall = Font() fntSmall:Load("font/luaminioutlined.fnt")

function dryad:OnPostRender(player)
    local ad = self:ActiveData(player)
    
    if ad.firingState == "charging" or ad.firingState == "reloading" then -- charge bar
        if not ad.chargeBar then
            local cb = Sprite() ad.chargeBar = cb
            cb:Load("gfx/chargebar.anm2", true)
        end
        
        if ad.crossbowSprite and ad.crossbowSprite:Exists() then
            local pos = Isaac.WorldToScreen(ad.crossbowSprite.Position + Vector(0, -28))
            
            HudHelper.RenderChargeBar(ad.chargeBar, ad.charge, ad.chargeTime, pos)
        end
    end
    
    -- ammo counter
    local str = ad.bolts .. "/" .. ad.boltsMax
    local wstr = ad.boltsMax .. "/" .. ad.boltsMax
    
    local tw = fntSmall:GetStringWidth(wstr)
    local lh = fntSmall:GetLineHeight()
    local pos = Isaac.WorldToScreen(player.Position + Vector(0, -58))
    fntSmall:DrawString(str, pos.X - tw/2, pos.Y - lh, KColor(1,1,1,1), tw)
end

function dryad:OnCheckInput(player, hook, btn)
    if btn == ButtonAction.ACTION_BOMB and hook == InputHook.IS_ACTION_TRIGGERED then
        return false -- disable normal bomb placement while retaining counter
    end
end
