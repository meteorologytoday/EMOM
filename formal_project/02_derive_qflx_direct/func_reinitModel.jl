function reinitModel!(
    OMDATA , 
    data   :: Dict,
)
    @. OMDATA.x2o["SWFLX"]      = - data["SHF_QSW"]
    @. OMDATA.x2o["NSWFLX"]     = - (data["SHF"] - data["SHF_QSW"])
    @. OMDATA.x2o["VSFLX"]      = data["SFWF"]
    @. OMDATA.x2o["TAUX_east"]  = data["TAUX"] / 10.0
    @. OMDATA.x2o["TAUX_north"] = data["TAUY"] / 10.0
    @. OMDATA.x2o["HMXL"]       = data["HMXL"] / 100.0

    OMDATA.mb.fi.sv[:TEMP] .= data["TEMP"]
    OMDATA.mb.fi.sv[:SALT] .= data["SALT"]
end
