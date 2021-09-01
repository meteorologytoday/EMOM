mutable struct Env

    config :: Dict
    
    sub_yrng :: Union{UnitRange, Colon, Nothing}
    Nx :: Integer
    Ny :: Integer
    Nz :: Integer

    cdata_varnames :: AbstractArray{String}

    gf        :: Union{PolelikeCoordinate.GridFile, Nothing}
    gd        :: PolelikeCoordinate.Grid
    gd_slab   :: PolelikeCoordinate.Grid
    topo      :: Topography

    function Env(
        config;
        sub_yrng :: Union{UnitRange, Colon} = Colon(),
        verbose :: Bool = false,
    )
       
        writeLog("Validating config: MODEL_CORE") 
        config = validateConfigEntries(config, getConfigDescriptor()["MODEL_CORE"]; verbose = verbose) 
           
        # mask =>   lnd = 0, ocn = 1
        gf = PolelikeCoordinate.CurvilinearSphericalGridFile(
            config["domain_file"];
            R  = Re,
            Ω  = Ω,
        )

        if sub_yrng == Colon()
            sub_yrng = 1:gf.Ny
        end

        Nx = gf.Nx
        Ny = length(sub_yrng)
        Nz = length(config["z_w"]) - 1

        cdata_varnames = []

        if config["MLD_scheme"] == "datastream"
            push!(cdata_varnames, "HMXL")
        end

        if config["Qflx"] == "on"
            push!(cdata_varnames, "QFLX_TEMP")
            push!(cdata_varnames, "QFLX_SALT")
        end
        
        if config["weak_restoring"] == "on" || config["Qflx_finding"] == "on"
            push!(cdata_varnames, "TEMP")
            push!(cdata_varnames, "SALT")
        end

        # I put gd here because master needs gd for output coordinate information
        gd      = PolelikeCoordinate.genGrid(gf, config["z_w"] ; sub_yrng=sub_yrng) 
        gd_slab = PolelikeCoordinate.genGrid(gf, [0, -1.0]; sub_yrng=sub_yrng) 


        #
        topo = nothing
        Dataset(config["topo_file"], "r") do ds
            Nz_bot = ds["Nz_bot"][:, sub_yrng]
            #println(Nz_bot)
            topo = Topography(
                Nz_bot, gf.Nx, length(sub_yrng), config["z_w"];
                deep_depth = - config["z_w"][config["Returnflow_layers"] + config["Ekman_layers"] + 1]
            )
        end

        if any(view(topo.mask_T, 1, :, :) .!= gf.mask[:, sub_yrng])
            throw(ErrorException("Topo surface mask is inconsistent with mask loaded from domain file. It can be that the `deep_depth` in Topography is set too low, or simply because topography file is not consistent with domain file."))
        end
 
        return new(
            
            config,
 
            sub_yrng,        
            Nx,
            Ny,
            Nz,

            cdata_varnames,

            gf,
            gd,
            gd_slab,
            topo,
        )
    end

end


