function updateDatastream!(
    mb    :: ModelBlock,
    clock :: ModelClock,
)
    cdatam     = mb.co.cdatam
    datastream = mb.fi.datastream
    cfg        = mb.ev.config


    if cdatam != nothing

        interpData!(cdatam, clock.time, datastream)

        if cfg[:MLD_scheme] == :datastream
            mb.fi.HMXL .= datastream["HMXL"]
        end
            

    end

end
