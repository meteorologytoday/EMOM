mutable struct Core
    
    wksp      :: Workspace

    amo_slab  :: Union{AdvancedMatrixOperators, Nothing}
    amo       :: Union{AdvancedMatrixOperators, Nothing}

    mtx       :: Dict

    vd        :: VerticalDiffusion

    cdatams    :: Union{Dict, Nothing}
    
    function Core(
        ev :: Env,
        tmpfi :: TempField,
    )

        cfg_core = ev.cfgs["MODEL_CORE"]
        cfg_domain = ev.cfgs["DOMAIN"]

        wksp = Workspace(Nx=ev.Nx, Ny=ev.Ny, Nz=ev.Nz)

        gf = PolelikeCoordinate.CurvilinearSphericalGridFile(
            cfg_domain["domain_file"];
            R  = Re,
            Ω  = Ω,
        )

        gd      = ev.gd
        gd_slab = ev.gd_slab

        #onelayerΔa_T = view(gf.area, :, ev.sub_yrng)  # Use domain provided area
        onelayerΔa_T = nothing # Use self-computed area
        amo_slab = AdvancedMatrixOperators(;
            gd = gd_slab,
            mask_T     = ev.topo.sfcmask_sT,
            deepmask_T = ev.topo.sfcmask_sT,
            onelayerΔa_T = onelayerΔa_T,
        )

        amo = AdvancedMatrixOperators(;
            gd = gd,
            mask_T = ev.topo.mask_T,
            deepmask_T = ev.topo.deepmask_T,
            onelayerΔa_T = onelayerΔa_T,
        )

        # Build Advection Matrix
        function build!(id_mtx, idx)
            local result
            # using transpose speeds up by 100 times 
            tp = transpose(id_mtx) |> sparse
            result = transpose(tp[:, view(idx, :)]) |> sparse
            dropzeros!(result)

            idx .= 0 # clean so that debug is easir when some girds are not assigned
            return result
        end

        # Build the matrix to broadcast sW to W grid
        # Notice that we cannot use W_pts because gd_slab has two W layers 
        num_sT = reshape( collect(1:amo_slab.bmo.T_pts), amo_slab.bmo.T_dim...)
        mapping_T = repeat(num_sT, outer=(ev.Nz+1, 1, 1))
        W_broadcast_sT = build!(amo_slab.bmo.T_I_T, mapping_T)

        # Build Radiation Matrix
        swflx_factor_W =  cfg_core["rad_R"]  * exp.(gd.z_W / cfg_core["rad_ζ1"]) + (1.0 - cfg_core["rad_R"]) * exp.(gd.z_W / cfg_core["rad_ζ2"])


        Nz_bot = view(ev.topo.Nz_bot_sT, 1, :, :)
        #println("Nz_bot: ", Nz_bot[20, 114])
        #println("Before: ", swflx_factor_W[:, 20, 114])
        for j=1:ev.Ny, i=1:ev.Nx
            swflx_factor_W[(Nz_bot[i, j]+1):end, i, j] .= 0.0 # Bottom absorbs everything
        end
        #println("After: ", swflx_factor_W[:, 20, 114])

        #swflx_factor_W .= 0
        #swflx_factor_W[1, :, :] .= 1.0

        # Surface flux is immediately absorbed at the top layer
        sfcflx_factor_W = 0.0 * gd.z_W
        sfcflx_factor_W[1, :, :] .= 1.0

        #Ks_H matrix
#        Ks_H_U = zeros(Float64, amo.bmo.V_dim...)

        # This design is to prevent the equator develop wind-Ekman-SST feedback
        # that creates spurious rainband in Central Pacific
        Ks_H_func = (ϕ, z) -> 500.0 + (20000.0 - 500.0) * exp( - 0.5 * (ϕ/deg2rad(10.0))^2 ) * exp(z/100.0)

#        println(size(gd.ϕ_U))
#        println(size(gd.ϕ_V))
#        println(size(gd.ϕ_UV))
#        println(size(gd.z_V))

        Ks_H_U = reshape(Ks_H_func.(gd.ϕ_U, gd.z_U), amo.bmo.U_dim...)
        Ks_H_V = reshape(Ks_H_func.(gd.ϕ_V, gd.z_V), amo.bmo.V_dim...)
        Ks_H_T = reshape(Ks_H_func.(gd.ϕ_T, gd.z_T), amo.bmo.T_dim...)



        # f and ϵ matrices
        f_sT = 2 * gd.Ω * sin.(gd_slab.ϕ_T)
        β_sT = (2 * gd.Ω / gd.R) * cos.(gd_slab.ϕ_T)
        ϵ_sT = f_sT * 0 .+ cfg_core["ϵ"]
        D_sT = f_sT.^2 + ϵ_sT.^2
        invD_sT = D_sT.^(-1.0)

        mtx = Dict(
            :ones_T          => ones(Float64, amo.bmo.T_pts),
            :T_swflxConv_sT  => - amo.T_mask_T * amo.T_DIVz_W * spdiagm(0 => view(swflx_factor_W, :)) * W_broadcast_sT,
            :T_sfcflxConv_sT => - amo.T_mask_T * amo.T_DIVz_W * spdiagm(0 => view(sfcflx_factor_W, :)) * W_broadcast_sT,
            :invD_sT         => invD_sT,
            :f_sT            => f_sT,
            :β_sT            => β_sT,
            :ϵ_sT            => ϵ_sT,
            :D_sT            => D_sT,
            :Ks_H_T          => Ks_H_T,
            :Ks_H_U          => Ks_H_U,
            :Ks_H_V          => Ks_H_V,
        ) 

        tmpfi.check_usage[:Ks_H_U] .= Ks_H_U
        tmpfi.check_usage[:Ks_H_V] .= Ks_H_V

        vd = VerticalDiffusion(
            amo;
            K_iso=cfg_core["Ks_V"],
            K_cva=(cfg_core["convective_adjustment"] == "on") ? cfg_core["Ks_V_cva"] : cfg_core["Ks_V"],
        )

        # surface mask but is in 3D T grid. This one is different from the topo.sfcmask_sT. 
        sfcmask_T = zeros(Float64, amo.bmo.T_dim...)
        sfcmask_T[1, :, :] .= 1
        mtx[:T_sfcmask_T] = spdiagm(0 => amo.T_mask_T * reshape(sfcmask_T, :))

        cdatams = Dict()
        
        if length(ev.cdata_varnames) == 0
            writeLog("No datastream variable is needed.")
        else
            writeLog("Needed datastream varnames: ", join(ev.cdata_varnames, ", "))
            
            for varname in ev.cdata_varnames
                if (! haskey(cfg_core, "cdata_var_file_$varname" ) )
                    throw(ErrorException("Need config: cdata_var_file_$varname"))
                end
            end

            function parseDateTime(timetype, str)
                m = match(r"(?<year>[0-9]+)-(?<month>[0-9]{2})-(?<day>[0-9]{2})\s+(?<hour>[0-9]{2}):(?<min>[0-9]{2}):(?<sec>[0-9]{2})", str)
                if m == nothing
                    throw(ErrorException("Unknown time format: " * (str)))
                end

                return timetype(
                    parse(Int64, m[:year]),
                    parse(Int64, m[:month]),
                    parse(Int64, m[:day]),
                    parse(Int64, m[:hour]),
                    parse(Int64, m[:min]),
                    parse(Int64, m[:sec]),
                )
            end
           
            timetype   = getproperty(CFTime, Symbol(cfg_core["timetype"]))
            tmpfi.datastream = Dict()


            for varname in ev.cdata_varnames
            
                var_file_map = Dict()
                var_file_map[varname] = cfg_core["cdata_var_file_$varname"]

                cdatam = CyclicDataManager(;
                    timetype     = timetype,
                    var_file_map = var_file_map,
                    beg_time     = parseDateTime(timetype, cfg_core["cdata_beg_time"]),
                    end_time     = parseDateTime(timetype, cfg_core["cdata_end_time"]),
                    align_time   = parseDateTime(timetype, cfg_core["cdata_align_time"]),
                    sub_yrng     = ev.sub_yrng,
                )

                tmpfi.datastream[varname] = makeDataContainer(cdatam)
                cdatams[varname] = cdatam
            end
        end

        if cfg_core["weak_restoring"] == "on"
        
            if cfg_core["τwk_file"] != ""
                
                println("config `τwk_file` is non-empty.")
                println("Read τwk from the file \"$(cfg_core["τwk_file"])\".")
                ds = Dataset(cfg_core["τwk_file"], "r")
                
                _τ_TEMP = permutedims( nomissing(ds["time_TEMP"][:, ev.sub_yrng, :], NaN), [3,1,2])
                _τ_SALT = permutedims( nomissing(ds["time_SALT"][:, ev.sub_yrng, :], NaN), [3,1,2])
                
                close(ds)
                
                if any(_τ_TEMP .<= 0.0)
                    throw(ErrorException("EMOM needs positive relaxation timescale in `time_TEMP`. Please feed in a different `τwk_file`."))
                end

                if any(_τ_SALT .<= 0.0)
                    throw(ErrorException("EMOM needs positive relaxation timescale in `time_SALT`. Please feed in a different `τwk_file`."))
                end

                invτ_TEMP = zeros(Float64, amo.bmo.T_dim)
                invτ_SALT = zeros(Float64, amo.bmo.T_dim)

                idx = isfinite.(_τ_TEMP)
                invτ_TEMP[idx] .= _τ_TEMP[idx].^(-1)

                idx = isfinite.(_τ_SALT)
                invτ_SALT[idx] .= _τ_SALT[idx].^(-1)
                
                mtx[:T_invτwk_TEMP_T] = - amo.T_mask_T * spdiagm(0 => reshape(invτ_TEMP, :))
                mtx[:T_invτwk_SALT_T] = - amo.T_mask_T * spdiagm(0 => reshape(invτ_SALT, :))

            else
                mtx[:T_invτwk_TEMP_T] = - amo.T_mask_T * spdiagm(0 => ones(Float64, amo.bmo.T_pts)) / cfg_core["τwk_TEMP"]
                mtx[:T_invτwk_SALT_T] = - amo.T_mask_T * spdiagm(0 => ones(Float64, amo.bmo.T_pts)) / cfg_core["τwk_SALT"]
            end
        end




        return new(
            wksp,

            #mask_sT,
            #ev.topo.mask_T,

            amo_slab,
            amo,

            mtx,    

            vd,

            cdatams,

        )
    end

end


