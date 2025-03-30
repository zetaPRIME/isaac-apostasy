local Apostasy = _ENV["::Apostasy"]

local byId = { }
local byType = { }

local Character = { } -- prototype

function Apostasy:RegisterCharacter(name, tainted)
    local chr = setmetatable({ }, { __index = Character })
    chr.name = name
    chr.isTainted = tainted or false
    chr.type = Isaac.GetPlayerTypeByName(name, tainted)
    chr.id = name .. (tainted and ":tainted" or "")
    byType[chr.type] = chr
    byId[chr.id] = chr
    
    return chr
end

function Apostasy:GetCharacter(p)
    local pt = type(p)
    if pt == "string" then return byId[p] end
    if pt == "number" then return byType[p] end
    return nil
end

function Apostasy:GetCharacterForPlayer(player)
    player = player and player:ToPlayer()
    if not player then return nil end
    return byType[player:GetPlayerType()]
end

do
    local activeData = setmetatable({ }, { __mode = "k" }) -- weakly keyed
    function Character:ActiveData(player)
        local ad = activeData[player]
        if not ad then
            ad = { }
            activeData[player] = ad
            self:InitActiveData(player, ad)
        end
        return ad
    end
    function Character:InitActiveData() end -- dummy
    
    Apostasy:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_INIT, CallbackPriority.IMPORTANT,
    function(_, player)
        activeData[player] = nil
    end)
end

do -- callback registration
    local NF = function() end -- null func
    -- callback id, function name, test param number
    -- type = [string]
    -- priority = [num]
    local callbackRegistry = {
        {ModCallbacks.MC_POST_PLAYER_INIT, "OnInit", 1},
        {ModCallbacks.MC_EVALUATE_CACHE, "OnEvaluateCache", 1, priority = CallbackPriority.LATE * 5},
        
        {ModCallbacks.MC_FAMILIAR_INIT, "OnFamiliarInit", 1, type = "familiar", priority = CallbackPriority.LATE - 1},
        {ModCallbacks.MC_POST_ENTITY_KILL, "OnFamiliarKilled", 1, type = "familiar"},
        
        {ModCallbacks.MC_POST_PEFFECT_UPDATE, "OnEffectUpdate", 1},
        {ModCallbacks.MC_POST_PLAYER_UPDATE, "OnUpdate", 1},
        {ModCallbacks.MC_POST_PLAYER_RENDER, "OnRender", 1},
        
        {ModCallbacks.MC_ENTITY_TAKE_DMG, "OnTakeDamage", 1, priority = CallbackPriority.LATE - 1},
        {ModCallbacks.MC_ENTITY_TAKE_DMG, "OnFamiliarTakeDamage", 1, type = "familiar", priority = CallbackPriority.LATE - 1},
        
        {ModCallbacks.MC_POST_FIRE_TEAR, "OnFireTear", 1, type = "source", priority = CallbackPriority.LATE},
        {ModCallbacks.MC_POST_LASER_INIT, "OnFireLaser", 1, type = "source"},
        --{ModCallbacks.MC_POST_LASER_UPDATE, "OnLaserUpdate", 1, type = "source"},
        {ModCallbacks.MC_USE_ITEM, "OnUseItem", 3},
        
        {ModCallbacks.MC_PRE_FAMILIAR_COLLISION, "OnPreFamiliarCollision", 1, type = "familiar"},
        {ModCallbacks.MC_PRE_PROJECTILE_COLLISION, "OnPreProjectileCollisionWithFamiliar", 2, type = "familiar"},
        
        -- REPENTOGON only
        {ModCallbacks.MC_PRE_PLAYERHUD_RENDER_HEARTS, "OnPreHUDRenderHearts", 5},
        {ModCallbacks.MC_POST_PLAYERHUD_RENDER_HEARTS, "OnPostHUDRenderHearts", 5},
    }
    
    local cbf = { }
    function cbf:default(id, fname, pn)
        Apostasy:AddPriorityCallback(id, self.priority or 0, function(_, ...)
            local par = {...}
            local player = (par[pn]):ToPlayer()
            if not player then return nil end
            local chr = byType[player:GetPlayerType()]
            if chr and chr[fname] then return (chr[fname])(chr, ...) end
        end)
    end
    
    function cbf:source(id, fname, pn)
        Apostasy:AddPriorityCallback(id, self.priority or 0, function(_, ...)
            local par = {...}
            local se = (par[pn]).SpawnerEntity
            local player = se and se:ToPlayer()
            if not player then return nil end
            local chr = byType[player:GetPlayerType()]
            if chr and chr[fname] then return (chr[fname])(chr, ...) end
        end)
    end
    
    function cbf:familiar(id, fname, pn)
        Apostasy:AddPriorityCallback(id, self.priority or 0, function(_, ...)
            local par = {...}
            local fam = (par[pn]):ToFamiliar()
            if not fam then return nil end
            local player = fam.Player
            if not player then return nil end
            local chr = byType[player:GetPlayerType()]
            if chr and chr[fname] then return (chr[fname])(chr, ...) end
        end)
    end
    
    function cbf:familiarSource(id, fname, pn)
        Apostasy:AddPriorityCallback(id, self.priority or 0, function(_, ...)
            local par = {...}
            local se = (par[pn]).SpawnerEntity
            local fam = se and se:ToFamiliar()
            if not fam then return nil end
            local player = fam.Player
            if not player then return nil end
            local chr = byType[player:GetPlayerType()]
            if chr and chr[fname] then return (chr[fname])(chr, ...) end
        end)
    end
    
    -- and set up callbacks
    for _, r in pairs(callbackRegistry) do
        if r[1] then -- don't error on missing REPENTOGON callbacks
            cbf[r.type or "default"](r, table.unpack(r))
        end
    end
end

-- and some special callbacks

-- OnFamiliarFireTear
Apostasy:AddPriorityCallback(ModCallbacks.MC_POST_TEAR_UPDATE, CallbackPriority.LATE, function(_, tear)
    if tear.FrameCount > 1 then return end
    local fam = tear.SpawnerEntity and tear.SpawnerEntity:ToFamiliar()
    if not fam then return end
    local player = fam.Player
    if not player then return end
    local chr = byType[player:GetPlayerType()]
    if chr and chr.OnFamiliarFireTear then return chr:OnFamiliarFireTear(tear) end
end)


local game = Game()
local function getPlayers()
    local r = { }
    local pn = game:GetNumPlayers()
    local i for i = 0, pn-1 do
        table.insert(r, Isaac.GetPlayer(i))
    end
    return r
end

-- OnRoomClear
Apostasy:AddPriorityCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, CallbackPriority.EARLY, function(_, ...)
    local pl = getPlayers()
    for _, player in pairs(pl) do
        local chr = Apostasy:GetCharacterForPlayer(player)
        if chr and chr.OnRoomClear then chr:OnRoomClear(player, ...) end
    end
end)

if false and ModCallbacks.MC_HUD_RENDER then -- REPENTOGON only
    Apostasy:AddCallback(ModCallbacks.MC_HUD_RENDER, function()
        local pl = getPlayers()
        for _, player in pairs(pl) do
            local chr = Apostasy:GetCharacterForPlayer(player)
            if chr and chr.OnHUDRender then chr:OnHUDRender(player) end
        end
    end)
    
    Apostasy:AddCallback(ModCallbacks.MC_POST_HUD_RENDER, function()
        local pl = getPlayers()
        for _, player in pairs(pl) do
            local chr = Apostasy:GetCharacterForPlayer(player)
            if chr and chr.OnPostHUDRender then chr:OnPostHUDRender(player) end
        end
    end)
end
