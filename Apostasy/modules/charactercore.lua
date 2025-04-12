local Apostasy = _ENV["::Apostasy"]

local saveManager = Apostasy:require "lib.save_manager"

local NF = function() end -- null func

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
        local key = player:GetData()
        local ad = activeData[key]
        if not ad then
            ad = { }
            activeData[key] = ad
            self:InitActiveData(player, ad)
        end
        return ad
    end
    Character.InitActiveData = NF -- dummy
    
    Apostasy:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_INIT, CallbackPriority.IMPORTANT,
    function(_, player)
        activeData[player:GetData()] = nil
    end)
    
    local rdKey = "characterData"
    function Character:RunData(player, noHg)
        local rdr = saveManager.GetRunSave(player, noHg)
        local rd = rdr[rdKey]
        if not rd then
            rd = { }
            rdr[rdKey] = rd
            self:InitRunData(player, rd, noHg)
        end
        return rd
    end
    Character.InitRunData = NF -- dummy
end


do -- callback registration
    -- callback id, function name, test param number
    -- type = [string]
    -- priority = [num]
    local callbackRegistry = {
        {ModCallbacks.MC_POST_PLAYER_INIT, "OnInit", 1},
        {ModCallbacks.MC_EVALUATE_CACHE, "OnEvaluateCache", 1, priority = CallbackPriority.LATE * 5},
        
        {ModCallbacks.MC_FAMILIAR_INIT, "OnFamiliarInit", 1, type = "familiar", priority = CallbackPriority.LATE - 1},
        {ModCallbacks.MC_POST_ENTITY_KILL, "OnFamiliarKilled", 1, type = "familiar"},
        
        --{ModCallbacks.MC_POST_ENTITY_KILL, "OnEntityKilled", 1, type = "source"},
        
        {ModCallbacks.MC_POST_PEFFECT_UPDATE, "OnEffectUpdate", 1},
        {ModCallbacks.MC_POST_PLAYER_UPDATE, "OnUpdate", 1},
        {ModCallbacks.MC_POST_PLAYER_RENDER, "OnRender", 1},
        
        {ModCallbacks.MC_INPUT_ACTION, "OnCheckInput", 1},
        
        {ModCallbacks.MC_ENTITY_TAKE_DMG, "OnTakeDamage", 1, priority = CallbackPriority.LATE - 1},
        {ModCallbacks.MC_ENTITY_TAKE_DMG, "OnFamiliarTakeDamage", 1, type = "familiar", priority = CallbackPriority.LATE - 1},
        
        {ModCallbacks.MC_POST_FIRE_TEAR, "OnFireTear", 1, type = "source", priority = CallbackPriority.LATE},
        {ModCallbacks.MC_POST_LASER_INIT, "OnFireLaser", 1, type = "source"},
        --{ModCallbacks.MC_POST_LASER_UPDATE, "OnLaserUpdate", 1, type = "source"},
        {ModCallbacks.MC_USE_ITEM, "OnUseItem", 3},
        
        {ModCallbacks.MC_PRE_TEAR_COLLISION, "OnPreTearCollision", 1, type = "source"},
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
            local player = (par[pn])
            if not player then return nil end
            player = player:ToPlayer()
            if not player then return nil end
            local chr = byType[player:GetPlayerType()]
            local f = chr and chr[fname]
            if f then return f(chr, ...) end
        end)
    end
    
    function cbf:source(id, fname, pn)
        Apostasy:AddPriorityCallback(id, self.priority or 0, function(_, ...)
            local par = {...}
            local se = (par[pn]).SpawnerEntity
            local player = se and se:ToPlayer()
            if not player then return nil end
            local chr = byType[player:GetPlayerType()]
            local f = chr and chr[fname]
            if f then return f(chr, ...) end
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
            local f = chr and chr[fname]
            if f then return f(chr, ...) end
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
            local f = chr and chr[fname]
            if f then return f(chr, ...) end
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
    local f = chr and chr.OnFamiliarFireTear
    if f then return f(chr, tear) end
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
        local f = chr and chr.OnRoomClear
        if f then return f(chr, player, ...) end
    end
end)

-- PostRender (for just-under-HUD stuff)
Apostasy:AddPriorityCallback(ModCallbacks.MC_POST_RENDER, CallbackPriority.LATE, function(_, ...)
    local pl = getPlayers()
    for _, player in pairs(pl) do
        local chr = Apostasy:GetCharacterForPlayer(player)
        local f = chr and chr.OnPostRender
        if f then return f(chr, player, ...) end
    end
end)

if false and REPENTOGON then -- REPENTOGON only
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

HudHelper.RegisterHUDElement({
    Name = "apostasy:characterblock",
    Priority = HudHelper.Priority.HIGHEST,
    
    Condition = function(player, idx, layout)
        local chr = Apostasy:GetCharacterForPlayer(player)
        if chr and chr.RenderHUDBlock then return true end
        return false
    end,
    OnRender = function(player, idx, layout, pos)
        local chr = Apostasy:GetCharacterForPlayer(player)
        if chr and chr.RenderHUDBlock then
            return chr:RenderHUDBlock(player, idx, layout, pos)
        end
    end,
    YPadding = function(player, idx, layout)
        local chr = Apostasy:GetCharacterForPlayer(player)
        return chr.HUDBlockHeight or 32
    end,
    XPadding = 0,
}, HudHelper.HUDType.EXTRA)

-- -- -- -- --- --- --- --- --- --- -- -- -- --
-- -- -- -- -- utility functions -- -- -- -- --
-- -- -- -- --- --- --- --- --- --- -- -- -- --

do -- encapsulate
    local buttons = {
        move = false,
        moveLeft = ButtonAction.ACTION_LEFT,
        moveDown = ButtonAction.ACTION_DOWN,
        moveUp = ButtonAction.ACTION_UP,
        moveRight = ButtonAction.ACTION_RIGHT,
        
        fire = false,
        fireLeft = ButtonAction.ACTION_SHOOTLEFT,
        fireDown = ButtonAction.ACTION_SHOOTDOWN,
        fireUp = ButtonAction.ACTION_SHOOTUP,
        fireRight = ButtonAction.ACTION_SHOOTRIGHT,
        fireMouse = false,
        
        bomb = ButtonAction.ACTION_BOMB,
        item = ButtonAction.ACTION_ITEM,
        pocket = ButtonAction.ACTION_PILLCARD,
        drop = ButtonAction.ACTION_DROP,
    }
    
    function Character:QueryControls(player)
        local ad = self:ActiveData(player)
        local cid = player.ControllerIndex
        
        ad.controlsPrev = ad.controls or { }
        ad.controls = { }
        local c, cpv = ad.controls, ad.controlsPrev
        
        for k,v in pairs(buttons) do -- handle button queries
            if v then -- button action specified
                c[k] = Input.IsActionPressed(v, cid)
            end
        end
        
        -- set up combined actions
        c.move = c.moveLeft or c.moveDown or c.moveUp or c.moveRight
        c.fire = c.fireLeft or c.fireDown or c.fireUp or c.fireRight
        
        local fd = player:GetShootingInput()
        if Options.MouseControl and player.Index == 0 then -- TODO handle subplayer??
            local mb = Input.IsMouseBtnPressed(0)
            c.fireMouse = mb
            
            if mb then -- and now we need to figure out fire direction
                c.fire = true
                local mp = Input.GetMousePosition(true)
                fd = mp - player.Position
            end
        end
        
        c.fireDir = cpv.fireDir or Vector(0, 1)
        if fd:Length() > 0 then c.fireDir = fd:Normalized() end
        
        for k,v in pairs(buttons) do -- handle press and release
            c[k .. "P"] = c[k] and not cpv[k]
            c[k .. "R"] = cpv[k] and not c[k]
        end
        
        return ad.controls
    end
    
end
