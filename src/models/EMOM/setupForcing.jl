function setupForcing!(
    mb   :: ModelBlock,
)
    ev = mb.ev
    fi = mb.fi
    co = mb.co
    cfg = ev.config

    gd = ev.gd 
 
    PolelikeCoordinate.project!(
        gd, 
        fi.TAUX_east,
        fi.TAUY_north,
        fi.TAUX,
        fi.TAUY;
        direction=:Forward,
        grid=:T,
    )

    
    # Setup Ekman Flow
    if cfg[:advection_scheme] == :static 

        fi._u .= 0.0
        fi._v .= 0.0
        fi._w .= 0.0

    elseif cfg[:advection_scheme] == :ekman_codron2012_partition
 
      
        f_sT = co.mtx[:f_sT]
        ϵ_sT = co.mtx[:ϵ_sT]
        invD_sT = co.mtx[:invD_sT]
        
        M_north = ( - f_sT .* fi.TAUX_east + ϵ_sT .* fi.TAUY_north  ) .* co.mtx[:invD_sT] / ρ_sw
        M_east  = (   ϵ_sT .* fi.TAUX_east + f_sT .* fi.TAUY_north  ) .* co.mtx[:invD_sT] / ρ_sw

        Mx_sT = copy(M_east)
        My_sT = copy(M_north)
 
        if cfg[:transform_vector_field]
            PolelikeCoordinate.project!(
                gd, 
                M_east,
                M_north,
                Mx_sT,
                My_sT;
                direction=:Forward,
                grid=:T,
            )
        end
 
        # notice that we drop the z dimension for simplicity in the for loop
        Mx_u = reshape( co.amo_slab.U_interp_T * view(Mx_sT, :), gd.Nx, gd.Ny)
        My_v = reshape( co.amo_slab.V_interp_T * view(My_sT, :), gd.Nx, gd.Ny+1)

        H_Ek = sum(gd.Δz_T[1:cfg[:Ekman_layers], 1, 1]) 
        H_Rf = sum(gd.Δz_T[(cfg[:Ekman_layers]+1):(cfg[:Ekman_layers]+cfg[:Returnflow_layers]), 1, 1]) 

        for k = 1:cfg[:Ekman_layers]
            fi.sv[:UVEL][k, :, :] .= Mx_u / H_Ek
            fi.sv[:VVEL][k, :, :] .= My_v / H_Ek
        end
 
        for k = (cfg[:Ekman_layers]+1):(cfg[:Ekman_layers]+cfg[:Returnflow_layers])
            fi.sv[:UVEL][k, :, :] .= - Mx_u / H_Rf
            fi.sv[:VVEL][k, :, :] .= - My_v / H_Rf
        end
        
        fi._u[:] = co.amo.U_flowmask_U * fi._u  
        fi._v[:] = co.amo.V_flowmask_V * fi._v
        fi._w[:] = co.amo.W_flowmask_W * fi._w
   
    elseif cfg[:advection_scheme] == :ekman_codron2012_partition
        
        
    end 
    
    # compute w
    DIVvol_T = reshape( co.amo.T_DIVy_V * fi._v + co.amo.T_DIVx_U * fi._u , co.amo.bmo.T_dim...)
    
    fi.sv[:WVEL][1, :, :] .= 0.0
    for k=1:gd.Nz
        fi.sv[:WVEL][k+1, :, :] .= fi.sv[:WVEL][k, :, :] + DIVvol_T[k, :, :] * gd.Δz_T[k, 1, 1]
    end

end
