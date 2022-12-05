function updateDatastream!(
    mb    :: ModelBlock,
    clock :: ModelClock,
)
    cdatams     = mb.co.cdatams
    datastream  = mb.tmpfi.datastream
    cfg_core    = mb.ev.cfgs["MODEL_CORE"]


    if length(cdatams) > 0
        
        print("Current time: ", clock.time)
        for (varname, cdatam) in cdatams 
            interpData!(cdatam, clock.time, datastream[varname])
        end

        if cfg_core["MLD_scheme"] == "datastream"
            mb.fi.HMXL .= datastream["HMXL"]["HMXL"]
        end
        
        if cfg_core["UVSFC_scheme"] == "datastream"
            mb.fi.USFC .= datastream["USFC"]["USFC"]
            mb.fi.VSFC .= datastream["VSFC"]["VSFC"]
        elseif cfg_core["UVSFC_scheme"] == "off"
            mb.fi.USFC .= 0.0
            mb.fi.VSFC .= 0.0
        end
 
        if cfg_core["Qflx"] == "on"
            mb.fi._QFLXX_[:, 1] .= reshape(datastream["QFLXT"]["QFLXT"], :)
            mb.fi._QFLXX_[:, 2] .= reshape(datastream["QFLXS"]["QFLXS"], :)
        elseif cfg_core["Qflx"] == "off"
            mb.fi._QFLXX_ .= 0.0
        end

    end

end
