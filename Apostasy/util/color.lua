local color = { }

function color.from255(c)
    return {c[1]/255, c[2]/255, c[3]/255}
end   local c255 = color.from255

function color.inverted(p)
    local c = Color(1,1,1)
    
    -- compensate for outlines not being quite white
    local bias = p.bias or c255 {10, 10, 10}
    
    local im = -(p.mult or 1.0)
    c:SetTint(im,im,im,1)
    
    local fc = p.fill
    local oc = p.outline or {1,1,1}
    
    c:SetColorize(oc[1] - fc[1], oc[2] - fc[2], oc[3] - fc[3], 1)
    c:SetOffset(oc[1]+bias[1], oc[2]+bias[2], oc[3]+bias[3])
    
    return c
end

return color
