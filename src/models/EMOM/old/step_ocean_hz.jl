function stepOcean_Flow!(
    ocn  :: Ocean;
    cfgs...
)
    
    adv_scheme = cfgs[:adv_scheme]
    do_convadjust = cfgs[:do_convadjust]
    Δt         = cfgs[:Δt]

     

    if adv_scheme == :static
        return
    end

    reset!(ocn.wksp)

    #old_intT = sum(ocn.ASUM.filter_T * ocn.ASUM.T_Δvol_T * view(ocn.Ts, :))
    # Determine the temperature / salinity of FLDO layer
    @loop_hor ocn i j let

        ocn.ΔT[i, j] = mixFLDO!(
            qs   = ocn.cols.Ts[i, j],
            zs   = ocn.cols.zs[i, j],
            hs   = ocn.cols.hs[i, j],
            q_ML = ocn.T_ML[i, j],
            FLDO = ocn.FLDO[i, j],
            FLDO_ratio_top = ocn.FLDO_ratio_top[i, j],
            FLDO_ratio_bot = ocn.FLDO_ratio_bot[i, j],
        )

        ocn.ΔS[i, j] = mixFLDO!(
            qs   = ocn.cols.Ss[i, j],
            zs   = ocn.cols.zs[i, j],
            hs   = ocn.cols.hs[i, j],
            q_ML = ocn.S_ML[i, j],
            FLDO = ocn.FLDO[i, j],
            FLDO_ratio_top = ocn.FLDO_ratio_top[i, j],
            FLDO_ratio_bot = ocn.FLDO_ratio_bot[i, j],
        )

    end

    # Pseudo code
    # 1. assign velocity field
    # 2. calculate temperature & salinity flux
    # 3. calculate temperature & salinity flux divergence
    # Gov eqn adv + diff: ∂T/∂t = - 1 / (ρ H1) ( ∇⋅(M1 T1) - (∇⋅M1) Tmid )

#    println("##### QUICK NO SPEEDUP")
#=
    calDiffAdv_QUICK!(
        ocn,
        qs          = ocn.Ts,
        FLUX_bot      = ocn.TFLUX_bot,
        dΔqdt       = ocn.dΔTdt,
        FLUX_CONV   = ocn.TFLUX_CONV,
        FLUX_CONV_h = ocn.TFLUX_CONV_h,
        FLUX_DEN_x  = ocn.TFLUX_DEN_x,
        FLUX_DEN_y  = ocn.TFLUX_DEN_y,
        FLUX_DEN_z  = ocn.TFLUX_DEN_z,
        Dh = ocn.Dh_T,
        Dv = ocn.Dv_T,
    )

    calDiffAdv_QUICK!(
        ocn,
        qs          = ocn.Ss,
        FLUX_bot      = ocn.SFLUX_bot,
        dΔqdt       = ocn.dΔSdt,
        FLUX_CONV   = ocn.SFLUX_CONV,
        FLUX_CONV_h = ocn.SFLUX_CONV_h,
        FLUX_DEN_x  = ocn.SFLUX_DEN_x,
        FLUX_DEN_y  = ocn.SFLUX_DEN_y,
        FLUX_DEN_z  = ocn.SFLUX_DEN_z,
        Dh = ocn.Dh_S,
        Dv = ocn.Dv_S,
    )
=#
    #println("##### QUICK SPEEDUP")
    #println("before calDiffAdv T_ML[60,70] = ", ocn.T_ML[60,70])
    
    calDiffAdv_QUICK_SpeedUp!(
        ocn,
        qs          = ocn.Ts,
        dΔqdt       = ocn.dΔTdt,
        FLUX_CONV   = ocn.TFLUX_CONV,
        FLUX_CONV_h = ocn.TFLUX_CONV_h,
        FLUX_DEN_x  = ocn.TFLUX_DEN_x,
        FLUX_DEN_y  = ocn.TFLUX_DEN_y,
        FLUX_DEN_z  = ocn.TFLUX_DEN_z,
        Dh = ocn.Dh_T,
        Dv = ocn.Dv_T,
        Δt = Δt,
    )

    #println("after calDiffAdv T_ML[60,70] = ", ocn.T_ML[60,70])
    #println("after calDiffAdv TFLUX_CONV[1, 60,70] = ", ocn.TFLUX_CONV[1, 60,70])

    calDiffAdv_QUICK_SpeedUp!(
        ocn,
        qs          = ocn.Ss,
        dΔqdt       = ocn.dΔSdt,
        FLUX_CONV   = ocn.SFLUX_CONV,
        FLUX_CONV_h = ocn.SFLUX_CONV_h,
        FLUX_DEN_x  = ocn.SFLUX_DEN_x,
        FLUX_DEN_y  = ocn.SFLUX_DEN_y,
        FLUX_DEN_z  = ocn.SFLUX_DEN_z,
        Dh = ocn.Dh_S,
        Dv = ocn.Dv_S,
        Δt = Δt,
    )
    

    @loop_hor ocn i j let
 
        Nz = ocn.Nz[i, j]
        zs   = ocn.cols.zs[i, j]
        hs   = ocn.cols.hs[i, j]
        h_ML = ocn.h_ML[i, j]
        FLDO = ocn.FLDO[i, j]
        
        for k = 1:ocn.Nz[i, j]
            ocn.Ts[k, i, j] += Δt * ocn.TFLUX_CONV[k, i, j]
            ocn.Ss[k, i, j] += Δt * ocn.SFLUX_CONV[k, i, j]
        end

        # Adjust ΔT, ΔS
        ocn.ΔT[i, j] += ocn.dΔTdt[i, j] * Δt 
        ocn.ΔS[i, j] += ocn.dΔSdt[i, j] * Δt

        ocn.T_ML[i, j] = unmixFLDOKeepDiff!(;
            qs   = ocn.cols.Ts[i, j],
            zs   = zs,
            hs   = hs,
            h_ML = h_ML,
            FLDO = FLDO,
            Nz   = Nz,
            Δq   = ocn.ΔT[i, j],
        )

        ocn.S_ML[i, j] = unmixFLDOKeepDiff!(;
            qs   = ocn.cols.Ss[i, j],
            zs   = zs,
            hs   = hs,
            h_ML = h_ML,
            FLDO = FLDO,
            Nz   = Nz,
            Δq   = ocn.ΔS[i, j],
        )

        OC_updateB!(ocn, i, j)

        if do_convadjust
            OC_doConvectiveAdjustment!(ocn, i, j)
        end




    end

    #new_intT = sum(ocn.ASUM.filter_T * ocn.ASUM.T_Δvol_T * view(ocn.Ts, :))
    #println("Total integrated T: ", new_intT, "; change=", (new_intT - old_intT)/old_intT * 100, " % ")
end
