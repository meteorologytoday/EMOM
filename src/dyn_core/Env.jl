mutable struct Env

    cfg_core :: Dict
    cfg_domain :: Dict
    
    sub_yrng :: Union{UnitRange, Colon, Nothing}
    Nx :: Integer
    Ny :: Integer
    Nz :: Integer

    cdata_varnames :: AbstractArray{String}

    gf        :: Union{PolelikeCoordinate.GridFile, Nothing}
    gd        :: PolelikeCoordinate.Grid
    gd_slab   :: PolelikeCoordinate.Grid
    z_w       :: AbstractArray{Float64, 1}
    topo      :: Topography

    function Env(
        cfg_core,
        cfg_domain;
        sub_yrng :: Union{UnitRange, Colon} = Colon(),
        verbose :: Bool = false,
    )
       
        writeLog("Validating cfg_core: MODEL_CORE") 
        cfg_core = validateConfigEntries(cfg_core, getEMOMConfigDescriptors()["MODEL_CORE"]; verbose = verbose) 
        cfg_domain = validateConfigEntries(cfg_domain, getDomainConfigDescriptors()["DOMAIN"]; verbose = verbose) 
           
        # mask =>   lnd = 0, ocn = 1
        gf = PolelikeCoordinate.CurvilinearSphericalGridFile(
            cfg_domain["domain_file"];
            R  = Re,
            Ω  = Ω,
        )

        if sub_yrng == Colon()
            sub_yrng = 1:gf.Ny
        end

        # Load z_w
        ds = Dataset(cfg_domain["z_w_file"], "r")
        z_w = nomissing(ds["z_w"][:], NaN)
        close(ds)

        Nx = gf.Nx
        Ny = length(sub_yrng)
        Nz = length(z_w) - 1

        cdata_varnames = []

        if cfg_core["MLD_scheme"] == "datastream"
            push!(cdata_varnames, "HMXL")
        end

        if cfg_core["Qflx"] == "on"
            push!(cdata_varnames, "QFLXT")
            push!(cdata_varnames, "QFLXS")
        end
        
        if cfg_core["weak_restoring"] == "on" || cfg_core["Qflx_finding"] == "on"
            push!(cdata_varnames, "TEMP")
            push!(cdata_varnames, "SALT")
        end

        # I put gd here because master needs gd for output coordinate information
        gd      = PolelikeCoordinate.genGrid(gf, z_w ; sub_yrng=sub_yrng) 
        gd_slab = PolelikeCoordinate.genGrid(gf, [0, -1.0]; sub_yrng=sub_yrng) 


        if cfg_core["Returnflow_layers"] + cfg_core["Ekman_layers"] > gd.Nz
            throw(ErrorException("Sum of `Returnflow_layers` and `Ekman_layers` exceeds Nz = $(gd.Nz)"))
        end
        #
        topo = nothing

        if cfg_domain["topo_file"] != ""
            Dataset(cfg_domain["topo_file"], "r") do ds
                Nz_bot = ds["Nz_bot"][:, sub_yrng]
            end
        else
            Nz_bot = zeros(Int64, gd.Nx, gd.Ny) .+ gd.Nz
            Nz_bot[gf.mask[:, sub_yrng] .== 0.0 ] .= 0.0
        end
        topo = Topography(
            Nz_bot, gf.Nx, length(sub_yrng), z_w;
            deep_depth = - z_w[cfg_core["Returnflow_layers"] + cfg_core["Ekman_layers"] + 1]
        )

        if any(view(topo.mask_T, 1, :, :) .!= gf.mask[:, sub_yrng])
            throw(ErrorException("Topo surface mask is inconsistent with mask loaded from domain file. It can be that the `deep_depth` in Topography is set too low, or simply because topography file is not consistent with domain file."))
        end
 
        return new(
            
            cfg_core,
            cfg_domain,
 
            sub_yrng,        
            Nx,
            Ny,
            Nz,

            cdata_varnames,

            gf,
            gd,
            gd_slab,
            z_w,
            topo,
        )
    end

end


