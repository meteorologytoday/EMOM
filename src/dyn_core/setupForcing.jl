function setupForcing!(
    mb    :: ModelBlock;
    w_max :: Float64,
)
    ev = mb.ev
    fi = mb.fi
    co = mb.co
    cfg = ev.cfgs["MODEL_CORE"]
    wksp = co.wksp
    gd = ev.gd
    gd_slab = ev.gd_slab
    amo = co.amo
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

    elseif cfg["advection_scheme"] in [ "ekman_AGA2020", "ekman_AGA2020_allowU", "ekman_KSC2018", "ekman_CO2012" ]

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


        elseif cfg["advection_scheme"] in [ "ekman_AGA2020", "ekman_AGA2020_allowU" ]

            if ! haskey(co.mtx, :ϵ2invβ_sT)
                co.mtx[:ϵ2invβ_sT] = co.mtx[:ϵ_sT].^2 * (gd.R / 2.0 / gd.Ω)
            end

            f_sT = co.mtx[:f_sT]
            ϵ_sT = co.mtx[:ϵ_sT]
            invD_sT = co.mtx[:invD_sT]
            ϵ2invβ_sT = co.mtx[:ϵ2invβ_sT]
            γ = cfg["γ"]    

            # First, I need to get the curl. I choose to
            # do the curl using line integral in ocean model
            # space
            curlτ_sT = reshape(
                amo_slab.T_CURLx_T * view(fi.TAUY, :) + amo_slab.T_CURLy_T * view(fi.TAUX, :),
                1, gd.Nx, gd.Ny,
            )
           
            if cfg["advection_scheme"] == "ekman_AGA2020_allowU"
                switch = 1.0
            elseif cfg["advection_scheme"] == "ekman_AGA2020"
                switch = 0.0
            else
                throw(ErrorException("Unexpected scenario. Please check."))
            end

            Mx_east  = (   f_sT .* fi.TAUY_north  ) .* invD_sT / ρ_sw
            My_north = ( - f_sT .* fi.TAUX_east + γ * ϵ2invβ_sT .* curlτ_sT ) .* co.mtx[:invD_sT] / ρ_sw

        else
            throw(ErrorException("Unexpected scenario. Please check."))
        end

        if Mx_east == nothing || My_north == nothing
            throw(ErrorException("Error: Either or both Mx_east or My_north are not assigned."))
        end

        Mx_sT = getSpace!(wksp, :sT; o=0.0)
        My_sT = getSpace!(wksp, :sT; o=0.0)

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
            fi.sv[:UVEL][k, :, :] .= Mx_u ./ H_Ek
            fi.sv[:VVEL][k, :, :] .= My_v ./ H_Ek
        end
 
        for k = (cfg["Ekman_layers"]+1):(cfg["Ekman_layers"]+cfg["Returnflow_layers"])
            fi.sv[:UVEL][k, :, :] .= - Mx_u ./ H_Rf
            fi.sv[:VVEL][k, :, :] .= - My_v ./ H_Rf
        end
        
    else
        throw(ErrorException("Unknown scheme: " * string(cfg["advection_scheme"])))

    end 


    _u = getSpace!(wksp, :U, true)
    _v = getSpace!(wksp, :V, true)
    _w = getSpace!(wksp, :W, true)

    _u[:] = fi._u
    _v[:] = fi._v
    _w[:] = fi._w

    mul!(fi._u, co.amo.U_flowmask_U, _u) 
    mul!(fi._v, co.amo.V_flowmask_V, _v) 
    mul!(fi._w, co.amo.W_flowmask_W, _w) 
    
    tmp_T  = getSpace!(wksp, :T, true)
    tmp2_T = getSpace!(wksp, :T, true)
    
    mul!(tmp_T, co.amo.T_DIVx_U, fi._u)
    mul!(tmp_T, co.amo.T_DIVy_V, fi._v, 1.0, 1.0)

    # compute w
    DIVvol_T = reshape( tmp_T, amo.bmo.T_dim...) 
    
    fi.sv[:WVEL][1, :, :] .= 0.0
    for k=1:gd.Nz
        fi.sv[:WVEL][k+1, :, :] .= fi.sv[:WVEL][k, :, :] + DIVvol_T[k, :, :] * gd.Δz_T[k, 1, 1]
    end

    CFL_break = 0
    violate_w_max = 0.0
    violate_w_min = 0.0
    for (i, w) in enumerate(fi._w)
        if w > w_max
            CFL_break += 1
            fi._w[i] = w_max
            violate_w_max = max(violate_w_max, w)
        elseif w < - w_max
            CFL_break += 1
            fi._w[i] = - w_max
            violate_w_min = min(violate_w_min, w)
        end
    end
    if CFL_break != 0
        println("CFL condition breaks in $(CFL_break) grid points. Arbitrarily cap w = ±$(w_max). Violated w (min, max) = ($(violate_w_min), $(violate_w_max))")
    end
end
