mutable struct Env

    config :: Dict
    
    sub_yrng :: Union{UnitRange, Colon, Nothing}
    Nx :: Integer
    Ny :: Integer
    Nz :: Integer

    cdata_varnames :: AbstractArray{String}

    function Env(
        config;
        sub_yrng = nothing,
    )
       
        writeLog("Validating config: :MODEL_CORE") 
        config = validateConfigEntries(config, getConfigDescriptor()[:MODEL_CORE]) 
           
        # mask =>   lnd = 0, ocn = 1
        gf = PolelikeCoordinate.CurvilinearSphericalGridFile(
            config[:domain_file];
            R  = 6371229.0,
            Ω  = 2π / (86400 / (1 + 365/365)),
        )

        Nx = gf.Nx
        Ny = (sub_yrng == nothing) ? gf.Ny : length(sub_yrng)
        Nz = length(config[:z_w]) - 1

        cdata_varnames = []

        if config[:MLD_scheme] == :datastream
            push!(cdata_varnames, "HMXL")
        end

        if config[:Qflx] == :on
            push!(cdata_varnames, "QFLX_TEMP")
            push!(cdata_varnames, "QFLX_SALT")
        end
        
        if config[:weak_restoring] == :on || config[:Qflx_finding] == :on
            push!(cdata_varnames, "TEMP")
            push!(cdata_varnames, "SALT")
        end

        println("ENV: CDATA_VARNAMES = ", cdata_varnames)

        return new(
            
            config,
 
            sub_yrng,        
            Nx,
            Ny,
            Nz,

            cdata_varnames,
        )
    end

end


