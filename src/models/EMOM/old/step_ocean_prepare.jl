using LinearAlgebra: mul!

function calWeightedQuantity(;
    top     :: Float64,
    bot     :: Float64,
    split_z :: Float64,
    zs      :: AbstractArray{Float64, 1},
    hs      :: AbstractArray{Float64, 1},
    layer   :: Integer,
)

    Δh     = ocn.hs[layer, i, j]
    Δh_top = ocn.zs[layer, i, j] - split_z
    Δh_bot = Δh - Δh_top

    return ( Δh_top * top + Δh_bot * bot ) / Δh

end


function stepOcean_prepare!(ocn::Ocean; cfgs...)

    adv_scheme = cfgs[:adv_scheme]

    if adv_scheme == :static
        return
    end

    # Transform input wind stress vector first
    DisplacedPoleCoordinate.project!(ocn.gi, ocn.in_flds.taux, ocn.in_flds.tauy, ocn.τx, ocn.τy, direction=:Forward)

    if adv_scheme == :ekman_HOOM_partition

        H_ek =  50.0
        H_rf = 250.0 
        H_total = H_ek + H_rf

        bot_lay_ek = getLayerFromDepth(
            z  = - H_ek,
            zs = ocn.zs_bone,  
            Nz = ocn.Nz_bone,
        )

        bot_lay_rf = getLayerFromDepth(
            z  = - H_total,
            zs = ocn.zs_bone,  
            Nz = ocn.Nz_bone,
        )

        @loop_hor ocn i j let

            ΔM̃_half = (ocn.τx[i, j] + ocn.τy[i, j] * im) / (2.0 * ρ_sw * (ocn.ϵs[i, j] + ocn.fs[i, j] * im) )

            ṽ_ek =   ΔM̃_half / H_ek
            ṽ_rf = - ΔM̃_half / H_rf

            u_ek, v_ek = real(ṽ_ek), imag(ṽ_ek)
            u_rf, v_rf = real(ṽ_rf), imag(ṽ_rf)

            if bot_lay_ek == -1
            
                ocn.u[:, i, j] .= u_ek
                ocn.v[:, i, j] .= v_ek

            else

                ocn.u[1:bot_lay_ek, i, j] .= u_ek
                ocn.v[1:bot_lay_ek, i, j] .= v_ek

                # Mix the top of RF layer
                Δh     = ocn.hs[bot_lay_ek, i, j]
                Δh_top = H_ek + ocn.zs[bot_lay_ek, i, j]
                Δh_bot = Δh - Δh_top

                ocn.u[bot_lay_ek, i, j] = (Δh_top * u_ek + Δh_bot * u_rf) / Δh
                ocn.v[bot_lay_ek, i, j] = (Δh_top * v_ek + Δh_bot * v_rf) / Δh

                if bot_lay_ek < ocn.Nz[i, j] # Bottom layers exists
                    if bot_lay_rf == -1
                       ocn.u[bot_lay_ek+1:end, i, j] .= u_rf
                       ocn.v[bot_lay_ek+1:end, i, j] .= v_rf
                    else
                       ocn.u[bot_lay_ek+1:bot_lay_rf, i, j] .= u_rf
                       ocn.v[bot_lay_ek+1:bot_lay_rf, i, j] .= v_rf

                        # Mix the bottom of RF layer
                        Δh     = ocn.hs[bot_lay_rf, i, j]
                        Δh_top = H_total + ocn.zs[bot_lay_rf, i, j]
                        Δh_bot = Δh - Δh_top

                        ocn.u[bot_lay_rf, i, j] = Δh_top * u_rf / Δh
                        ocn.v[bot_lay_rf, i, j] = Δh_top * v_rf / Δh

                    end
                end

            end
        end

 
    elseif adv_scheme == :test


        ocn.u .= 0
        ocn.v .= 0

        for k=1:2
             ocn.u[k, :, :] = 1.0 * cos.(ocn.gi.c_lat) .* sin.(ocn.gi.c_lon)
        end

        for k=3:12
             ocn.u[k, :, :] = -1.0/5 * cos.(ocn.gi.c_lat) .* sin.(ocn.gi.c_lon)
        end


       
    elseif adv_scheme == :ekman_codron2012_partition

        H_ek =  50.0
        H_rf = 250.0   # Codron (2012) suggests 150 - 350 meters. Here I take the average.
        H_total = H_ek + H_rf

        bot_lay_ek = getLayerFromDepth(
            z  = - H_ek,
            zs = ocn.zs_bone,  
            Nz = ocn.Nz_bone,
        )

        bot_lay_rf = getLayerFromDepth(
            z  = - H_total,
            zs = ocn.zs_bone,  
            Nz = ocn.Nz_bone,
        )

        @loop_hor ocn i j let

            M̃ = (ocn.τx[i, j] + ocn.τy[i, j] * im) / (ρ_sw * (ocn.ϵs[i, j] + ocn.fs[i, j] * im) )

            ṽ_ek =   M̃ / H_ek
            ṽ_rf = - M̃ / H_rf

            u_ek, v_ek = real(ṽ_ek), imag(ṽ_ek)
            u_rf, v_rf = real(ṽ_rf), imag(ṽ_rf)

            if bot_lay_ek == -1
            
                ocn.u[:, i, j] .= u_ek
                ocn.v[:, i, j] .= v_ek

            else

                ocn.u[1:bot_lay_ek, i, j] .= u_ek
                ocn.v[1:bot_lay_ek, i, j] .= v_ek

                # Mix the top of RF layer
                Δh     = ocn.hs[bot_lay_ek, i, j]
                Δh_top = H_ek + ocn.zs[bot_lay_ek, i, j]
                Δh_bot = Δh - Δh_top

                ocn.u[bot_lay_ek, i, j] = (Δh_top * u_ek + Δh_bot * u_rf) / Δh
                ocn.v[bot_lay_ek, i, j] = (Δh_top * v_ek + Δh_bot * v_rf) / Δh

                if bot_lay_ek < ocn.Nz[i, j] # Bottom layers exists
                    if bot_lay_rf == -1
                       ocn.u[bot_lay_ek+1:end, i, j] .= u_rf
                       ocn.v[bot_lay_ek+1:end, i, j] .= v_rf
                    else
                       ocn.u[bot_lay_ek+1:bot_lay_rf, i, j] .= u_rf
                       ocn.v[bot_lay_ek+1:bot_lay_rf, i, j] .= v_rf

                        # Mix the bottom of RF layer
                        Δh     = ocn.hs[bot_lay_rf, i, j]
                        Δh_top = H_total + ocn.zs[bot_lay_rf, i, j]
                        Δh_bot = Δh - Δh_top

                        ocn.u[bot_lay_rf, i, j] = Δh_top * u_rf / Δh
                        ocn.v[bot_lay_rf, i, j] = Δh_top * v_rf / Δh

                    end
                end

            end
        end

    else
        throw(ErrorException("Unknown advection scheme: " * string(adv_scheme)))
    end


    #println("calHorVelBnd with spmtx")
    tmp = getSpace!(ocn.wksp, :T)
    mul!(view(ocn.u_bnd, :), ocn.ASUM.U_fluxmask_interp_T, view(ocn.u, :))
    mul!(view(ocn.v_bnd, :), ocn.ASUM.V_fluxmask_interp_T, view(ocn.v, :))

    mul_autoflat!(ocn.div,   ocn.ASUM.T_DIVx_U, ocn.u_bnd)
    mul_autoflat!(tmp      , ocn.ASUM.T_DIVy_V, ocn.v_bnd)
    @. ocn.div += tmp

    calVerVelBnd!(
        gi    = ocn.gi,
        Nx    = ocn.Nx,
        Ny    = ocn.Ny,
        Nz    = ocn.Nz,
        w_bnd = ocn.w_bnd,
        hs    = ocn.hs,
        div   = ocn.div,
        mask3 = ocn.mask3,
    )
end

