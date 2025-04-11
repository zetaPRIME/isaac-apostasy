local Apostasy = _ENV["::Apostasy"]

do
    local routineQueue = { }
    function Apostasy:QueueUpdateRoutine(f, ...)
        f = coroutine.create(f)
        routineQueue[f] = {...}
    end
    
    Apostasy:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
        local nextQueue = { }
        for f, par in pairs(routineQueue) do
            if par then
                coroutine.resume(f, table.unpack(par))
            else coroutine.resume(f) end
            if coroutine.status(f) ~= "dead" then nextQueue[f] = false end
        end routineQueue = nextQueue
    end)
end
