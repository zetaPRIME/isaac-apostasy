local tu = { }

function tu.flagMap(t)
    local r = { }
    for _,v in pairs(t) do r[v] = true end
    return r
end

return tu
