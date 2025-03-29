local Apostasy = _ENV["::Apostasy"]

do -- inserting this here for now
    local routineQueue = { }
    function Apostasy:QueueRoutine(f)
        f = coroutine.create(f)
        routineQueue[f] = true
    end
    
    Apostasy:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
        for f in pairs(routineQueue) do coroutine.resume(f) end
        if coroutine.status(f) == "dead" then routineQueue[f] = nil end
    end)
end
