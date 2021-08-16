mutable struct Core
    
    wksp      :: Workspace

#    mask_sT   :: AbstractArray{Float64, 3}
#    mask_T    :: AbstractArray{Float64, 3}
 
    amo_slab  :: Union{AdvancedMatrixOperators, Nothing}
    amo       :: Union{AdvancedMatrixOperators, Nothing}

    mtx       :: Dict

    vd        :: VerticalDiffusion

    cdatam     :: Union{CyclicDataManager, Nothing}



    function Core(
        ev :: Env,
        tmpfi :: TempField,
    )

        cfg = ev.config

        wksp = Workspace(Nx=ev.Nx, Ny=ev.Ny, Nz=ev.Nz)

        gf = PolelikeCoordinate.CurvilinearSphericalGridFile(
            cfg[:domain_file];
            R  = 6371229.0,
            Ω  = 2π / (86400 / (1 + 365/365)),
        )

        gd      = ev.gd
        gd_slab = ev.gd_slab

        amo_slab = AdvancedMatrixOperators(;
            gd = gd_slab,
            mask_T     = ev.topo.sfcmask_sT,
            deepmask_T = ev.topo.sfcmask_sT,
        )

        amo = AdvancedMatrixOperators(;
            gd = gd,
            mask_T = ev.topo.mask_T,
            deepmask_T = ev.topo.deepmask_T,
        )



        # Build Advection Matrix


        function build!(id_mtx, idx)
            local result
#            rows = size(id_mtx)[1]
            
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
        swflx_factor_W =  cfg[:rad_R]  * exp.(gd.z_W / cfg[:rad_ζ1]) + (1.0 - cfg[:rad_R]) * exp.(gd.z_W / cfg[:rad_ζ2])
        swflx_factor_W[end, :, :] .= 0.0 # Bottom absorbs everything

        # Surface flux is immediately absorbed at the top layer
        sfcflx_factor_W = 0.0 * gd.z_W
        sfcflx_factor_W[1, :, :] .= 1.0



        # f and ϵ matrices
        f_sT = 2 * gd.Ω * sin.(gd_slab.ϕ_T)
        ϵ_sT = f_sT * 0 .+ cfg[:ϵ]
        D_sT = f_sT.^2 + ϵ_sT.^2
        invD_sT = D_sT.^(-1.0)

        mtx = Dict(
            :ones_T          => ones(Float64, amo.bmo.T_pts),
            :T_swflxConv_sT  => - amo.T_mask_T * amo.T_DIVz_W * spdiagm(0 => view(swflx_factor_W, :)) * W_broadcast_sT,
            :T_sfcflxConv_sT => - amo.T_mask_T * amo.T_DIVz_W * spdiagm(0 => view(sfcflx_factor_W, :)) * W_broadcast_sT,
            :invD_sT         => invD_sT,
            :f_sT            => f_sT,
            :ϵ_sT            => ϵ_sT,
            :D_sT            => D_sT,
        ) 

        vd = VerticalDiffusion(
            amo;
            K_iso=cfg[:Ks_V],
            K_cva=(cfg[:convective_adjustment] == :on) ? cfg[:Ks_V_cva] : cfg[:Ks_V],
        )

        # freezing operator
        mtx[:T_invτ_frz_T] = - amo.T_mask_T * spdiagm(0 => ones(Float64, amo.bmo.T_pts)) / cfg[:τ_frz]
        
        # surface mask but is in 3D T grid. This one is different from the topo.sfcmask_sT. 
        sfcmask_T = zeros(Float64, amo.bmo.T_dim...)
        sfcmask_T[1, :, :] .= 1
        mtx[:T_sfcmask_T] = spdiagm(0 => amo.T_mask_T * reshape(sfcmask_T, :))


        if length(ev.cdata_varnames) == 0
            cdatam = nothing
        else

            if cfg[:cdata_file] == ""
                throw(ErrorException("Some config require cyclic data forcing file"))
            else
                cdatam = CyclicDataManager(;
                    timetype     = getproperty(CFTime, Symbol(cfg[:timetype])),
                    filename     = cfg[:cdata_file],
                    varnames     = ev.cdata_varnames,
                    beg_time     = cfg[:cdata_beg_time],
                    end_time     = cfg[:cdata_end_time],
                    align_time   = cfg[:cdata_align_time],
                    sub_yrng     = ev.sub_yrng,
                )


                tmpfi.datastream = makeDataContainer(cdatam)
            end
        end

        if cfg[:weak_restoring] == :on
            mtx[:T_invτwk_TEMP_T] = - amo.T_mask_T * spdiagm(0 => ones(Float64, amo.bmo.T_pts)) / cfg[:τwk_TEMP]
            mtx[:T_invτwk_SALT_T] = - amo.T_mask_T * spdiagm(0 => ones(Float64, amo.bmo.T_pts)) / cfg[:τwk_SALT]
        end




        return new(
            wksp,

            #mask_sT,
            #ev.topo.mask_T,

            amo_slab,
            amo,

            mtx,    

            vd,

            cdatam,


        )
    end

end


