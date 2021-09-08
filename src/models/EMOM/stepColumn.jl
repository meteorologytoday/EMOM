function stepColumn!(
    mb :: ModelBlock,
    Δt :: Float64,
)

    fi    = mb.fi
    tmpfi = mb.tmpfi
    co    = mb.co
    ev    = mb.ev
    cfg   = ev.config
    wksp  = co.wksp

    # *** Diffusion and restoring ***
    # (b_t+1 - b_t) / dt =  OP1 * b_t+1 + OP2 * (b_t+1 - b_target) + const
    # b_t+1 - b_t =  dt * OP1 * b_t+1 + dt * OP2 * (b_t+1 - b_target) + dt * const
    # (I - OP1 * dt - OP2 * dt) b_t+1 = b_t - dt * OP2 * b_target + dt * const
    # b_t+1 = (I - OP1 * dt - OP2 * dt) \ (b_t - dt * OP2 * b_target + dt * const)
    #
    # Change of b
    #
    # Δb = b_t+1 - b_t = Δt * OP1 * b_t+1 + Δt * OP2 * (b_t+1 - b_target) + Δt * const
    #
    # Notice that I carefully use the buoyancy before
    # stepAdvection which means operators should be at
    # t = t0. I empirically know if we use newton method
    # to find a steady state, then this scheme seem to
    # ensure that physical stepping will be steady state
    # too.
    # 
    op_vdiff = calOp_vdiff(co.vd, fi._b, fi.HMXL, fi.sv[:_TEMP])

    op_TEMP = op_vdiff
    op_SALT = op_vdiff
  
    # Save this operator for diagnostic purpose 
    mb.tmpfi.op_vdiff = op_vdiff
 
    # Surface fluxes of temperature
    rad = ( co.mtx[:T_swflxConv_sT] * view(fi.SWFLX, :) + co.mtx[:T_sfcflxConv_sT] * view(fi.NSWFLX, :)) / ρcp_sw
    RHS_TEMP = view(tmpfi._INTMX_, :, 1) + Δt * rad

    # Surface fluxes of salinity
    RHS_SALT = view(tmpfi._INTMX_, :, 2) + Δt * co.mtx[:T_sfcflxConv_sT] * view(fi.VSFLX, :)


    if cfg["weak_restoring"] == "on"
        op_TEMP   += co.mtx[:T_invτwk_TEMP_T]
        op_SALT   += co.mtx[:T_invτwk_SALT_T]
        
        idx = isnan.(tmpfi.datastream["TEMP"])
        tmpfi.datastream["TEMP"][idx] .= 0.0
        tmpfi.datastream["SALT"][idx] .= 0.0
 
        RHS_TEMP .-= Δt * co.amo.T_mask_T * co.mtx[:T_invτwk_TEMP_T] * reshape( tmpfi.datastream["TEMP"] , :)
        RHS_SALT .-= Δt * co.amo.T_mask_T * co.mtx[:T_invτwk_SALT_T] * reshape( tmpfi.datastream["SALT"] , :)
    end
 
    if cfg["Qflx"] == "on"
        RHS_TEMP .+= Δt * co.amo.T_mask_T * view( tmpfi.datastream["QFLX_TEMP"] , :) / ρcp_sw
        RHS_SALT .+= Δt * co.amo.T_mask_T * view( tmpfi.datastream["QFLX_SALT"] , :) 
    end

    F_EBM_TEMP = lu( I - Δt * op_TEMP )
    F_EBM_SALT = lu( I - Δt * op_SALT )
    
    tmpfi.sv[:NEWTEMP][:] = F_EBM_TEMP \ RHS_TEMP
    tmpfi.sv[:NEWSALT][:] = F_EBM_SALT \ RHS_SALT
    #tmpfi.sv[:NEWTEMP][:] = RHS_TEMP
    #tmpfi.sv[:NEWSALT][:] = RHS_SALT

   fi.sv[:VDIFFT][:] = op_vdiff * reshape(tmpfi.sv[:NEWTEMP], :, 1) 
   fi.sv[:VDIFFS][:] = op_vdiff * reshape(tmpfi.sv[:NEWSALT], :, 1) 

    #=
    beg_idx = 0
    jmp = ev.Nz*ev.Nx
    for i=1:ev.Ny
        rng = beg_idx+1:beg_idx+jmp
        sub_op_TEMP  = view(op_TEMP, rng, rng)
        sub_op_SALT  = view(op_SALT, rng, rng)

        sub_RHS_TEMP = view(RHS_TEMP, rng)
        sub_RHS_SALT = view(RHS_SALT, rng) 

        F_EBM_TEMP = lu( I - Δt * sub_op_TEMP )
        F_EBM_SALT = lu( I - Δt * sub_op_SALT )
        
        tmpfi.sv[:NEWTEMP][rng] = F_EBM_TEMP \ sub_RHS_TEMP
        tmpfi.sv[:NEWSALT][rng] = F_EBM_SALT \ sub_RHS_SALT
        
        beg_idx += jmp
    end
    =#
    # Recompute source and sink of tracers due to weak restoring
    if cfg["weak_restoring"] == "on"
        tmpfi._WKRSTΔX_[:, 1] = tmpfi._NEWX_[:, 1] - reshape(tmpfi.datastream["TEMP"], :)
        tmpfi._WKRSTΔX_[:, 2] = tmpfi._NEWX_[:, 2] - reshape(tmpfi.datastream["SALT"], :)
        fi._WKRSTX_[:, 1] = co.mtx[:T_invτwk_TEMP_T] * view(tmpfi._WKRSTΔX_, :, 1)
        fi._WKRSTX_[:, 2] = co.mtx[:T_invτwk_SALT_T] * view(tmpfi._WKRSTΔX_, :, 2)
    else
        fi._WKRSTX_ .= 0.0
    end

    # 
    # Freezing Potential
    #
    # Please read:
    # "CICE: the Los Alamos Sea Ice Model Documentation and Software User’s Manual"
    # https://csdms.colorado.edu/w/images/CICE_documentation_and_software_user's_manual.pdf
    #
    # Section 2.2 "Ocean":
    #
    # New sea ice forms when the ocean temperature drops below its freezing temperature, Tf = −µS, where S
    # is the seawater salinity and µ = 0.054 psu is the ratio of the freezing temperature of brine to its salinity.
    # The ocean model performs this calculation; if the freezing/melting potential Ffrzmlt is positive, its value
    # represents a certain amount of frazil ice that has formed in one or more layers of the ocean and floated to the
    # surface. (The ocean model assumes that the amount of new ice implied by the freezing potential actually
    # forms.) In general, this ice is added to the thinnest ice category. The new ice is grown in the open water area
    # of the grid cell to a specified minimum thickness; if the open water area is nearly zero or if there is more
    # new ice than will fit into the thinnest ice category, then the new ice is spread over the entire cell.
    # If Ffrzmlt is negative, it is used to heat already existing ice from below. In particular, the sea surface
    # temperature and salinity are used to compute an oceanic heat flux Fw (|Fw| ≤ |Ffrzmlt|) which is applied at
    # the bottom of the ice. The portion of the melting potential actually used to melt ice is returned to the coupler
    # in Fhocn.
    #
    # By reading the code of CICE, I know that Q_FRZMLTPOT in my model is
    # the variable "frzmlt" in CICE.
    #
    # If frzmlt < 0:
    # In ice_therm_vertical.F90 of lines 703-740, CICE model uses
    # frzmlt only when it is negative (T_ocean > T_sw_frz) to
    # compute the melting of sea ice.
    #
    # If frzmlt > 0:
    # In ice_therm_itd.F90 of lines 1000-1022, CIMICE uses positive frzmlt
    # to compute the amount of newly formed sea ice. 
    #
    # So, frzmlt > 0 has to be consistent with my energy gain due to freezing.
    # I can safely adapt the original "instant response" scheme to Newtonion
    # relaxation.
    #
    # If frzmlt < 0, I guess this melting potential is used by CICE model and
    # recompute the actual heat that would be taken away by sea ice, and this
    # amount of energy is then passed to "Fioi_melth". So it looks like I cannot
    # modify its definition because frzmlt positive and negative do not share
    # the same concep. frzmlt > 0 represents the actual energy transfer while
    # frzmlt < 0 represents temperature differences.
    #
    # *** This is potentially a CESM design flaw because freezing and
    # melting can happen at the same time. For example, ocean
    # surface is above freezing point and the bottom of ocean is
    # below freezing point. So, a way to imagine this still works is to modify
    # the convective adjustment scheme:
    #
    # If freezing happens somewhere below the ocean surface (top grid), the 
    # formed sea ice will float upward due to less density. This indirectly
    # produce turbulence, and hence increase the vertical diffusivity above 
    # this deep ocean grid.
    #
    # Also, I surprisingly find that sensible heat flux between atm and ocn
    # is not affected by the presence of sea ice. At least I cannot find anything
    # considering the sea ice when the coupler computes sensible heat flux in
    # "csm_share/shr/shr_flux_mod.F90" "Faox_sen, Foxx_sen"
    #
    # Maybe it is worth asking this question on CESM forum.
    #
    #sfc_below_frz_mask_T = co.mtx[:T_sfcmask_T] * (fi.sv[:_TEMP] .<  T_sw_frz)
    #sfc_above_frz_mask_T = co.mtx[:T_sfcmask_T] * (fi.sv[:_TEMP] .>= T_sw_frz)
    #T_sfc_below_frz_mask_T = spdiagm(0 => sfc_below_frz_mask_T)
    #T_sfc_above_frz_mask_T = spdiagm(0 => sfc_above_frz_mask_T)
    #op_frz   = - T_sfc_below_frz_mask_T * co.mtx[:T_invτ_frz_T]
    #op_TEMP += op_frz
    #RHS_TEMP .-= Δt * op_frz * (T_sw_frz * co.mtx[:ones_T])

    # Tackle freeze / melt potential
    ΔT_sT = getSpace!(wksp, sT, true)
    NEWSST = reshape(view(tmpfi.sv[:NEWTEMP], 1:1, :, :), :)
    @. ΔT_sT = NEWSST - T_sw_frz
    tmp = zeros(Float64, co.amo_slab.bmo.T_pts)
    tmp[ΔT_sT < 0.0] .= - 1.0 / cfg["τfrz"]
    T_frz_T = co.amo_slab.T_mask_T * spdiagm(0 => tmp)
            
    ΔT_sT = NEWSST .-  T_sw_frz
    sfc_below_frz_mask_sT = ΔT_sT .<  0
    sfc_above_frz_mask_sT = ΔT_sT .>= 0

    # Restore the surface water temperature
    NEWSST[sfc_below_frz_mask_sT] .= T_sw_frz

    # Determine the frz melt potential
    sfcΔz_sT = view(co.amo.gd.Δz_T, 1:1, :, :)

    fi.Q_FRZMLTPOT .= - (sfcΔz_sT .* ΔT_sT) * ρcp_sw / Δt

    fi.Q_FRZHEAT                              .= 0
    fi.Q_FRZHEAT[sfc_below_frz_mask_sT]       .= fi.Q_FRZMLTPOT[sfc_below_frz_mask_sT]
    fi.Q_FRZMLTPOT_NEG[sfc_above_frz_mask_sT] .= fi.Q_FRZMLTPOT[sfc_above_frz_mask_sT]
   
    #= 
    # It is possible that some of the Q_FRZHEAT and Q_FRZMLTPOT_NEG are not positive and negative anymore because
    # the mask is the old one while the Δ_TEMP is the new one. So in order to be consistent
    # with the energy, I will overwrite these values with zeros.
    if any(fi.Q_FRZHEAT .< 0)
        throw(ErrorException("[2] Something is wrong when computing freeze melt potential."))
    end    

    if any(fi.Q_FRZMLTPOT_NEG .> 0)
        throw(ErrorException("[1] Something is wrong when computing freeze melt potential."))
    end
    =# 
end
