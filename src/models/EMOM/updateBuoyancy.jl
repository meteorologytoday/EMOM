function updateBuoyancy!(
    mb :: ModelBlock
)

    _b    = mb.fi._b
    _TEMP = mb.fi.sv[:_TEMP]
    _SALT = mb.fi.sv[:_SALT]

    @. _b = TS2b(_TEMP, _SALT)

end
