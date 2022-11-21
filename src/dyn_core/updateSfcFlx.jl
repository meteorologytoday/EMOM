
function updateSfcFlx!(
    mb    :: ModelBlock;
)
    fi = mb.fi
    @. fi.NSWFLX = fi.LWUP + fi.LWDN + fi.SEN + fi.LAT + fi.MELTH - (fi.SNOW + fi.IOFF) * Hf_sw
    @. fi.VSFLX  = fi.SALTFLX - ( fi.EVAP + fi.PREC + fi.MELTW + fi.ROFF + fi.IOFF ) * S_vsref / ρ_fw
end
