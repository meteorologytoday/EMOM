
function updateSfcFlx!(
    mb    :: ModelBlock;
)
    fi = mb.fi
    @. fi.NSWFLX = fi.LWUP + fi.LWDN + fi.SEN + fi.LAT + fi.MELTH - (fi.SNOW + fi.IOFF) * Hf_sw
    
    # This is a bug found 11/21/2022
    @. fi.VSFLX  = 0.0
    # I did not send freshwater flux into the slave cores
    # In near future the correct one should be 
    # @. fi.VSFLX  = fi.SALTFLX - ( fi.EVAP + fi.PREC + fi.MELTW + fi.ROFF + fi.IOFF ) * S_vsref / ρ_fw
end
