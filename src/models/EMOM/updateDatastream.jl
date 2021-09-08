function updateDatastream!(
    mb    :: ModelBlock,
    clock :: ModelClock,
)
    cdatam     = mb.co.cdatam
    datastream = mb.tmpfi.datastream
    cfg        = mb.ev.config


    if cdatam != nothing

        interpData!(cdatam, clock.time, datastream)

        if cfg["MLD_scheme"] == "datastream"
            mb.fi.HMXL .= datastream["HMXL"]
        end

        # I added this check for it seems to cause
        # cice model to generate conservation error, or CFL instability
        # during QFLX finding run (strong weak-restoring cases).
        #=
        if haskey(datastream, "TEMP")
            _TEMP = datastream["TEMP"]
            for i=1:length(_TEMP)
                if _TEMP[i] < T_sw_frz
                    _TEMP[i] = T_sw_frz
                end
            end
        end 
        =#
    end

end
