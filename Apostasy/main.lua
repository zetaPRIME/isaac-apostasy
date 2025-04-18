local Apostasy = RegisterMod("Apostasy", 1)
_ENV["::Apostasy"] = Apostasy

do -- we're rolling our own require() because Nicalis Code
    local req = { }
    Apostasy[":req"] = req
    function Apostasy:require(file)
        if req[file] then return table.unpack(req[file]) end
        local r = {include(file)}
        req[file] = r
        return table.unpack(r)
    end
end

-- init libraries
Apostasy:require "lib.hud_helper"
Apostasy:require("lib.save_manager").Init(Apostasy)

-- pull in utilities
for _,k in pairs {
    "Color",
    "Table",
    "Random",
} do end--Apostasy[k] = Apostasy:require("util." .. k:lower()) end

-- functional modules
Apostasy:require "modules.queue"
Apostasy:require "modules.charactercore"

-- at end: list of all included content files
Apostasy:require "content"
