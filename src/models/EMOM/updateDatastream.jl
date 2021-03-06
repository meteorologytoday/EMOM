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
        
        if cfg["Qflx"] == "on"
            mb.fi._QFLXX_[:, 1] .= reshape(datastream["QFLXT"], :)
            mb.fi._QFLXX_[:, 2] .= reshape(datastream["QFLXS"], :)
        end

    end

end
