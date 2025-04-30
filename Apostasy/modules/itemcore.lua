local Apostasy = _ENV["::Apostasy"]

local saveManager = Apostasy:require "lib.save_manager"

local util = Apostasy:require "util.misc"
local sleep = util.sleep

local Item = { } -- prototype

local byName = { }
local byIdItems = { }
local byIdTrinkets = { }

function Apostasy:RegisterItem(name)
    local itm = setmetatable({ }, { __index = Item })
    itm.name = name
    itm.id = Isaac.GetItemIdByName(name)
    
    byIdItems[itm.id] = itm
    byName[name] = itm
    return itm
end

function Apostasy:RegisterTrinket(name)
    local itm = setmetatable({ }, { __index = Item })
    itm.isTrinket = true
    itm.name = name
    itm.id = Isaac.GetTrinketIdByName(name)
    
    byIdTrinkets[itm.id] = itm
    byName[name] = itm
    return itm
end

function Apostasy:GetItem(p)
    local pt = type(p)
    if pt == "number" then return byIdItems[p] end
    if pt == "string" then return byName[p] end
    return nil
end

function Apostasy:GetTrinket(p)
    local pt = type(p)
    if pt == "number" then return byIdTrinkets[p] end
    if pt == "string" then return byName[p] end
    return nil
end

function Item:IsHeldBy(player, real, discrete)
    if self.isTrinket then return player:HasTrinket(self.id, real) end
    return player:HasCollectible(self.id, real, discrete)
end

function Item:NumHeldBy(player, real, discrete)
    if self.isTrinket then return player:GetTrinketMultiplier(self.id, real) end
    return player:GetCollectibleNum(self.id, real, discrete)
end

local forPlayer = setmetatable({ }, { __mode = "k" }) -- weakly keyed
local updQ = setmetatable({ }, { __mode = "k" })

function Apostasy:UpdateItemsFor(player)
    local pd = player:GetData()
    updQ[pd] = nil
    if not player:ToPlayer() or not player:Exists() then
        forPlayer[pd] = nil
    else
        player = player:ToPlayer()
        local l = { }
        for k,itm in pairs(byName) do
            if itm:IsHeldBy(player) then l[itm] = itm end
        end
        forPlayer[pd] = l
    end
end
function Apostasy:QueueUpdateItemsFor(player)
    local pd = player:GetData()
    if not updQ[pd] then
        updQ[pd] = true
        Apostasy:QueueUpdateRoutine(Apostasy.UpdateItemsFor, self, player)
    end
end






-- handle catching item wisps
Apostasy:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, function(_, fam)
    local player = fam.SpawnerEntity:ToPlayer()
    if not player then return end
    local itm = fam.SubType
    local pd = player:GetData()
    local l = forPlayer[pd]
    if not l then l = { } forPlayer[pd] = l end
    l[itm] = itm
end, FamiliarVariant.ITEM_WISP)

-- and removing
Apostasy:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, function(_, ent)
    if ent.Variant ~= FamiliarVariant.ITEM_WISP then return end
    Apostasy:QueueUpdateItemsFor(ent.SpawnerEntity:ToPlayer())
end, EntityType.ENTITY_FAMILIAR)

Apostasy:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, function(_, ent)
    if ent.Variant ~= FamiliarVariant.ITEM_WISP then return end
    Apostasy:QueueUpdateItemsFor(ent.SpawnerEntity:ToPlayer())
end, EntityType.ENTITY_FAMILIAR)

if REPENTOGON then -- set up our added/removed hooks
    Apostasy:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_INIT, CallbackPriority.LATE * 5, Apostasy.QueueUpdateItemsFor)
    
    Apostasy:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, function(_, id, charge, firstTime, slot, vdata, player)
        local itm = byIdItems[id]
        if itm then
            local pd = player:GetData()
            local l = forPlayer[pd]
            if not l then l = { } forPlayer[pd] = l end
            l[itm] = itm
        end
    end)
    
    Apostasy:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, function(_, player, id)
        local itm = byIdItems[id]
        if itm then
            Apostasy:QueueUpdateItemsFor(player)
        end
    end)
    
    Apostasy:AddCallback(ModCallbacks.MC_POST_TRIGGER_TRINKET_ADDED, function(_, player, id, firstTime)
        local itm = byIdTrinkets[id]
        if itm then
            local pd = player:GetData()
            local l = forPlayer[pd]
            if not l then l = { } forPlayer[pd] = l end
            l[itm] = itm
        end
    end)
    
    Apostasy:AddCallback(ModCallbacks.MC_POST_TRIGGER_TRINKET_REMOVED, function(_, player, id)
        local itm = byIdTrinkets[id]
        if itm then
            Apostasy:QueueUpdateItemsFor(player)
        end
    end)
else -- we get the Hacky Way for vanilla...
    local function playerTracking(player)
        while player:Exists() do
            Apostasy:UpdateItemsFor(player)
            sleep(10)
            if player.QueuedItem then
                local qi = player.QueuedItem
                for i = 1, 180 do -- limit sleep time
                    if not player.QueuedItem then break end
                    coroutine.yield()
                end
                if not player:Exists() then return end
                -- TODO trigger pickup routine
            end
        end
    end
    
    Apostasy:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_INIT, CallbackPriority.LATE * 5, function(_, player)
        Apostasy:QueueUpdateRoutine(playerTracking, player)
    end)
end

-- pick up players after a luamod
Apostasy:QueueUpdateRoutine(function()
    local pn = Game():GetNumPlayers()
    for i = 0, pn-1 do
        Apostasy:UpdateItemsFor(Isaac.GetPlayer(i))
    end
end)



-- TODO: split this kind of stuff out

do -- callback registration
    -- callback id, function name, test param number
    -- type = [string]
    -- priority = [num]
    local callbackRegistry = {
        --{ModCallbacks.MC_POST_PLAYER_INIT, "OnInit", 1},
        {ModCallbacks.MC_EVALUATE_CACHE, "OnEvaluateCache", 1},
        
        --{ModCallbacks.MC_FAMILIAR_INIT, "OnFamiliarInit", 1, type = "familiar", priority = CallbackPriority.LATE - 1},
        --{ModCallbacks.MC_POST_ENTITY_KILL, "OnFamiliarKilled", 1, type = "familiar"},
        
        --{ModCallbacks.MC_POST_ENTITY_KILL, "OnEntityKilled", 1, type = "source"},
        
        {ModCallbacks.MC_POST_PEFFECT_UPDATE, "OnEffectUpdate", 1},
        {ModCallbacks.MC_POST_PLAYER_UPDATE, "OnUpdate", 1},
        {ModCallbacks.MC_POST_PLAYER_RENDER, "OnRender", 1},
        
        --{ModCallbacks.MC_INPUT_ACTION, "OnCheckInput", 1},
        
        {ModCallbacks.MC_ENTITY_TAKE_DMG, "OnTakeDamage", 1},
        --{ModCallbacks.MC_ENTITY_TAKE_DMG, "OnFamiliarTakeDamage", 1, type = "familiar", priority = CallbackPriority.LATE - 1},
        
        {ModCallbacks.MC_POST_FIRE_TEAR, "OnFireTear", 1, type = "source", priority = CallbackPriority.LATE},
        {ModCallbacks.MC_POST_LASER_INIT, "OnFireLaser", 1, type = "source"},
        --{ModCallbacks.MC_POST_LASER_UPDATE, "OnLaserUpdate", 1, type = "source"},
        {ModCallbacks.MC_USE_ITEM, "OnUseItem", 3},
        
        --{ModCallbacks.MC_PRE_TEAR_COLLISION, "OnPreTearCollision", 1, type = "source"},
        --{ModCallbacks.MC_PRE_FAMILIAR_COLLISION, "OnPreFamiliarCollision", 1, type = "familiar"},
        --{ModCallbacks.MC_PRE_PROJECTILE_COLLISION, "OnPreProjectileCollisionWithFamiliar", 2, type = "familiar"},
        
        -- REPENTOGON only
        --{ModCallbacks.MC_PRE_PLAYERHUD_RENDER_HEARTS, "OnPreHUDRenderHearts", 5},
        --{ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS, "OnPostHUDRenderHearts", 5},
    }
    
    local function itemsFor(player)
        if not player then return { } end
        local pd = player:GetData()
        return forPlayer[pd] or { }
    end
    local function hasEntries(t)
        if not t then return false end
        for _ in pairs(t) do return true end
        return false
    end
    
    local cbf = { }
    function cbf:default(id, fname, pn)
        Apostasy:AddPriorityCallback(id, self.priority or 0, function(_, ...)
            local par = {...}
            local player = (par[pn])
            
            for itm in pairs(itemsFor(player)) do
                local f = itm[fname]
                if f then
                    local r = {f(itm, ...)}
                    if hasEntries(r) then return table.unpack(r) end
                end
            end
        end)
    end
    
    function cbf:source(id, fname, pn)
        Apostasy:AddPriorityCallback(id, self.priority or 0, function(_, ...)
            local par = {...}
            local se = (par[pn]).SpawnerEntity
            
            for itm in pairs(itemsFor(se)) do
                local f = itm[fname]
                if f then
                    local r = {f(itm, ...)}
                    if hasEntries(r) then return table.unpack(r) end
                end
            end
        end)
    end
    
    function cbf:familiar(id, fname, pn)
        Apostasy:AddPriorityCallback(id, self.priority or 0, function(_, ...)
            local par = {...}
            local fam = (par[pn]):ToFamiliar()
            if not fam then return nil end
            for itm in pairs(itemsFor(fam.Player)) do
                local f = itm[fname]
                if f then
                    local r = {f(itm, ...)}
                    if hasEntries(r) then return table.unpack(r) end
                end
            end
        end)
    end
    
    function cbf:familiarSource(id, fname, pn)
        Apostasy:AddPriorityCallback(id, self.priority or 0, function(_, ...)
            local par = {...}
            local se = (par[pn]).SpawnerEntity
            local fam = se and se:ToFamiliar()
            if not fam then return nil end
            for itm in pair(itemsFor(fam.Player)) do
                local f = itm[fname]
                if f then
                    local r = {f(itm, ...)}
                    if hasEntries(r) then return table.unpack(r) end
                end
            end
        end)
    end
    
    -- and set up callbacks
    for _, r in pairs(callbackRegistry) do
        if r[1] then -- don't error on missing REPENTOGON callbacks
            cbf[r.type or "default"](r, table.unpack(r))
        end
    end
end

-- Adds an EID description
function Item:AddDescription(desc)
    if not EID then return end
    if self.isTrinket then
        EID:addTrinket(self.id, desc)
    else
        EID:addCollectible(self.id, desc)
    end
end
