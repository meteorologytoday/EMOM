function checkBudget!(
    mb :: ModelBlock,
    Δt :: Float64;
    stage :: Symbol,
    substeps :: Integer = 0,
)

    fi    = mb.fi
    tmpfi = mb.tmpfi
    co    = mb.co
    cfg   = mb.ev.config
    Nx = co.gd.Nx
    Ny = co.gd.Ny
    Nz = co.gd.Nz

    if stage == :BEFORE_STEPPING

        @. tmpfi._TMP_SUBSTEP_BUDGET_ = 0.0

    elseif stage == :SUBSTEP_AFTER_ADV

        for i = 1:2
            # Advection
            tmpfi._TMP_SUBSTEP_BUDGET_[:, i] .+= sum(reshape(co.amo.T_Δz_T * view(fi._ADVX_, :, i), Nz, :), dims=1)[1, :] / substeps
        end

    elseif stage == :AFTER_STEPPING

        @. tmpfi._ΔX_  = tmpfi._NEWX_ - fi._X_

        # Compute ∫ dTEMP/dt dz and ∫ dSALT/dt dz
        for i = 1:2
            tmpfi._CHKX_[:, i] = sum(reshape(co.amo.T_Δz_T * view(tmpfi._ΔX_, :, i), Nz, :), dims=1)[1, :]
        end
        @. tmpfi._CHKX_ /= Δt

        # Advection check
        @. tmpfi._CHKX_ -= tmpfi._TMP_SUBSTEP_BUDGET_

        # Surface fluxes check     
        tmpfi._CHKX_[:, 1] .-= - ( view(fi.SWFLX, :) + view(fi.NSWFLX, :)) ./ ρcp_sw
        tmpfi._CHKX_[:, 2] .-= - view(fi.VSFLX, :)

        # Freezing melt potential check
        tmpfi._CHKX_[:, 1] .-= reshape( fi.Q_FRZHEAT, :) ./ ρcp_sw

        # Weak restoring check
        if cfg[:weak_restoring] == :on 
            tmpfi._CHKX_[:, 1] .-= reshape(sum( reshape(co.amo.T_Δz_T * view(fi._WKRST_, :, 1), Nz, :), dims=1 ), :)
            tmpfi._CHKX_[:, 2] .-= reshape(sum( reshape(co.amo.T_Δz_T * view(fi._WKRST_, :, 2), Nz, :), dims=1 ), :)
        end

        # Qfluxes check
        if cfg[:Qflx] == :on
            tmpfi._CHKX_[:, 1] .-= reshape(sum( reshape(co.amo.T_Δz_T * reshape(fi.datastream["QFLX_TEMP"], :, 1), Nz, :), dims=1 ), :) / ρcp_sw
            tmpfi._CHKX_[:, 2] .-= reshape(sum( reshape(co.amo.T_Δz_T * reshape(fi.datastream["QFLX_SALT"], :, 1), Nz, :), dims=1 ), :)
        end


        # Clean the values on the mask
        tmpfi._CHKX_[:, 1] .= co.amo_slab.T_mask_T * view(tmpfi._CHKX_, :, 1)
        tmpfi._CHKX_[:, 2] .= co.amo_slab.T_mask_T * view(tmpfi._CHKX_, :, 2)

    end      

end
