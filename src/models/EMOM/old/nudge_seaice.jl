
function nudgeSeaice!(
    ocn :: Ocean;
    τ   :: Float64,
    cfgs...
)
    do_convadjust = cfgs[:do_convadjust]

    Δt = cfgs[:Δt]
    r = Δt / τ
    rr = r / (1.0 + r)

    @loop_hor ocn i j let

        ifrac_clim = ocn.in_flds.IFRACclim[i, j]

        # This provide an option for nudging area. For example, to nudge the seaice in northern hemisphere ONLY,
        # user can simply set IFRAC_clim in the sounthern hemisphere to non-positive values.
        if ifrac_clim >= 0.0
           
            ifrac = ocn.in_flds.ifrac[i, j]
            T_ML = ocn.T_ML[i, j]
            FLDO = ocn.FLDO[i, j]
            h_ML = ocn.h_ML[i, j]
     

            # observe that between -1~-2 degC, slope of SST - IFRAC is
            # roughly 100% / 1K. Use this as a diagnostic relation to determine
            # nudged SST.
            ΔT = rr * (ifrac - ifrac_clim)

            T_ML += ΔT
            ocn.T_ML[i, j] = T_ML
            if FLDO > 1
                ocn.Ts[1:FLDO-1, i, j] .= T_ML
            elseif FLDO == -1
                ocn.Ts[1:ocn.Nz[i, j], i, j] .= T_ML
            end

            ocn.seaice_nudge_energy[i, j] = ΔT * ocn.h_ML[i, j] * ρc_sw   / Δt   # + => warming

            OC_updateB!(ocn, i, j)

        else
            ocn.seaice_nudge_energy[i, j] = 0.0
        end

    end

    if do_convadjust
        @loop_hor ocn i j let
            if ocn.in_flds.IFRACclim[i, j] >= 0.0
                OC_doConvectiveAdjustment!(ocn, i, j;)
            end
        end
    end


end
