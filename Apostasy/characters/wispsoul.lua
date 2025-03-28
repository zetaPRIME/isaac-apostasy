-- Character: The Seeker
-- working names: "Wisp Soul", "Spirit Lantern"

local Apostasy = _ENV["::Apostasy"]
local tableUtil = Apostasy:require "util.table"
local color = Apostasy:require "util.color"

local itemConfig = Isaac.GetItemConfig()

local CHARACTER_NAME = "The Seeker"
local chr = Apostasy:RegisterCharacter(CHARACTER_NAME)

local function wispType(e)
    if e.Type ~= 3 then return nil end
    if     e.Variant == 206 then return 1
    elseif e.Variant == 237 then return 2
    else return nil end
end

-- itemWisps: true for only, false for only not, nil for don't care
local function getWispsFor(player, itemWisps)
    local ents = Isaac.GetRoomEntities()
    
    local wl = { }
    
    for i, ent in ipairs(ents) do
        if ent.Type == 3 then
            -- 206: normal, 237: item
            if (ent.Variant == 206 and itemWisps ~= true) or (ent.Variant == 237 and itemWisps ~= false) then
                local wisp = ent:ToFamiliar()
                if wisp.Player and wisp.Player.Index == player.Index and not wisp:IsDead() then
                    table.insert(wl, wisp)
                end
            end
        end
        --print(ent.Type, ent.Variant, ent.SubType)
    end
    
    return wl
end

local tearColors = { } do
    local c255 = color.from255
    
    tearColors.null = Color(1,1,1)
    tearColors.normal = color.inverted {
        fill = c255 {105, 196, 255}, mult = 1.25,
        outline = c255 {231, 247, 255},
        bias = c255 {5, 5, 5},
    }
    
    tearColors.item = color.inverted {
        fill = c255 {166, 84, 242}, mult = 1.3,
        --outline = c255 {232, 175, 255},
        outline = c255 {231, 160, 255},
        bias = c255 {10, 10, 10},
    }
    
    tearColors.blood = color.inverted {
        fill = c255 {63, 0, 0},
        outline = c255 {225, 55, 55},
    }
    
    tearColors.brimstone = color.inverted {
        fill = c255 {127, 0, 0},
        outline = c255 {225, 55, 55},
    }
    
    tearColors.holy = color.inverted {
        fill = c255 {245, 230, 200}, mult = 1.2,
        bias = c255 {5, 5, 5},
    }
end

local function getTearColorForWisp(w)
    if wispType(w) == 2 then
        return tearColors.item
    end
    
    if w.SubType == CollectibleType.COLLECTIBLE_BERSERK then -- blood wisps
        return tearColors.blood
    elseif w.SubType == CollectibleType.COLLECTIBLE_SULFUR then -- brim wisps
        return tearColors.brimstone
    elseif w.SubType == CollectibleType.COLLECTIBLE_BIBLE then -- holy wisp
        return tearColors.holy
    elseif w.SubType == CollectibleType.COLLECTIBLE_BOOK_OF_THE_DEAD then -- bone wisps
        return tearColors.null, TearVariant.BONE
    end
    
    return tearColors.normal
end

do
    local function dmg(t)
        if not t[1] then return false end
        local i = (Random() % #t) + 1
        t[i]:Kill()
        table.remove(t, i)
        return true
    end
    
    -- kill a random item out of the lowest quality item wisps
    local function killLowestItem(t)
        if not t[1] then return end
        local lowest = 15
        local ll = { }
        local rev = { }
        for idx,w in pairs(t) do -- iterate through wisps
            local itm = itemConfig:GetCollectible(w.SubType)
            lowest = math.min(lowest, itm.Quality)
            if not ll[itm.Quality] then ll[itm.Quality] = {w}
            else table.insert(ll[itm.Quality], w) end
            rev[w] = idx
        end
        local lt = ll[lowest]
        local i = (Random() % #lt) + 1
        local w = lt[i]
        w:Kill()
        table.remove(t, rev[w])
    end
    
    --- Breaks the according number of wisps, in order of priority.
    function chr:ApplyWispDamage(player, amount)
        local normalWisps = getWispsFor(player, false)
        local itemWisps = getWispsFor(player, true)
        
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
        local normalWisps = getWispsFor(player, false)
        local itemWisps = getWispsFor(player, true)
        
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

function chr:GiveWisps(player, amount, type)
    if amount <= 0 then return nil end
    local i
    for i = 1, amount do
        player:AddWisp(type or 0, player.Position, true)
    end
end

chr.WispItemBlacklist = tableUtil.flagMap {
    CollectibleType.COLLECTIBLE_BIRTHRIGHT,
    CollectibleType.COLLECTIBLE_MARBLES,
    
    -- not tagged summonable but might as well make sure
    CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES,
}

chr.WispItemWhitelist = tableUtil.flagMap {
    -- force enable a few things that aren't normally summonable,
    -- but kind of don't do anything to hold in your normal inventory
    CollectibleType.COLLECTIBLE_PAGEANT_BOY,
    CollectibleType.COLLECTIBLE_QUARTER,
    CollectibleType.COLLECTIBLE_DOLLAR,
}

local function bflag(fd, fl) return fd & fl == fl end

-- process item conversion
function chr:ConvertItemsToWisps(player)
    local ad = self:ActiveData(player)
    
    local check = ad.queuedItemsSeen
    ad.queuedItemsSeen = { } -- clear out
    
    -- if REPENTOGON is installed, grab the full list from it
    if player.GetCollectiblesList then check = player:GetCollectiblesList() end
    
    for id in pairs(check) do
        local itm = itemConfig:GetCollectible(id)
        local num = player:GetCollectibleNum(id, true)
        
        if num > 0 and (bflag(itm.Tags, ItemConfig.TAG_SUMMONABLE) or self.WispItemWhitelist[id]) and not self.WispItemBlacklist[id] then
            local i
            for i = 1, num do
                player:AddItemWisp(id, player.Position, true)
                player:RemoveCollectible(id, true, ActiveSlot.SLOT_POCKET, false)
            end
        end
    end
    
    self:EvaluateWispStats(player)
end

function chr:EvaluateWispStats(player, inEval)
    if inEval then
        local ad = self:ActiveData(player)
        ad.wispCheckTimer = math.max(ad.wispCheckTimer, 1)
        return
    end
    player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
    player:EvaluateItems()
end

-- -- -- -- -- --- --- --- --- -- -- -- -- --
-- -- -- -- -- callbacks below -- -- -- -- --
-- -- -- -- -- --- --- --- --- -- -- -- -- --

function chr:OnInit(player)
    local ad = self:ActiveData(player)
    
    --player:AddWisp(0, player.Position)
end

function chr:InitActiveData(player, ad)
    ad.wispCheckTimer = 1
    ad.itemCheckTimer = 1
    
    ad.queuedItemsSeen = { }
end

function chr:OnEvaluateCache(player, cacheFlag)
    local wispAttenuation = 0.0
    if cacheFlag == CacheFlag.CACHE_DAMAGE
    or cacheFlag == CacheFlag.CACHE_FIREDELAY then
        local normalWisps = getWispsFor(player, false)
        local itemWisps = getWispsFor(player, true)
        wispAttenuation = (#normalWisps-3) * .05 + #itemWisps * .075
    end
    
    if cacheFlag == CacheFlag.CACHE_SPEED then
        -- being mostly made of energy makes you pretty fast
        -- thus, we give a *multiplier*
        player.MoveSpeed = player.MoveSpeed * 1.25
    elseif cacheFlag == CacheFlag.CACHE_DAMAGE then
        -- slightly reduced base damage, to compensate for the fire rate ramp-up
        -- we also taper off the damage roughly proportional to the fire rate increase but slightly less
        local div = 1.0 + wispAttenuation * 0.666
        player.Damage = (player.Damage - 0.5) / div
    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        -- more wisps, faster shots
        local div = 1.0 + wispAttenuation
        player.MaxFireDelay = player.MaxFireDelay / div
    elseif cacheFlag == CacheFlag.CACHE_FAMILIARS then
        self:EvaluateWispStats(player, true)
    end
end

function chr:OnUpdate(player)
    local ad = self:ActiveData(player)
    
    local red = player:GetMaxHearts()
    local soul = player:GetSoulHearts() - 2
    local rotten = player:GetRottenHearts()
    local bone = player:GetBoneHearts()
    local eternal = player:GetEternalHearts()
    
    if soul == -1 then
        player:AddSoulHearts(1)
        soul = 0
    elseif soul <= -2 then -- directly removed to no health at all? assume devil deal
        player:AddSoulHearts(2)
        soul = 0
        self:ApplyWispSacrifice(player) -- we'll just assume so
    end
    
    local total = red + soul + bone + eternal
    if total > 0 then -- health update needed
        -- count up black hearts
        local black = 0
        local i
        for i = 0, 20 do if player:IsBlackHeart(i) then black = black + 1 end end
        
        -- reset actual health
        player:AddMaxHearts(-100)
        player:AddEternalHearts(-100)
        player:AddBoneHearts(-100)
        player:AddSoulHearts(-100)
        player:AddSoulHearts(2)
        
        -- and give wisps accordingly:
        
        -- plain old wisps
        self:GiveWisps(player, math.floor(soul/2) - black)
        -- short range brimstone wisps
        self:GiveWisps(player, black, CollectibleType.COLLECTIBLE_SULFUR)
        -- just big red drippy wisps with a ton of contact health but no tears?
        self:GiveWisps(player, math.floor(red/2), CollectibleType.COLLECTIBLE_BERSERK)
        -- holy homing tear wisps a la Sacred Heart
        self:GiveWisps(player, eternal, CollectibleType.COLLECTIBLE_BIBLE)
        -- bony wisps that spawn skeleton minions on break~
        self:GiveWisps(player, bone, CollectibleType.COLLECTIBLE_BOOK_OF_THE_DEAD)
        
        self:EvaluateWispStats(player)
        
    elseif total < 0 then -- negative health??
        -- hmm.
    end
    
    
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
            local wisps = getWispsFor(player)
            if not wisps[1] then
                player:Die() -- I has a dead
            end
            
            -- force update wisp modifiers
            self:EvaluateWispStats(player)
        end
    end
end

function chr:OnTakeDamage(e, amount, flags, source, inv)
    local player = e:ToPlayer()
    player:AddSoulHearts(amount)
    
    self:ApplyWispDamage(player, math.ceil(amount / 2))
    
    return true
end

function chr:OnFamiliarTakeDamage(e, amount, flags, source, inv)
    if not wispType(e) then return nil end -- only acting on wisps
    local fam = e:ToFamiliar()
    local player = fam.Player
    self:ActiveData(player).wispCheckTimer = 3
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

function chr:OnUseItem(type, rng, player, flags, slot, data)
    if type == CollectibleType.COLLECTIBLE_LEMEGETON or player:HasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES) then
        local ad = self:ActiveData(player)
        self:EvaluateWispStats(player, true) -- kick wisp updates
        ad.wispCheckTimer = math.max(ad.wispCheckTimer, 5)
        --print("spawning an wisp")
    end
end

do
    -- accepted tear variants for theming
    -- false to not convert, otherwise specify variant
    local default = TearVariant.MYSTERIOUS
    chr.TearConversionTable = {
        [TearVariant.BLUE] = default,
        [TearVariant.BLOOD] = default,
        
        [TearVariant.PUPULA] = default,--false,
        [TearVariant.PUPULA_BLOOD] = default,--TearVariant.PUPULA,
    }
end

function chr:OnFireTear(tear)
    local player = tear.SpawnerEntity:ToPlayer()
    local ad = self:ActiveData(player)
    local wisps = getWispsFor(player)
    
    if wisps[1] then -- we have wisps; our tears originate from them
        local w = wisps[(Random() % #wisps)+1]
        if wisps[2] then -- avoid firing from the same wisp twice in a row
            while w.Index == ad.lastTearSource do
                w = wisps[(Random() % #wisps)+1]
            end
        end
        ad.lastTearSource = w.Index
        
        tear.Position = w.Position
        
        -- relatively normal tear type, theme it to the wisp firing
        if self.TearConversionTable[tear.Variant] ~= nil then
            local c, v = getTearColorForWisp(w)
            v = v or self.TearConversionTable[tear.Variant] or tear.Variant
            
            tear.Color = c
            if tear.Variant ~= v then tear:ChangeVariant(v) end
        end
        
    end
end

function chr:OnFireLaserAAA(laser)
    --if not laser.FirstUpdate then return nil end
    --print("laser firing")
    local player = laser.SpawnerEntity:ToPlayer()
    local wisps = getWispsFor(player)
    
    if wisps[1] then -- we have wisps
        --print("we have wisps")
        local w = wisps[(Random() % #wisps)+1]
        --laser.Position = w.Position
    end
end

function chr:OnPreHUDRenderHearts(offset, sprite, position, scale, player)
    return true -- don't render hearts HUD for this character
end
