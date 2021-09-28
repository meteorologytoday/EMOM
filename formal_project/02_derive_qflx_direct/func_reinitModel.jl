function reinitModel!(
    OMDATA , 
    data   :: Dict;
    forcing :: Bool,
    thermal :: Bool,
    SOM_HMXL :: Union{Nothing, Float64} = nothing,
)
    cvtsT = (a,) -> reshape(a, 1, size(a)...)
    SHF     = cvtsT(data["SHF"])
    SHF_QSW = cvtsT(data["SHF_QSW"])
    SFWF    = cvtsT(data["SFWF"])
    TAUX    = cvtsT(data["TAUX"])
    TAUY    = cvtsT(data["TAUY"])
    HMXL    = cvtsT(data["HMXL"])

    if forcing
        @. OMDATA.x2o["SWFLX"]      = - SHF_QSW
        @. OMDATA.x2o["NSWFLX"]     = - (SHF - SHF_QSW)
        @. OMDATA.x2o["VSFLX"]      = SFWF
        @. OMDATA.x2o["TAUX_east"]  = TAUX / 10.0
        @. OMDATA.x2o["TAUY_north"] = TAUY / 10.0

        if SOM_HMXL == nothing
            @. OMDATA.mb.fi.HMXL = HMXL / 100.0
        else
            OMDATA.mb.fi.HMXL .= SOM_HMXL  # Ugly code: we pass in meters
        end
    end

    if thermal
        OMDATA.mb.fi.sv[:TEMP] .= data["TEMP"]
        OMDATA.mb.fi.sv[:SALT] .= data["SALT"]
    end
end
