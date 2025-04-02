-- Character: The Seeker
-- working names: "Wisp Soul", "Spirit Lantern"

local Apostasy = _ENV["::Apostasy"]
local tableUtil = Apostasy:require "util.table"
local color = Apostasy:require "util.color"

local itemConfig = Isaac.GetItemConfig()
local game = Game()
local sfx = SFXManager()

local CHARACTER_NAME = "The Seeker"
local chr = Apostasy:RegisterCharacter(CHARACTER_NAME)

local function bflag(fd, fl) return fd & fl == fl end

local function wispType(e)
    if e.Type ~= 3 then return nil end
    if     e.Variant == 206 then return 1
    elseif e.Variant == 237 then return 2
    else return nil end
end

-- itemWisps: true for only, false for only not, nil for don't care
-- TODO still working on it
function chr:GetWispList(player, itemWisps)
    local ad = self:ActiveData(player)
    local wl = { }
    
    for k, wisp in pairs(ad.wispTracking) do
        if itemWisps == nil or itemWisps == (wisp.Variant == 237) then
            table.insert(wl, wisp)
        end
    end
    
    return wl
end

-- for when you want both lists separately
function chr:GetWispLists(player)
    local ad = self:ActiveData(player)
    local n, i = { }, { }
    
    for k, wisp in pairs(ad.wispTracking) do
        if wisp.Variant == 237 then table.insert(i, wisp)
        else table.insert(n, wisp) end
    end
    
    return n, i
end

-- re-fetch in case of reload
function chr:_ForceFetchWispList(player, ad)
    local ents = Isaac.GetRoomEntities()
    
    local wl = ad.wispTracking
    
    for i, ent in ipairs(ents) do
        if ent.Type == 3 then
            -- 206: normal, 237: item
            if ent.Variant == 206 or ent.Variant == 237 then
                local wisp = ent:ToFamiliar()
                if wisp.Player and wisp.Player.Index == player.Index and not wisp:IsDead() then
                    wl[wisp:GetData()] = wisp
                end
            end
        end
    end
    
    return wl
end

local wispTypes = { } do
    local c255 = color.from255
    local nullColor = Color(1,1,1)
    
    -- events:
    -- OnSpawn(wisp)
    -- OnFireTear(wisp, tear, isAutonomous, isGlamoured)
    
    -- plain old wisps
    wispTypes.normal = {
        tearColor = color.inverted {
            fill = c255 {105, 196, 255}, mult = 1.25,
            outline = c255 {231, 247, 255},
            bias = c255 {5, 5, 5},
        },
        maxHealth = 5,
        damageTransfer = 0.1,
    }
    
    local itemKeepChance = {
        [0] = 5,
        [1] = 10,
        [2] = 25,
        [3] = 50,
        [4] = 75,
    }
    -- picked up items as Lemegeton wisps
    wispTypes.item = {
        orbitLayer = -1, orbitSpeed = -1,
        tearColor = color.inverted {
            fill = c255 {166, 84, 242}, mult = 1.3,
            --outline = c255 {232, 175, 255},
            outline = c255 {231, 160, 255},
            bias = c255 {10, 10, 10},
        },
        
        OnDeath = function(wisp)
            local itm = itemConfig:GetCollectible(wisp.SubType)
            if itemKeepChance[itm.Quality] > (Random() % 10000)/100 then -- scaling chance per quality to keep
                local player = wisp.Player
                player:AddCollectible(wisp.SubType, 0, false) -- give it permanently but without one-time benefits
                Apostasy:QueueUpdateRoutine(function()
                    local i for i = 1,7 do coroutine.yield() end
                    sfx:Play(SoundEffect.SOUND_SOUL_PICKUP, 2)
                end)
            end
        end,
    }
    
    -- just big red drippy wisps with a ton of contact health but no tears?
    wispTypes.blood = {
        subtype = CollectibleType.COLLECTIBLE_BERSERK,
        orbitLayer = 1, orbitSpeed = -1.5,
        tearColor = color.inverted {
            fill = c255 {63, 0, 0},
            outline = c255 {225, 55, 55},
        },
        maxHealth = 12,
    }
    
    -- short range brimstone wisps
    wispTypes.brimstone = {
        subtype = CollectibleType.COLLECTIBLE_SULFUR,
        orbitLayer = -0.5, orbitSpeed = -1.5,
        tearColor = color.inverted {
            fill = c255 {127, 0, 0},
            outline = c255 {225, 55, 55},
        },
        maxHealth = 5,
    }
    
    -- holy homing tear wisps a la Sacred Heart
    wispTypes.holy = {
        subtype = CollectibleType.COLLECTIBLE_BIBLE,
        orbitLayer = -0.5, orbitSpeed = 1.5,
        tearColor = color.inverted {
            fill = c255 {245, 230, 200}, mult = 1.2,
            bias = c255 {5, 5, 5},
        },
        
        maxHealth = 7,
        damageTransfer = 0.333, -- these ones go hard thanks to their relative rarity
        
        OnFireTear = function(wisp, tear, isAutonomous, isGlamoured)
            tear:AddTearFlags(TearFlags.TEAR_HOMING) -- to match what this wisp variant does by default
        end,
    }
    
    -- bony wisps that spawn skeleton minions on break~
    wispTypes.bone = {
        subtype = CollectibleType.COLLECTIBLE_BOOK_OF_THE_DEAD,
        orbitLayer = 2, orbitSpeed = 1.75,
        tearColor = nullColor,
        tearVariant = TearVariant.BONE,
        
        maxHealth = 7,
    }
    
    wispTypes.gold = {
        -- could be magic fingers, portable slot or wooden nickel
        -- we're using this one because best balance of damage, health and coin chance
        subtype = CollectibleType.COLLECTIBLE_WOODEN_NICKEL,
        orbitLayer = 1.5, orbitSpeed = 0.75,
        tearColor = nullColor,
        tearVariant = TearVariant.COIN,
        
        maxHealth = 5,
        damageTransfer = 0.25, -- slightly stronger
        
        OnFireTear = function(wisp, tear, isAutonomous, isGlamoured)
            tear:AddTearFlags(TearFlags.TEAR_GREED_COIN) -- chance to drop coins on hit a la Head of the Keeper
        end,
    }
    
    -- reverse lookup table and the like
    local bySubtype = { } for id,wt in pairs(wispTypes) do
        if wt.subtype then bySubtype[wt.subtype] = wt end
        wt.id = id
    end
    
    function chr:GetWispType(w)
        local wt = wispType(w)
        if not wt then return nil end
        if wt == 2 then return wispTypes.item end
        local bs = bySubtype[w.SubType] if bs then
            return bs
        end
        return wispTypes.normal
    end
    
    -- accepted tear variants for theming
    -- false to not convert, otherwise specify variant
    local default = TearVariant.MYSTERIOUS
    local tearConversionTable = {
        [TearVariant.BLUE] = default,
        [TearVariant.BLOOD] = default,
        
        [TearVariant.PUPULA] = default,--false,
        [TearVariant.PUPULA_BLOOD] = default,--TearVariant.PUPULA,
        
        [TearVariant.MYSTERIOUS] = default,
    }
    
    -- theme a tear to whatever wisp is firing it
    function chr:HandleTearGlamour(w, tear, isAutonomous)
        -- only override if it's relatively normal tear type, or if it was fired autonomously
        if tearConversionTable[tear.Variant] ~= nil or isAutonomous then
            local wt = self:GetWispType(w)
            
            tear.Color = wt.tearColor or nullColor
            local v = wt.tearVariant or tearConversionTable[tear.Variant] or tear.Variant
            if tear.Variant ~= v then tear:ChangeVariant(v) end
            
            if wt.OnFireTear then wt.OnFireTear(w, tear, isAutonomous, true) end
        else
            --print("tear has unsupported variant:", tear.Variant)
            local wt = self:GetWispType(w)
            if wt.OnFireTear then wt.OnFireTear(w, tear, isAutonomous, false) end
        end
    end
end

local function onWispSpawned(wisp, wt)
    if not wt then wt = chr:GetWispType(wisp) end
    if wt.maxHealth then
        if wisp.HitPoints == wisp.MaxHitPoints then
            wisp.HitPoints = wt.maxHealth -- assume fresh
        end
        wisp.MaxHitPoints = wt.maxHealth
    end
    if wt.OnSpawn then wt.OnSpawn(wisp) end
end

local function onWispDeath(wisp, wt)
    if not wt then wt = chr:GetWispType(wisp) end
    if wt.OnDeath then wt.OnDeath(wisp) end
end

do
    -- kill the normal wisp with the lowest remaining health
    local function dmg(t)
        if not t[1] then return false end
        table.sort(t, function(a, b) return a.HitPoints < b.HitPoints end)
        t[1]:Kill()
        table.remove(t, 1)
        return true
    end
    
    local function qualityOf(w)
        return itemConfig:GetCollectible(w.SubType).Quality end
    -- kill a random item out of the lowest quality item wisps
    local function killLowestItem(t)
        if not t[1] then return end
        
        table.sort(t, function(a, b) -- sort list by quality, then within by remaining health
            local qa, qb = qualityOf(a), qualityOf(b)
            if qa == qb then return a.HitPoints < b.HitPoints end
            return qa < qb
        end)
        
        t[1]:Kill()
        table.remove(t, 1)
    end
    
    --- Breaks the according number of wisps, in order of priority.
    function chr:ApplyWispDamage(player, amount)
        local normalWisps, itemWisps = self:GetWispLists(player)
        
        while amount > 0 do
            local _ = dmg(normalWisps) or killLowestItem(itemWisps)
            amount = amount - 1
        end
        
        if not normalWisps[1] and not itemWisps[1] then
            player:Die() -- out of luck!
        end
        
        self:EvaluateWispStats(player)
    end
    
    --- Applies logic for a devil deal sacrifice; either three normal wisps or one item wisp.
    function chr:ApplyWispSacrifice(player)
        local normalWisps, itemWisps = self:GetWispLists(player)
        
        -- not enough normals but can sacrifice an item wisp
        if not normalWisps[3] and itemWisps[1] then
            killLowestItem(itemWisps)
        else -- can either afford normals, or can't afford at all
            local i
            for i = 1, 3 do dmg(normalWisps) end
        end
        
        -- and set up devil grace period
        if not normalWisps[1] and not itemWisps[1] then
            local ad = self:ActiveData(player)
            ad.devilGracePeriod = true
        end
        
        self:EvaluateWispStats(player)
    end
end

function chr:GiveWisps(player, amount, wt)
    if amount <= 0 then return nil end
    wt = wt or wispTypes.normal
    local i for i = 1, amount do
        player:AddWisp(wt.subtype or 0, player.Position, true)
    end
end

-- actually queues it for update later this frame
function chr:RearrangeWisps(player, frameDelay)
    local ad = self:ActiveData(player)
    if not ad._queuedRearrange then
        ad._queuedRearrange = true
        frameDelay = frameDelay or 0
        Apostasy:QueueUpdateRoutine(function()
            for frameDelay = frameDelay, 0 do
                coroutine.yield()
            end
            self:_RearrangeWisps(player)
            ad._queuedRearrange = nil
        end)
    end
end

local orbitVMult = Vector(1, 3/4)
local baseOrbit = 37
local orbitLMult = 14
local orbitSpeedMult = 0.0333 -- -0.01666
function chr:_RearrangeWisps(player) -- and this is where the magic happens~
    --print "reshuffling wisps"
    local wl = self:GetWispList(player)
    table.sort(wl, function(a, b) return a.Index < b.Index end) -- consistent order
    local ll = { }
    for _,w in pairs(wl) do -- separate into layers
        local l = self:GetWispType(w)
        if not ll[l] then ll[l] = {w}
        else table.insert(ll[l], w) end
    end
    for wt,wl in pairs(ll) do -- and shuffle offsets within each
        -- precalc the stuff
        local base = baseOrbit * player.Size * 0.1
        local orbitDist = orbitVMult * (base + orbitLMult * (wt.orbitLayer or 0))
        local orbitSpeed = orbitSpeedMult * (wt.orbitSpeed or 1)
        
        local wlc = #wl
        --print(wlc, "wisps of type", wt.id)
        local i for i = 1, wlc do
            local w = wl[i]
            --print("wisp of type:", wt.id, "layer:", w.OrbitLayer, "distance:", w.OrbitDistance, "speed:", w.OrbitSpeed) -- DEBUG
            
            -- distance proportion seems to be 4:3 naturally
            w.OrbitLayer = 573 -- reserved number, overridden
            w.OrbitDistance = orbitDist
            w.OrbitSpeed = orbitSpeed
            w.OrbitAngleOffset = (i-1) * math.pi*2 / wlc
        end
    end
end

function chr:ProcessHearts(player)
    local ad = self:ActiveData(player)
    
    local red = player:GetMaxHearts()
    local soul = player:GetSoulHearts() - 2
    local rotten = player:GetRottenHearts()
    local bone = player:GetBoneHearts()
    local eternal = player:GetEternalHearts()
    local gold = player:GetGoldenHearts()
    
    if soul == -1 then
        soul = 0
    elseif soul <= -2 then -- directly removed to no health at all? assume devil deal
        self:ApplyWispSacrifice(player) -- and process the sacrifice accordingly
        player:AddSoulHearts(2) -- don't die
        soul = 0
    end
    
    local total = red + soul + bone + eternal + gold
    if total > 0 then -- health update needed
        -- count up black hearts
        local black = 0
        local i
        for i = 0, 20 do if player:IsBlackHeart(i) then black = black + 1 end end
        
        -- reset actual health
        player:AddMaxHearts(-100)
        player:AddEternalHearts(-100)
        player:AddBoneHearts(-100)
        player:AddGoldenHearts(-100)
        player:AddSoulHearts(-100)
        player:AddSoulHearts(2)
        
        -- and give wisps accordingly:
        self:GiveWisps(player, math.ceil(soul/2) - black) -- we'll be a bit generous here
        self:GiveWisps(player, black, wispTypes.brimstone)
        self:GiveWisps(player, math.floor(red/2) * 3, wispTypes.blood)
        self:GiveWisps(player, eternal, wispTypes.holy)
        self:GiveWisps(player, bone, wispTypes.bone)
        self:GiveWisps(player, gold, wispTypes.gold)
        
        self:EvaluateWispStats(player)
    end
end

chr.WispItemBlacklist = tableUtil.flagMap {
    -- things that you probably want to keep on your actual self
    CollectibleType.COLLECTIBLE_BIRTHRIGHT,
    CollectibleType.COLLECTIBLE_MARBLES,
    CollectibleType.COLLECTIBLE_MITRE,
    
    -- not tagged summonable but might as well make sure
    CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES,
}

chr.WispItemWhitelist = tableUtil.flagMap {
    -- force enable a few things that aren't normally summonable,
    -- but kind of don't do anything to hold in your normal inventory
    CollectibleType.COLLECTIBLE_PAGEANT_BOY,
    CollectibleType.COLLECTIBLE_QUARTER,
    CollectibleType.COLLECTIBLE_DOLLAR,
    CollectibleType.COLLECTIBLE_BOX,
}

-- process item conversion
function chr:ConvertItemsToWisps(player)
    local ad = self:ActiveData(player)
    
    local check = ad.queuedItemsSeen
    ad.queuedItemsSeen = { } -- clear out
    
    for id in pairs(check) do
        local itm = itemConfig:GetCollectible(id)
        local num = player:GetCollectibleNum(id, true)
        
        if num > 0 and (bflag(itm.Tags, ItemConfig.TAG_SUMMONABLE) or self.WispItemWhitelist[id]) and not self.WispItemBlacklist[id] then
            player:AddItemWisp(id, player.Position, true)
            player:RemoveCollectible(id, true, ActiveSlot.SLOT_POCKET, false)
            gainedWisps = true
        end
    end
    
    self:EvaluateWispStats(player)
end

function chr:EvaluateWispStats(player) -- queue function
    local ad = self:ActiveData(player)
    if not ad._queuedEval then
        ad._queuedEval = true
        Apostasy:QueueUpdateRoutine(function()
            self:_EvaluateWispStats(player)
            ad._queuedEval = nil
        end)
    end
end
function chr:_EvaluateWispStats(player, inEval)
    player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
    player:EvaluateItems()
end

-- -- -- -- -- --- --- --- --- -- -- -- -- --
-- -- -- -- -- callbacks below -- -- -- -- --
-- -- -- -- -- --- --- --- --- -- -- -- -- --

function chr:OnInit(player)
    local ad = self:ActiveData(player)
    
    self:RearrangeWisps(player) -- kick this immediately
end

local function __count(l)
    local c = 0
    for _ in pairs(l) do c = c + 1 end
    return c
end

function chr:InitActiveData(player, ad)
    ad.wispCheckTimer = 1
    ad.itemCheckTimer = 1
    
    ad.queuedItemsSeen = { }
    ad.wispTracking = setmetatable({ }, { __mode = "k" }) -- weakly keyed
    
    -- for safety, assume reload
    self:_ForceFetchWispList(player, ad)
end

function chr:OnRoomClear(player, rng, spawnPos)
    local wl = self:GetWispList(player)
    if #wl < 3 then -- pinch recovery aid
        local sn = math.min(game:GetLevel():GetStage(), 3)
        if Random() % sn == 0 then -- 1 in (floor number) chance, up to 1/3 per room
            self:GiveWisps(player, 1)
        end
    end
end

function chr:OnFamiliarInit(fam)
    if not wispType(fam) then return end
    local player = fam.Player
    local ad = self:ActiveData(player)
    local key = fam:GetData()
    ad.wispTracking[key] = fam
    
    Apostasy:QueueUpdateRoutine(function() onWispSpawned(fam) end)
    self:RearrangeWisps(player)
    self:EvaluateWispStats(player)
end

function chr:OnFamiliarKilled(fam)
    if not wispType(fam) then return end
    fam = fam:ToFamiliar() -- coerce
    local player = fam.Player
    local ad = self:ActiveData(player)
    local key = fam:GetData()
    ad.wispTracking[key] = nil
    
    onWispDeath(fam)
    self:ActiveData(player).wispCheckTimer = 1
    self:RearrangeWisps(player)
    self:EvaluateWispStats(player)
end

function chr:OnUseItem(type, rng, player, flags, slot, data)
    if type == CollectibleType.COLLECTIBLE_LEMEGETON or player:HasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES) then
        -- used to be some logic here but we don't need it anymore
        -- keeping it in case we want to do something else later
    end
end

function chr:OnEvaluateCache(player, cacheFlag)
    local wispAttenuation = 0.0
    if cacheFlag == CacheFlag.CACHE_DAMAGE
    or cacheFlag == CacheFlag.CACHE_FIREDELAY then
        local normalWisps, itemWisps = self:GetWispLists(player)
        wispAttenuation = math.max(0, (#normalWisps-3) * .05 + #itemWisps * .075)
    end
    
    if cacheFlag == CacheFlag.CACHE_SPEED then
        -- being mostly made of energy makes you pretty fast
        -- thus, we give a *multiplier*
        player.MoveSpeed = player.MoveSpeed * 1.25
    elseif cacheFlag == CacheFlag.CACHE_DAMAGE then
        -- slightly reduced base damage, to compensate for the fire rate ramp-up
        -- we also taper off the damage roughly proportional to the fire rate increase but slightly less
        local div = 1.0 -- + wispAttenuation * 0.5
        player.Damage = (player.Damage - 0.25) / div
    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        -- more wisps, faster shots
        local div = 1.0 + wispAttenuation
        player.MaxFireDelay = (player.MaxFireDelay+1) / div - 1
    elseif cacheFlag == CacheFlag.CACHE_RANGE then
        -- this little wisp wants to be at a distance; bump up base range a bit for QoL
        player.TearRange = player.TearRange + 40 * 1.5 -- 20 == .5 on the counter?
    elseif cacheFlag == CacheFlag.CACHE_SIZE then
        self:RearrangeWisps(player) -- base orbit size is adjusted by player size
    end
end

function chr:OnEffectUpdate(player)
    --self:ProcessHearts(player)
end

function chr:OnUpdate(player)
    local ad = self:ActiveData(player)
    
    self:ProcessHearts(player)
    
    if not player:IsItemQueueEmpty() then
        local qd = player.QueuedItem
        local ic = qd.Item
        if ic:IsCollectible() then ad.queuedItemsSeen[ic.ID] = true end
        
        ad.itemCheckTimer = 1
    elseif ad.itemCheckTimer > 0 then
        ad.itemCheckTimer = ad.itemCheckTimer - 1
        if ad.itemCheckTimer == 0 then
            self:ConvertItemsToWisps(player)
        end
    end
    
    if ad.devilGracePeriod and not player:IsHoldingItem() then
        ad.devilGracePeriod = false
        ad.wispCheckTimer = 16 -- re-check after collection complete,
        -- giving just enough time for the animation to actually play
    end
    
    if ad.wispCheckTimer > 0 then
        ad.wispCheckTimer = ad.wispCheckTimer - 1
        
        if ad.wispCheckTimer == 0 then
            local wisps = self:GetWispList(player)
            if not wisps[1] and not ad.devilGracePeriod then
                player:Die() -- I has a dead
            end
        end
    end
end

local itmTranscendence -- cache it
function chr:OnRender(player)
    -- for now we have to do this every frame in case Transcendence happens to be gained and then lost
    if not itmTranscendence then -- force bodiless state using existing item
        itmTranscendence = itemConfig:GetCollectible(CollectibleType.COLLECTIBLE_TRANSCENDENCE)
    end   if itmTranscendence then player:AddCostume(itmTranscendence, false) end
end

function chr:OnTakeDamage(e, amount, flags, source, inv)
    local player = e:ToPlayer()
    player:AddSoulHearts(amount)
    
    if amount >= 1 and flags & DamageFlag.DAMAGE_FAKE == 0 then
        self:ApplyWispDamage(player, math.ceil(amount / 2))
    end
    
    -- replace hurt sound
    Apostasy:QueueUpdateRoutine(function()
        sfx:Stop(SoundEffect.SOUND_ISAAC_HURT_GRUNT)
        -- SOUND_POWERUP_SPEWER, pitch 4.2
        sfx:Play(SoundEffect.SOUND_SATAN_ROOM_APPEAR, 1, 0, false, 6.5)
    end)
    
    return true
end

function chr:OnFamiliarTakeDamage(fam, amount, flags, source, inv)
    if not wispType(fam) then return nil end -- only acting on wisps
    fam = fam:ToFamiliar()
    local player = fam.Player
    
    if amount >= fam.HitPoints then -- wisp dies from impact
        -- inv 10 for wisps, 30 for player
        player:TakeDamage(1, DamageFlag.DAMAGE_FAKE, source, 10) -- simulate hit
    end
end

function chr:OnPreFamiliarCollision(fam, with, low, var)
    local player = fam.Player
    if not wispType(fam) then return nil end -- only overriding wisps
    if with:ToProjectile() then
        return true -- don't block enemy shots
    end
end

function chr:OnPreProjectileCollisionWithFamiliar(tear, with, low, var)
    if not wispType(with) then return nil end -- only overriding wisps
    local fam = with:ToFamiliar()
    local player = fam.Player
    return true -- wisps don't block enemy shots
end

function chr:OnFireTear(tear)
    local player = tear.SpawnerEntity:ToPlayer()
    local ad = self:ActiveData(player)
    local wisps = self:GetWispList(player)
    
    if wisps[1] then -- we have wisps; our tears originate from them
        local w = wisps[(Random() % #wisps)+1]
        if wisps[2] then -- avoid firing from the same wisp twice in a row
            while w.Index == ad.lastTearSource do
                w = wisps[(Random() % #wisps)+1]
            end
        end
        ad.lastTearSource = w.Index
        
        -- set position to match
        tear.Position = w.Position
        
        -- and change its appearance accordingly
        self:HandleTearGlamour(w, tear)
    end
end

function chr:OnFamiliarFireTear(tear)
    local w = tear.SpawnerEntity:ToFamiliar()
    if not wispType(w) then return end
    
    self:HandleTearGlamour(w, tear, true)
    local wt = self:GetWispType(w)
    local dt = wt.damageTransfer or wispTypes.normal.damageTransfer
    if dt and dt > 0 then
        local player = w.Player
        -- calculate statwise relative dps
        local pfr = 30.0 / (player.MaxFireDelay+1)
        local wfr = 30.0 / (w.FireCooldown+1)
        local d = player.Damage * pfr/wfr
        tear.CollisionDamage = tear.CollisionDamage + (d * dt)
    end
end

function chr:OnPreHUDRenderHearts(offset, sprite, position, scale, player)
    return true -- don't render hearts HUD for this character
end
