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

Apostasy:require "charactercore"

-- at end: list of all included content files
Apostasy:require "content"
