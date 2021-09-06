function setupForcing!(
    mb   :: ModelBlock,
)
    ev = mb.ev
    fi = mb.fi
    co = mb.co
    cfg = ev.config

    gd = ev.gd
    gd_slab = ev.gd_slab
    amo_slab = co.amo_slab

    if cfg["transform_vector_field"]
        PolelikeCoordinate.project!(
            gd, 
            fi.TAUX_east,
            fi.TAUY_north,
            fi.TAUX,
            fi.TAUY;
            direction=:Forward,
            grid=:T,
        )
    else
        fi.TAUX .= fi.TAUX_east
        fi.TAUY .= fi.TAUY_north
    end



    # Setup Ekman Flow
    if cfg["advection_scheme"] == "static"

        fi._u .= 0.0
        fi._v .= 0.0
        fi._w .= 0.0

    elseif cfg["advection_scheme"] in [ "ekman_AGA2020", "ekman_KSC2018", "ekman_CO2012" ]

        Mx_east = nothing
        My_north = nothing

        if cfg["advection_scheme"] in [ "ekman_CO2012", "ekman_KSC2018" ]
            
            f_sT = co.mtx[:f_sT]
            ϵ_sT = co.mtx[:ϵ_sT]
            invD_sT = co.mtx[:invD_sT]
           
            if cfg["advection_scheme"] == "ekman_CO2012"
                switch = 1.0
            elseif cfg["advection_scheme"] == "ekman_KSC2018"
                switch = 0.0
            else
                throw(ErrorException("Unexpected scenario. Please check."))
            end
 
            Mx_east  = (   ϵ_sT .* fi.TAUX_east + f_sT .* fi.TAUY_north  ) .* invD_sT / ρ_sw
            My_north = ( - f_sT .* fi.TAUX_east + ϵ_sT .* fi.TAUY_north * switch  ) .* invD_sT / ρ_sw


        elseif cfg["advection_scheme"] == "ekman_AGA2020"

            if ! haskey(co.mtx, :wϵ2invβ_sT)
                co.mtx[:wϵ2invβ_sT] = co.mtx[:ϵ_sT].^2 * (gd.R / 2.0 / gd.Ω) .* (cos.(gd_slab.ϕ_T).^2)
            end

            f_sT = co.mtx[:f_sT]
            invD_sT = co.mtx[:invD_sT]
            wϵ2invβ_sT = co.mtx[:wϵ2invβ_sT]

            # First, I need to get the curl. I choose to
            # do the curl using line integral in ocean model
            # space
            curlτ_sT = reshape(
                amo_slab.T_CURLx_T * view(fi.TAUY, :) + amo_slab.T_CURLy_T * view(fi.TAUX, :),
                1, gd.Nx, gd.Ny,
            )
            
            Mx_east  = getSpace!(co.wksp, :sT; o=0.0)
            My_north = ( - f_sT .* fi.TAUX_east + wϵ2invβ_sT .* curlτ_sT ) .* co.mtx[:invD_sT] / ρ_sw

        else
            throw(ErrorException("Unexpected scenario. Please check."))
        end

        if Mx_east == nothing || My_north == nothing
            throw(ErrorException("Error: Either or both Mx_east or My_north are not assigned."))
        end

        Mx_sT = getSpace!(co.wksp, :sT; o=0.0)
        My_sT = getSpace!(co.wksp, :sT; o=0.0)

        PolelikeCoordinate.project!(
            gd, 
            Mx_east,
            My_north,
            Mx_sT,
            My_sT;
            direction=:Forward,
            grid=:T,
        )

        # notice that we drop the z dimension for simplicity in the for loop
        Mx_u = reshape( co.amo_slab.U_interp_T * view(Mx_sT, :), gd.Nx, gd.Ny)
        My_v = reshape( co.amo_slab.V_interp_T * view(My_sT, :), gd.Nx, gd.Ny+1)

        H_Ek = sum(gd.Δz_T[1:cfg["Ekman_layers"], 1, 1]) 
        H_Rf = sum(gd.Δz_T[(cfg["Ekman_layers"]+1):(cfg["Ekman_layers"]+cfg["Returnflow_layers"]), 1, 1]) 


        for k = 1:cfg["Ekman_layers"]
            fi.sv[:UVEL][k, :, :] .= Mx_u / H_Ek
            fi.sv[:VVEL][k, :, :] .= My_v / H_Ek
        end
 
        for k = (cfg["Ekman_layers"]+1):(cfg["Ekman_layers"]+cfg["Returnflow_layers"])
            fi.sv[:UVEL][k, :, :] .= - Mx_u / H_Rf
            fi.sv[:VVEL][k, :, :] .= - My_v / H_Rf
        end
        
        fi._u[:] = co.amo.U_flowmask_U * fi._u  
        fi._v[:] = co.amo.V_flowmask_V * fi._v
        fi._w[:] = co.amo.W_flowmask_W * fi._w

    else
        throw(ErrorException("Unknown scheme: " * string(cfg["advection_scheme"])))

    end 
    
    # compute w
    DIVvol_T = reshape( co.amo.T_DIVy_V * fi._v + co.amo.T_DIVx_U * fi._u , co.amo.bmo.T_dim...)
    
    fi.sv[:WVEL][1, :, :] .= 0.0
    for k=1:gd.Nz
        fi.sv[:WVEL][k+1, :, :] .= fi.sv[:WVEL][k, :, :] + DIVvol_T[k, :, :] * gd.Δz_T[k, 1, 1]
    end

end
