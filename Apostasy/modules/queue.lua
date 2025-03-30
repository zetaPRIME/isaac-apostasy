local Apostasy = _ENV["::Apostasy"]

do -- inserting this here for now
    local routineQueue = { }
    function Apostasy:QueueUpdateRoutine(f)
        f = coroutine.create(f)
        routineQueue[f] = true
    end
    
    Apostasy:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
        local nextQueue = { }
        for f in pairs(routineQueue) do
            coroutine.resume(f)
            if coroutine.status(f) ~= "dead" then nextQueue[f] = true end
        end routineQueue = nextQueue
    end)
end
