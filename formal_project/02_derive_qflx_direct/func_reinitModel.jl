function reinitModel!(
    OMDATA , 
    data   :: Dict,
)
    println(size(OMDATA.x2o["SWFLX"]), size(data["SHF_QSW"]))

    cvtsT = (a,) -> reshape(a, 1, size(a)...)
    SHF     = cvtsT(data["SHF"])
    SHF_QSW = cvtsT(data["SHF_QSW"])
    SFWF    = cvtsT(data["SFWF"])
    TAUX    = cvtsT(data["TAUX"])
    TAUY    = cvtsT(data["TAUY"])
    HMXL    = cvtsT(data["HMXL"])


    @. OMDATA.x2o["SWFLX"]      = - SHF_QSW
    @. OMDATA.x2o["NSWFLX"]     = - (SHF - SHF_QSW)
    @. OMDATA.x2o["VSFLX"]      = SFWF
    @. OMDATA.x2o["TAUX_east"]  = TAUX / 10.0
    @. OMDATA.x2o["TAUY_north"] = TAUY / 10.0

    @. OMDATA.mb.fi.HMXL = HMXL / 100.0
    OMDATA.mb.fi.sv[:TEMP] .= data["TEMP"]
    OMDATA.mb.fi.sv[:SALT] .= data["SALT"]
end
