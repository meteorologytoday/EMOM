function calFlxCorrection!(
    ocn :: Ocean;
    τ   :: Float64 = 10 * 86400.0,
    cfgs...
)
    do_convadjust = cfgs[:do_convadjust]

    Δt = cfgs[:Δt]
    r = Δt / τ
    rr = r / (1.0 + r)

    calTsSsMixed!(ocn)

    # Euler backward method
    @. ΔT_mixed = rr * (ocn.in_fld.Tclim - ocn.Ts_mixed)
    @. ΔS_mixed = rr * (ocn.in_fld.Sclim - ocn.Ss_mixed)


    @loop_hor ocn i j let
 
        T_ML = ocn.T_ML[i, j]
        S_ML = ocn.S_ML[i, j]
        FLDO = ocn.FLDO[i, j]
        h_ML = ocn.h_ML[i, j]

        if FLDO == -1  # Whole ocean layer. In the future I want to restrict FLDO so that code can be cleaner.
            
            ΔT_ML = 0.0
            for k=1:ocn.Nz[i, j]
                ΔT_ML += ΔT_mixed[k, i, j] * ocn.hs[k, i, j]
            end
            ΔT_ML /= h_ML
            
            
            ΔS_ML = 0.0
            for k=1:ocn.Nz[i, j]
                ΔS_ML += ΔS_mixed[k, i, j] * ocn.hs[k, i, j]
            end
            ΔS_ML /= h_ML


            T_ML += ΔT_ML
            S_ML += ΔS_ML
            ocn.T_ML[i, j] = T_ML
            ocn.S_ML[i, j] = S_ML

            ocn.Ts[:, i, j] .= T_ML
            ocn.Ss[:, i, j] .= S_ML
  
        else
            # With in mixed-layer
            if FLDO == 1
                ocn.T_ML += ΔT_mixed[1, i, j]
                ocn.S_ML += ΔS_mixed[1, i, j]
            elseif FLDO > 1
 
                ΔT_ML = 0.0
                for k=1:FLDO-1
                    ΔT_ML += ΔT_mixed[k, i, j] * ocn.hs[k, i, j]
                end
                ΔT_ML += ΔT_mixed[FLDO, k, j] * (ocn.zs[FLDO, i, j] + h_ML)
                ΔT_ML /= h_ML


                ΔS_ML = 0.0
                for k=1:FLDO-1
                    ΔS_ML += ΔS_mixed[k, i, j] * ocn.hs[k, i, j]
                end
                ΔS_ML += ΔS_mixed[FLDO, k, j] * (ocn.zs[FLDO, i, j] + h_ML)
                ΔS_ML /= h_ML


                T_ML += ΔT_ML
                S_ML += ΔS_ML
                ocn.T_ML[i, j] = T_ML
                ocn.S_ML[i, j] = S_ML

                ocn.Ts[1:FLDO-1, i, j] .= T_ML
                ocn.Ss[1:FLDO-1, i, j] .= S_ML
            
            end

            # Deeper ocean
            if FLDO != -1
                @. ocn.Ts[FLDO:end, i, j] += ΔT_mixed[FLDO:end, i, j]           
                @. ocn.Ss[FLDO:end, i, j] += ΔS_mixed[FLDO:end, i, j]           
            end
        
        end 

        OC_updateB!(ocn, i, j)

    end

    @. ocn.qflx_T_correction = ΔT_mixed * ocn.hs * ρc_sw   / Δt   # + => warming
    @. ocn.qflx_S_correction = ΔS_mixed * ocn.hs           / Δt   # + => saltier


    if do_convadjust
        @loop_hor ocn i j let
            OC_doConvectiveAdjustment!(ocn, i, j;)
        end
    end


end
