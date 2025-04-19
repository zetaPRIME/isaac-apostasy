-- Character: Dryad

local Apostasy = _ENV["::Apostasy"]
local tableUtil = Apostasy:require "util.table"
local color = Apostasy:require "util.color"
local rand = Apostasy:require "util.random"
local util = Apostasy:require "util.misc"

local itemConfig = Isaac.GetItemConfig()
local game = Game()
local sfx = SFXManager()

local CHARACTER_NAME = "Elysia"
local dryad = Apostasy:RegisterCharacter(CHARACTER_NAME)

local function bflag(fd, fl) return fd & fl == fl end
local sleep = util.sleep

local function clampFireAngle(vec)
    if math.abs(vec.Y) >= math.abs(vec.X) then -- vertically firing
        return Vector(0, vec.Y):Normalized()
    end
    return Vector(vec.X, 0):Normalized()
end

local function roundVec(vec)
    return Vector(math.floor(vec.X + 0.5), math.floor(vec.Y + 0.5))
end

local function getBombDamage(player) -- manual way because apparently not even REPENTOGON has anything
    local dmg = 100 -- base
    if player:HasCollectible(CollectibleType.COLLECTIBLE_MR_MEGA) then dmg = dmg + 85 end
    if player:HasTrinket(TrinketType.TRINKET_SHORT_FUSE) then dmg = dmg + 15 end
    return dmg
end

-- tear flags that just generally screw with a tear's path
local flagsWormEtc = TearFlags.TEAR_WIGGLE | TearFlags.TEAR_SPIRAL | TearFlags.TEAR_BIG_SPIRAL | TearFlags.TEAR_FLAT | TearFlags.TEAR_SQUARE
    | TearFlags.TEAR_ORBIT | TearFlags.TEAR_ORBIT_ADVANCED | TearFlags.TEAR_OCCULT | TearFlags.TEAR_DECELERATE
-- TEAR_TURN_HORIZONTAL?
local flagsBouncy = TearFlags.TEAR_BOUNCE | TearFlags.TEAR_BOUNCE_WALLSONLY
local flagsSticky = TearFlags.TEAR_STICKY | TearFlags.TEAR_BOOGER

local c255 = color.from255
local shotTypes = {
    normal = {
        speedMult = 36,
        
        variant = TearVariant.NAIL,
        color = color.colorize(.75, .5, .25, 1),
        hitboxScale = 2,
        spriteScale = 0.5,
        
        trailColor = Color(1, .875, .75, 0.666),
        trailSize = 0.666,
        
        flags = TearFlags.TEAR_NORMAL,
        flagsRem = TearFlags.TEAR_NORMAL,
        
        OnFired = function(self, tear)
            
        end,
    },
    wind = {
        speedMult = 40,
        variant = TearVariant.PUPULA,
        color = color.colorize(0.9, 1.75, 0.9, 1),
        hitboxScale = 3.5,
        spriteScale = Vector(1, 0.75),
        
        trailSize = 4,
        --trailColor = Color(0.5, 1.0, 0.75, 0.75),
        
        flags = TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL,
        flagsRem = flagsBouncy | flagsSticky | (flagsWormEtc ~ TearFlags.TEAR_WIGGLE),
        
        OnFired = function(self, tear)
            tear.SpriteOffset = tear.Velocity:Normalized() * -5
            tear.KnockbackMultiplier = tear.KnockbackMultiplier * 0.5
        end
    },
    shotgunIce = {
        speedMult = 30,
        
        variant = TearVariant.ICE,
        color = Color(1,1,1),
        spriteScale = Vector(0.5, 0.333),
        
        OnFired = function(self, tear)
            
        end,
    },
    explosive = {
        speedMult = 27,
        
        variant = TearVariant.MYSTERIOUS,--ICE,
        color = color.colorize(1.5, 0.75, 0.2, 1),
        hitboxScale = 2.1,
        --spriteScale = Vector(0.333, 0.25),
        spriteScale = Vector(0.75, 0.42),
        --spriteScale = 0.333,
        
        trailSize = 1.5,
        
        flags = TearFlags.TEAR_NORMAL,
        flagsRem = TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING | TearFlags.TEAR_HOMING | flagsBouncy | flagsSticky | flagsWormEtc,
        
        OnFired = function(self, tear)
            --print("lol", fnarb())
        end,
        OnKill = function(self, tear)
            local player = tear.SpawnerEntity:ToPlayer()
            
            local b = Isaac.Spawn(EntityType.ENTITY_BOMB, player:GetBombVariant(TearFlags.TEAR_NORMAL, false), 0, tear.Position - (tear.Velocity * 1.5), Vector.Zero, player):ToBomb()
            b.ExplosionDamage = tear.CollisionDamage * 2
            b.Flags = player:GetBombFlags() b.Visible = false b:SetExplosionCountdown(0)
            if player:HasCollectible(CollectibleType.COLLECTIBLE_REMOTE_DETONATOR) then
                player:UseActiveItem(CollectibleType.COLLECTIBLE_REMOTE_DETONATOR) -- I'm not asking.
            end
        end,
    },
} for k,v in pairs(shotTypes) do v.id = k end

do
    local function trt(self, player, tear, shotType, trail)
        if trail then
            --trail.ParentOffset = tear.PositionOffset
        end
        coroutine.yield()
        tear.Visible = true
        local homing = tear:HasTearFlags(TearFlags.TEAR_HOMING)
        if trail then
            trail.Visible = true
        end
        while not tear:IsDead() do
            if trail then
                trail.ParentOffset = tear.PositionOffset --+ Vector(0, -6.25)
                trail:SetTimeout(10)
            end
            if homing then
                if tear.Velocity:Length() > 17 then
                    tear.HomingFriction = 0.75
                else
                    tear.HomingFriction = 1.05
                end
            end
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
        
        if shotType.color then t.Color = shotType.color end
        
        -- we set our scales up manually to give a good hitbox size for the projectile speed
        t.Scale = shotType.hitboxScale or normal.hitboxScale
        local scale = shotType.spriteScale or normal.spriteScale
        if type(scale) == "number" then
            t.SpriteScale = Vector.One * scale
        else
            t.SpriteScale = scale
        end
        
        -- and now we figure out speed
        local maxSpeed = 48
        local sm = shotType.speedMult or normal.speedMult
        local sv = dir * (player.ShotSpeed * sm)
        sv = sv + (player.Velocity * 0.75)
        if sv:Length() > maxSpeed then sv = sv:Normalized() * maxSpeed end
        t.Visible = false
        
        local height = -6
        if player.CanFly then height = height - 4 end
        t.Height = height -- we want this coming out of the crossbow
        t.FallingAcceleration = 0
        t.FallingSpeed = -1 -- TODO calculate stuff based on height+range
        t:Update() -- kick offset
        t:AddVelocity(sv)
        
        if shotType.flagsRem then t:ClearTearFlags(shotType.flagsRem) end
        if shotType.flags then t:AddTearFlags(shotType.flags) end
        t.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_BULLET
        t:AddTearFlags(t.TearFlags) -- kick it
        
        if t:HasTearFlags(TearFlags.TEAR_HOMING) then
            t.FallingSpeed = t.FallingSpeed - 1.5 -- last a bit longer
        end
        
        local tr
        if not shotType.noTrail then
            tr = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SPRITE_TRAIL, 0, t.Position + t.PositionOffset, Vector.Zero, t):ToEffect()
            tr.Parent = t
            tr:FollowParent(t)
            
            tr.Position = t.Position
            tr.ParentOffset = t.PositionOffset --+ Vector(0, -6)
            
            if shotType.trailColor then tr.Color = shotType.trailColor
            else -- new Color on the left side because *someone* decided the multiplication operator should modify the left operand
                tr.Color = Color(1,1,1, 0.75) * (shotType.color or Color(1,1,1))
            end
            
            tr:GetSprite().Scale = Vector.One * (shotType.trailSize or normal.trailSize)
            tr.MinRadius = 0.15
            tr.DepthOffset = -5
            
            --tr:Update()
        end
        
        if shotType.OnFired then util.lpcall(shotType.OnFired, self, t, tr) end
        Apostasy:QueueUpdateRoutine(trt, self, player, t, shotType, tr)
        
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
    
    local rd = self:RunData(player)
    rd.boltsMax = mag
    rd.bolts = mag
end

function dryad:GetMana(player)
    local rd = self:RunData(player)
    local max = 100
    return (rd.mana or 0), max
end

function dryad:TryPayCosts(player, bolts, mana)
    if type(bolts) == "table" then -- passed spell
        return self:TryPayCosts(player, self:GetSpellBolts(player, bolts), self:GetSpellCost(player, bolts))
    end
    
    local ad = self:ActiveData(player)
    local rd = self:RunData(player)
    if not mana then mana = 0 end
    
    -- check both
    if rd.bolts < bolts then return false end
    if rd.mana < mana then return false end
    
    -- deduct cost
    rd.bolts = math.max(0, rd.bolts - bolts)
    rd.mana = math.max(0, rd.mana - mana)
    
    return true
end

local spellTypes = {
    wind = {
        name = "Galeshot",
        
        manaCost = 20,
        chargeTime = 15,
        
        WhileCharging = function(self, player, spellType)
            local ad = self:ActiveData(player)
            ad.dpsCache = util.playerDPS(player) -- cache dps value for Epiphora-like effects
        end,
        OnCast = function(self, player, spellType)
            local ad = self:ActiveData(player)
            ad.kickback = 15
            
            -- bit of a silly stack of sounds, but
            sfx:Play(SoundEffect.SOUND_GFUEL_GUNSHOT, 1, 2, false, 1.5)
            --sfx:Play(SoundEffect.SOUND_SWORD_SPIN, 0.666, 0, false, 1.5)
            sfx:Play(SoundEffect.SOUND_SWORD_SPIN, 0.75, 0, false, 1.25)
            sfx:Play(SoundEffect.SOUND_FLAMETHROWER_END, 0.75, 2, false, 1.75)
            
            local dmg = math.max(util.playerDPS(player), ad.dpsCache) * 1.1
            local pdmg = dmg * util.playerMultishot(player)
            
            local t = self:FireShot(player, shotTypes.wind, self:GetFireDirection(player))
            t.CollisionDamage = pdmg
            
            player.FireDelay = 14
            ad.fireHold = 32
        end,
    },
    
    ice = {
        name = "Frostburst",
        
        manaCost = 35,
        boltCost = 3,
        chargeTime = 25,
        
        WhileCharging = function(self, player, spellType)
            local ad = self:ActiveData(player)
            ad.dpsCache = util.playerDPS(player) -- cache dps value for Epiphora-like effects
        end,
        OnCast = function(self, player, spellType)
            local ad = self:ActiveData(player)
            ad.kickback = 15
            
            sfx:Play(SoundEffect.SOUND_GFUEL_GUNSHOT, 1, 2, false, 1.5)
            sfx:Play(SoundEffect.SOUND_FREEZE_SHATTER, 0.75, 2, false, 0.75)
            sfx:Play(SoundEffect.SOUND_FREEZE, 0.5, 2, false, 0.75)
            --sfx:Play(SoundEffect.SOUND_SWORD_SPIN, 0.42, 2, false, 2)
            
            local nproj = 5 -- how many projectiles
            local fan = 20 -- total spread degrees
            
            local dmg = math.max(util.playerDPS(player), ad.dpsCache) * 2
            local pdmg = dmg/nproj * util.playerMultishot(player)
            
            local fd = self:GetFireDirection(player)
            for i = 1, nproj do
                local nfd = fd:Rotated(fan * ((i-1)/(nproj-1) - 0.5))
                local t = self:FireShot(player, shotTypes.shotgunIce, nfd)
                t.CollisionDamage = pdmg
                t.KnockbackMultiplier = t.KnockbackMultiplier / 2
                
                if rand.rollPercent(10, player) then
                    t:AddTearFlags(TearFlags.TEAR_ICE)
                end
            end
        end,
    },
    
    fire = {
        name = "Fireblast",
        
        manaCost = 15,
        chargeTime = 20,
        
        goldenManaCost = 10, -- spammable!
        
        noBombManaCost = 50,
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
        
        WhileCharging = function(self, player, spellType)
            local ad = self:ActiveData(player)
            ad.dpsCache = util.playerDPS(player) -- cache dps value for Epiphora-like effects
        end,
        OnCast = function(self, player, spellType)
            local goldenBomb = player:HasGoldenBomb()
            local withBomb = player:GetNumBombs() > 0 or goldenBomb
            if withBomb and not goldenBomb then player:AddBombs(-1) end -- take the cost
            
            local ad = self:ActiveData(player)
            ad.kickback = 15
            
            sfx:Play(SoundEffect.SOUND_FLAMETHROWER_END, 1, 2, false, 1.5)
            sfx:Play(SoundEffect.SOUND_SWORD_SPIN, 0.666, 2, false, 1.5)
            
            local t = self:FireShot(player, shotTypes.explosive, self:GetFireDirection(player))
            local dmg = math.max(util.playerDPS(player), ad.dpsCache) * 1.5
            dmg = dmg * util.playerMultishot(player)
            if withBomb then
                local bombDmg = getBombDamage(player)
                if goldenBomb then bombDmg = bombDmg * 1.5 end
                dmg = math.max(dmg, bombDmg/2)
            end
            t.CollisionDamage = dmg
        end,
    },
    
    --
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
    
    player.FireDelay = 4 -- 5 ticks
    if spellType.OnCast then util.lpcall(spellType.OnCast, self, player, spellType) end
end

function dryad:SelectSpell(player, spellType, silent)
    if type(spellType) == "string" then spellType = spellTypes[spellType] end
    if not spellType then return end
    
    local rd = self:RunData(player)
    local ad = self:ActiveData(player)
    local prev = ad.selectedSpell
    ad.selectedSpell = spellType
    rd.selectedSpell = spellType.id
    
    if not silent then
        if spellType ~= prev then
            sfx:Play(SoundEffect.SOUND_BEEP, 1, 2, false, 1.25)
        else
            sfx:Play(SoundEffect.SOUND_BEEP, 1, 2, false, 0.9)
        end
    end
end

function dryad:HandleCrossbowSprite(player)
    local ad = self:ActiveData(player)
    
    local spr, sp = ad.crossbowSprite
    if not spr or not spr:Exists() or spr:IsDead() then
        --print "new crossbow"
        spr = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.BLUE_FLAME, 0, player.Position, Vector.Zero, nil and player):ToEffect()
        ad.crossbowSprite = spr
        
        --spr.SpriteScale = Vector(0.5, 0.5)
        spr.DepthOffset = 2
        
        if REPENTOGON then -- drop shadow is nice to have
            spr:SetShadowSize(0.15)
        end
        
        sp = spr:GetSprite()
        sp:Load("gfx/characters/apostasy.dryad.crossbow.anm2", true)
        spr.SpriteOffset = Vector(0, -9)
    else sp = spr:GetSprite() end
    
    spr:SetTimeout(2)
    local fd = self:GetFireDirection(player)-- ad.controls.fireDir:Normalized()
    
    if not ad.crossbowDir then ad.crossbowDir = fd end
    if ad.fireHold > 0 then
        fd = ad.fireHoldDir:Normalized()
    else--if player.FireDelay < 0 then
        fd = Vector.FromAngle(player:GetHeadDirection() * 90 + 180)
    end
    if ad.spellMenu or ad.firingState == "reloading" then
        fd = Vector(0, 1)
    end
    
    ad.crossbowDir:Lerp(fd, 0.5)
    ad.crossbowDir:Normalize()
    
    local np = (ad.crossbowDir * (28 - ad.kickback*0.75)) --* Vector(1, 3/4)
    spr.Position = player.Position + np
    
    local anm, frame = "Down", 0
    if math.abs(fd.X) > math.abs(fd.Y) then
        anm = "Side"
        local rot = (fd:GetAngleDegrees() + 360 + 90) % 360
        if rot >= 180 then rot = 360 - rot end
        sp.Rotation = rot - 90
        sp.FlipX = fd.X < 0
    else
        sp.Rotation = fd:GetAngleDegrees() - 90
        sp.FlipX = false
    end
    if ad.firingState == "charging" then
        frame = math.floor((ad.charge / ad.chargeTime) * 2.5 + 0.75)
    elseif ad.firingState == "reloading" then
        frame = math.floor((ad.charge / ad.chargeTime) * 4 - 0.01)
    end
    sp:SetFrame(anm, frame)
    spr.Visible = player.Visible and not util.IsIncapacitated(player)
    spr.SpriteOffset = player.CanFly and Vector(0, -13) or Vector(0, -9)
    
    if ad.kickback > 0 then
        ad.kickback = math.max(0, ad.kickback - 1)
    end
end

function dryad:EvaluateActionStats(player) -- queue function
    local ad = self:ActiveData(player)
    if not ad._queuedEval then
        ad._queuedEval = true
        Apostasy:QueueUpdateRoutine(function()
            self:_EvaluateActionStats(player)
            ad._queuedEval = nil
        end)
    end
end
function dryad:_EvaluateActionStats(player, inEval)
    player:AddCacheFlags(CacheFlag.CACHE_SPEED)
    player:EvaluateItems()
end

function dryad:SetFireHold(player, t, dir)
    local ad = self:ActiveData(player)
    if t <= 0 then ad.fireHold = 0 -- clear
    else
        ad.fireHold = math.max(ad.fireHold, t)
        dir = dir or self:GetFireDirection(player)
        ad.fireHoldDir = dir
        
        -- figure out button to hold
        local x, y, btn = dir.X, dir.Y
        if math.abs(x) > math.abs(y) then
            if x >= 0 then btn = ButtonAction.ACTION_SHOOTRIGHT
            else btn = ButtonAction.ACTION_SHOOTLEFT end
        else
            if y >= 0 then btn = ButtonAction.ACTION_SHOOTDOWN
            else btn = ButtonAction.ACTION_SHOOTUP end
        end ad.fireHoldButton = btn
    end
end

-- -- -- -- -- --- --- --- --- -- -- -- -- --
-- -- -- -- -- callbacks below -- -- -- -- --
-- -- -- -- -- --- --- --- --- -- -- -- -- --

function dryad:InitActiveData(player, ad)
    local rd = self:RunData(player)
    ad.kickback = 0
    ad.fireHold = 0
    
    if not rd.bolts or not rd.boltsMax then
        self:Reload(player)
    end
    
    self:SelectSpell(player, rd.selectedSpell or "wind", true)
    
    ad.crFiring = coroutine.create(self.FiringBehavior)
    coroutine.resume(ad.crFiring, self, player)
end

function dryad:InitRunData(player, rd, noHg)
    if not noHg then
        local _, manaMax = self:GetMana(player)
        rd.mana = manaMax
    end
end

function dryad:OnEvaluateCache(player, cacheFlag)
    local ad = self:ActiveData(player)
    
    if cacheFlag == CacheFlag.CACHE_SPEED then
        if not REPENTOGON then player.MoveSpeed = player.MoveSpeed + 0.1 end
        if ad.firingState == "reloading" then
            player.MoveSpeed = player.MoveSpeed * 0.5
        end
    elseif cacheFlag == CacheFlag.CACHE_DAMAGE then
        if not REPENTOGON then player.Damage = player.Damage + 2 end
    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        if player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then
            -- counteract the fire rate multiplier since normal brim mechanics don't apply here
            player.MaxFireDelay = (player.MaxFireDelay + 1) / 3 - 1
        end
        
        -- handle the base tears modifier in vanilla engine
        if not REPENTOGON then util.modifyFireRate(player, -0.7272727272) end
        
        -- let's just. raise the minimum possible fire rate some <_< any longer than this just feels like the firing code broke
        player.MaxFireDelay = math.min(player.MaxFireDelay, 59) -- and if your tears are this low you're already oneshotting rooms
        
        --print("fire rate:", 30/(player.MaxFireDelay+1))
    end
    
    --print("dps:", util.playerDPS(player))
end

function dryad:OnEffectUpdate(player)
    if player.FireDelay > 0 then
        --print("fire delay", player.FireDelay)
        -- FireDelay *does* count down at effect update rates
    end
    
    local ad = self:ActiveData(player)
    
    
end

dryad.manaRegenRate = 5 -- per second
function dryad:OnUpdate(player)
    local ad = self:ActiveData(player)
    local rd = self:RunData(player)
    ad.fireHoldActive = false -- get the actual input direction
    local c = self:QueryControls(player)
    ad.fireHoldActive = true
    
    local _, maxMana = self:GetMana()
    rd.mana = math.min(rd.mana + self.manaRegenRate/60, maxMana)
    
    if ad.fireHold > 0 then ad.fireHold = ad.fireHold - 1 end
    
    -- handle reload key
    if c.bombP then
        ad.spellMenu = true
        ad.shouldQueueReload = true
    elseif ad.spellMenu and not c.bomb then
        ad.spellMenu = false
        ad.shouldReload = ad.shouldQueueReload and rd.bolts < rd.boltsMax
        player.FireDelay = 1
    end
    
    if ad.spellMenu then
        local sel = true
        if c.fireLeftP then
            self:SelectSpell(player, "ice")
        elseif c.fireDownP then
            self:SelectSpell(player, "fire")
        elseif c.fireRightP then
            self:SelectSpell(player, "wind")
        elseif c.fireUpP then -- TODO
        else sel = false end
        if sel then
            ad.shouldQueueReload = false
            --player.FireDelay = 5
        end
    end
    
    local res, err = util.resume(ad.crFiring)
    if not res then -- if the behavior routine errors, then...
        -- restart it so the character isn't left bricked
        ad.crFiring = coroutine.create(self.FiringBehavior)
        coroutine.resume(ad.crFiring, self, player)
    end
    
    self:HandleCrossbowSprite(player)
end

dryad.baseReloadTime = 36
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
        if ad.controls.fireP then
            buffered = true
        elseif player.FireDelay >= 20 and not ad.controls.fire then
            buffered = false -- don't leave lingering buffer for huge tear delays
        end
    end
    local function waitInterp()
        while player:HasEntityFlags(EntityFlag.FLAG_INTERPOLATION_UPDATE) do coroutine.yield() end
    end
    
    function states.charging()
        local ct = self:GetSpellChargeTime(player, ad.selectedSpell)
        ad.chargeTime = ct
        ad.charge = 0
        self:SetFireHold(player, 0)
        
        sfx:Play(SoundEffect.SOUND_ULTRA_GREED_SLOT_STOP, 0.666, 2, false, 2)
        
        while ad.controls.fire or not player.ControlsEnabled do
            if ad.spellMenu or ad.shouldReload then -- abort
                ad.shouldReload = false
                ad.spellMenu = false
                sfx:Play(SoundEffect.SOUND_SOUL_PICKUP, 1, 2, false, 0.666)
                return
            end
            -- cancel charge if crossbow should be hidden
            if util.IsIncapacitated(player) then return end
            waitInterp()
            local fc = ad.charge >= ad.chargeTime
            ad.charge = math.min(ad.charge + 1, ad.chargeTime)
            
            local kb = 5 * (ad.charge / ad.chargeTime)
            ad.kickback = kb
            
            if ad.charge >= ad.chargeTime then
                if not fc then
                    sfx:Play(SoundEffect.SOUND_ULTRA_GREED_SLOT_STOP, 0.35, 2, false, 2.25)
                    sfx:Play(SoundEffect.SOUND_SOUL_PICKUP, 1.1)
                end
            elseif ad.charge % 3 == 0 then
                sfx:Play(SoundEffect.SOUND_BUTTON_PRESS, 0.5, 2, false, 2.0 + (ad.charge / ad.chargeTime) * 1.75)
            end
            
            if ad.selectedSpell.WhileCharging then
                ad.selectedSpell.WhileCharging(self, player, ad.selectedSpell)
            end
            
            self:SetFireHold(player, 2) -- no frame of not holding
            
            coroutine.yield()
            ad.kickback = kb
        end
        
        if ad.charge >= ad.chargeTime then
            if REPENTOGON then -- paper over the single frame of not holding
                player:SetHeadDirection(player:GetHeadDirection(), 1)
            end
            ad.fireHoldActive = false -- let familiars release their charge
            
            if self:TryPayCosts(player, ad.selectedSpell) then
                self:SetFireHold(player, 20)
                self:CastSpell(player, ad.selectedSpell)
                enterState "cooldown"
            else -- error sounds
                sfx:Play(SoundEffect.SOUND_SOUL_PICKUP, 1, 2, false, 0.75)
                sfx:Play(SoundEffect.SOUND_BONE_BOUNCE, 1, 2, false, 2.25)
            end
        else
            enterState "fire"
        end
    end
    
    function states.reloading()
        ad.shouldReload = false
        ad.cancelReload = false
        ad.chargeTime = self.baseReloadTime + math.ceil((player.MaxFireDelay+1) * 0.5)
        ad.charge = 0
        
        self:EvaluateActionStats(player)
        
        sfx:Play(SoundEffect.SOUND_ULTRA_GREED_SLOT_STOP, 0.75, 2, false, 1.5)
        
        local kbMax = 20
        local function setKb()
            local ch = ad.charge
            if player:HasEntityFlags(EntityFlag.FLAG_INTERPOLATION_UPDATE) then ch = ch + 0.5 end
            ad.kickback = math.max(ad.kickback, math.min(ch * 4, kbMax))
        end
        while ad.charge < ad.chargeTime do
            coroutine.yield()
            if ad.cancelReload then
                ad.cancelReload = false
                sfx:Play(SoundEffect.SOUND_ULTRA_GREED_SLOT_STOP, 1, 2, false, 1.0)
                self:EvaluateActionStats(player)
                return
            end
            setKb()
            waitInterp()
            if ad.charge % 2 == 0 then
                sfx:Play(SoundEffect.SOUND_BUTTON_PRESS, 0.75, 2, false, 1.5 + (ad.charge / ad.chargeTime) * 1.1)
            end
            ad.charge = math.min(ad.charge + 1, ad.chargeTime)
            setKb()
        end
        
        ad.shouldReload = false
        sfx:Play(SoundEffect.SOUND_ULTRA_GREED_SLOT_STOP, 0.75, 2, false, 1.27)
        self:Reload(player)
        self:EvaluateActionStats(player)
    end
    
    function states.fire()
        local nf = self:GetBoltsPerTap(player)
        local hasLeadPencil = player:HasCollectible(CollectibleType.COLLECTIBLE_LEAD_PENCIL)
        
        for i = 1, nf do
            if ad.shouldReload then return end -- abort shot if reload triggered
            if not self:TryPayCosts(player, 1) then
                sfx:Play(SoundEffect.SOUND_BUTTON_PRESS, 1, 2, false, 1)
                sfx:Play(SoundEffect.SOUND_BONE_BOUNCE, 1, 2, false, 2.5)
                break
            end
            
            local ms = util.playerMultishot(player)
            if hasLeadPencil then
                if rand.rollFloat(1/15, player) then ms = ms + 11 end
            end
            --if ms > 1 then print("firing",ms,"tears") end
            local spread = math.min(math.max(0, ms-1) * 1.5, 5)
            local threshold = 5 -- max tears before switching from even fan to Monstro-style cluster
            for j = 1, ms do
                local ra = (Random() % 200 / 100) - 1
                if ms > 1 and ms <= threshold then -- even spread if under threshold
                    ra = (j-1)/(ms-1) * 2 - 1
                end
                local t = self:FireShot(player, shotTypes.normal, self:GetFireDirection(player):Rotated(ra * spread))
                if ms > threshold then -- velocity spread
                    local rv = Random() % 100 / 100
                    t.Velocity = t.Velocity * (1.0 - rv * 0.25)
                end
            end
            
            ad.kickback = 5
            self:SetFireHold(player, math.ceil((player.MaxFireDelay+1)*2 + 2))
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
        -- no firing if in an animation
        while util.IsIncapacitated(player) do coroutine.yield() end
        -- waiting for fire input
        if player.FireDelay >= 0 then -- if externally set firedelay,
            enterState "cooldown" -- enter cooldown
            buffered = ad.controls.fire -- but only start charging if holding as it ends
        elseif not ad.spellMenu and not ad.controls.map then
            chkBuf()
        end
        if buffered and not player:HasEntityFlags(EntityFlag.FLAG_INTERPOLATION_UPDATE) then
            buffered = false
            if not ad.controls.fire then
                enterState "fire"
            else -- charge
                enterState "charging"
            end
        end
        
        if ad.shouldReload then
            enterState "reloading"
            buffered = ad.controls.fire
        end
        
        coroutine.yield()
    end
end

function dryad:OnTakeDamage(e, amount, flags, source, inv)
    local player = e:ToPlayer()
    local ad = self:ActiveData(player)
    
    if ad.firingState == "reloading" then
        ad.cancelReload = true
    end
end

function dryad:OnCheckInput(player, hook, btn)
    if btn >= ButtonAction.ACTION_SHOOTLEFT and btn <= ButtonAction.ACTION_SHOOTDOWN then
        local ad = self:ActiveData(player)
        if hook == InputHook.IS_ACTION_PRESSED then
            if ad.spellMenu then return false end
            if ad.fireHold > 0 and ad.fireHoldActive then
                return btn == ad.fireHoldButton
            end
        elseif hook == InputHook.GET_ACTION_VALUE then
            if ad.fireHold > 0 and ad.fireHoldActive then
                return (btn == ad.fireHoldButton) and 1 or 0
            end
        end
    elseif btn == ButtonAction.ACTION_BOMB and hook == InputHook.IS_ACTION_TRIGGERED then
        return false -- disable normal bomb placement while retaining counter
    end
end

local fntNum = Font() fntNum:Load("font/pftempestasevencondensed.fnt")
local fntSmall = Font() fntSmall:Load("font/luaminioutlined.fnt")

function dryad:OnPostRender(player)
    if HudHelper.ShouldHideHUD() then return end
    local ad = self:ActiveData(player)
    local rd = self:RunData(player)
    local room = game:GetRoom()
    
    local WorldToScreen
    if not room:IsMirrorWorld() then WorldToScreen = Isaac.WorldToScreen
    else WorldToScreen = function(vec)
        local w = room:GetCenterPos().X * 2
        return room:WorldToScreenPosition(Vector(w - vec.X, vec.Y))
    end end
    
    if ad.firingState == "charging" or ad.firingState == "reloading" then -- charge bar
        if not ad.chargeBar then
            local cb = Sprite() ad.chargeBar = cb
            cb:Load("gfx/chargebar.anm2", true)
        end
        
        if ad.crossbowSprite and ad.crossbowSprite:Exists() then
            local pos = WorldToScreen(ad.crossbowSprite.Position + ad.crossbowSprite.SpriteOffset + Vector(0, -20)) + Vector(0.5, 0)
            
            HudHelper.RenderChargeBar(ad.chargeBar, ad.charge, ad.chargeTime, pos)
        end
    end
    
    -- ammo counter
    if ad.firingState ~= "reloading" and not ad.spellMenu then
        local str = rd.bolts .. "/" .. rd.boltsMax
        local wstr = rd.boltsMax .. "/" .. rd.boltsMax
        
        local tw = fntSmall:GetStringWidth(wstr)
        local lh = fntSmall:GetLineHeight()
        local fo = player.CanFly and 4 or 0 -- flying offset
        local pos = WorldToScreen(player.Position + Vector(0, -58 - fo))
        fntSmall:DrawString(str, pos.X - tw/2, pos.Y - lh, KColor(1,1,1,1), tw)
    end
end

do -- HUD block stuff
    local manaBar = Sprite()
    manaBar:Load("gfx/ui/apostasy/dryad.manabar.anm2", true)
    manaBar:SetFrame("Default", 1)
    
    local barEnd = 5
    local barWidth = 73 -- matches full row of hearts
    local intW = barWidth - (barEnd*2)
    local function rnd(n) return math.floor(n*2 + 0.5)/2 end
    local function getBarRegion(from, to)
        return Vector(rnd(barEnd + intW*from), 0), Vector(128 - barEnd - rnd(intW*to), 0)
    end
    
    local colNone = Color(1,1,1)
    local colHighlight = Color(1,1,1,1, 0.4, 0.2, 0.2)
    local colInsufficient = Color(1,1,1)
    colInsufficient:SetColorize(1.5, 0.25, 0.25, 1)
    
    dryad.HUDBlockHeight = 22
    function dryad:RenderHUDBlock(player, idx, layout, pos)
        --fntNum:DrawString("Hello world!", pos.X, pos.Y, KColor(1,1,1,1))
        local ad = self:ActiveData(player)
        
        local mana, manaMax = self:GetMana(player)
        local manaCost = self:GetSpellCost(player, ad.selectedSpell)
        
        local mbp = pos + Vector(-9, -5 - 3)
        manaBar.Color = colNone
        manaBar:RenderLayer(0, mbp)
        
        if mana >= manaCost then
            manaBar:RenderLayer(1, mbp, getBarRegion(0, mana / manaMax))
            manaBar.Color = colHighlight
            manaBar:RenderLayer(1, mbp, getBarRegion((mana-manaCost) / manaMax, mana / manaMax))
        else
            manaBar.Color = colInsufficient
            manaBar:RenderLayer(1, mbp, getBarRegion(0, mana / manaMax))
        end
        
        -- current spell info
        local tp = mbp + Vector(5, 15)
        fntSmall:DrawString(ad.selectedSpell.name or ad.selectedSpell.id, tp.X, tp.Y, KColor(1,1,1,1))
    end
end
