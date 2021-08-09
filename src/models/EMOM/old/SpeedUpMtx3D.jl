
using SparseArrays

@inline function flat_i(
    k :: Int64,
    i :: Int64,
    j :: Int64,
    Nz :: Int64,
    Nx :: Int64,
    Ny :: Int64,
)
    return k + (i-1) * Nz + (j-1) * Nz * Nx
end

@inline function cyc(i::Int64, N::Int64)
    return mod(i-1, N) + 1
end


mutable struct AdvectionSpeedUpMatrix

    mtx_interp_U :: AbstractArray{Float64, 2}
    mtx_interp_V :: AbstractArray{Float64, 2}
    mtx_DIV_X    :: AbstractArray{Float64, 2}
    mtx_DIV_Y    :: AbstractArray{Float64, 2}
    mtx_DIV_Z    :: AbstractArray{Float64, 2}
    mtx_GRAD_X   :: AbstractArray{Float64, 2}
    mtx_GRAD_Y   :: AbstractArray{Float64, 2}
    mtx_GRAD_Z   :: AbstractArray{Float64, 2}
    mtx_CURV_X   :: AbstractArray{Float64, 2}
    mtx_CURV_Y   :: AbstractArray{Float64, 2}
    mtx_CURV_Z   :: AbstractArray{Float64, 2}

    function AdvectionSpeedUpMatrix(;
        gi             :: DisplacedPoleCoordinate.GridInfo,
        Nx             :: Int64,
        Ny             :: Int64,
        Nz_bone        :: Int64,
        Nz             :: AbstractArray{Int64, 2},
        mask3          :: AbstractArray{Float64, 3},
        noflux_x_mask3 :: AbstractArray{Float64, 3},
        noflux_y_mask3 :: AbstractArray{Float64, 3},
        Δzs            :: AbstractArray{Float64, 3},
        hs             :: AbstractArray{Float64, 3},
    )
   # mtx_GRAD_x = spzeros(Float64, Nx * Ny * Nz_bone, (Nx+1) * Ny * Nz_bone)
   # mtx_GRAD_y = spzeros(Float64, Nx * Ny * Nz_bone, Nx * (Ny+1) * Nz_bone)
   # mtx_GRAD_z = spzeros(Float64, Nx * Ny * Nz_bone, Nx * Ny * (Nz_bone+1))
    
   # mtx_CURV :: AbstractArray{Float64, 2}
#=     
        mtx_interp_U = spzeros(Float64, Nz_bone * (Nx+1) * Ny    , Nz_bone     * Nx     * Ny    )
        mtx_interp_V = spzeros(Float64, Nz_bone * Nx     * (Ny+1), Nz_bone     * Nx     * Ny    )
        mtx_DIV_X    = spzeros(Float64, Nz_bone * Nx     * Ny    , Nz_bone     * (Nx+1) * Ny    )
        mtx_DIV_Y    = spzeros(Float64, Nz_bone * Nx     * Ny    , Nz_bone     * Nx     * (Ny+1))
        mtx_DIV_Z    = spzeros(Float64, Nz_bone * Nx     * Ny    , (Nz_bone+1) * Nx     * Ny    )
        mtx_GRAD_X   = spzeros(Float64, Nz_bone * (Nx+1) * Ny    , Nz_bone     * Nx     * Ny    )
        mtx_GRAD_Y   = spzeros(Float64, Nz_bone * Nx     * (Ny+1), Nz_bone     * Nx     * Ny    )
        mtx_GRAD_Z   = spzeros(Float64, (Nz_bone+1) * Nx * Ny    , Nz_bone     * Nx     * Ny    )
        mtx_CURV_X   = spzeros(Float64, Nz_bone * Nx     * Ny    , Nz_bone     * (Nx+1) * Ny    )
        mtx_CURV_Y   = spzeros(Float64, Nz_bone * Nx     * Ny    , Nz_bone     * Nx     * (Ny+1))
        mtx_CURV_Z   = spzeros(Float64, Nz_bone * Nx     * Ny    , (Nz_bone+1) * Nx     * Ny    )
=#


        elm_max = (Nz_bone+1)*(Nx+1)*(Ny+1) * 2 
        I = zeros(Int64, elm_max)
        J = zeros(Int64, elm_max)
        V = zeros(Float64, elm_max)
        idx = 0

        function add!(i::Int64, j::Int64, v::Float64)
            idx += 1
            I[idx] = i
            J[idx] = j
            V[idx] = v
        end

        function getSparse!(m::Int64, n::Int64)
            s = sparse(view(I, 1:idx), view(J, 1:idx), view(V, 1:idx), m, n)
            idx = 0
            return s 
        end

        #=
        mtx_interp_U = spzeros(Float64, Nz_bone * Nx     * Ny    , Nz_bone     * (Nx+1) * Ny    )
        mtx_interp_V = spzeros(Float64, Nz_bone * Nx     * Ny    , Nz_bone     * Nx     * (Ny+1))

        mtx_DIV_X    = spzeros(Float64, Nz_bone * (Nx+1) * Ny    , Nz_bone     * Nx     * Ny    )
        mtx_DIV_Y    = spzeros(Float64, Nz_bone * Nx     * (Ny+1), Nz_bone     * Nx     * Ny    )
        mtx_DIV_Z    = spzeros(Float64, (Nz_bone+1) * Nx     * Ny, Nz_bone     * Nx     * Ny    )

        mtx_GRAD_X   = spzeros(Float64, Nz_bone * Nx     * Ny    , Nz_bone     * (Nx+1) * Ny    )
        mtx_GRAD_Y   = spzeros(Float64, Nz_bone * Nx     * Ny    , Nz_bone     * Nx     * (Ny+1))
        mtx_GRAD_Z   = spzeros(Float64, Nz_bone * Nx     * Ny    , (Nz_bone+1) * Nx     * Ny    )

        mtx_CURV_X   = spzeros(Float64, Nz_bone * (Nx+1) * Ny    , Nz_bone     * Nx     * Ny    )
        mtx_CURV_Y   = spzeros(Float64, Nz_bone * Nx     * (Ny+1), Nz_bone     * Nx     * Ny    )
        mtx_CURV_Z   = spzeros(Float64, (Nz_bone+1) * Nx     * Ny, Nz_bone     * Nx     * Ny    )
        =#
        println("Making Interp Matrix")
        # ===== [BEGIN] Making interp matrix =====
        # x
        for i=1:Nx+1, j=1:Ny  # iterate through bounds
            for k=1:Nz[cyc(i, Nx), j]  # Bounds Nx+1 is the same as the bound 1
                if noflux_x_mask3[k, i, j] != 0.0
                    ib   = flat_i(k, i           , j, Nz_bone, Nx+1, Ny)
                    ic_e = flat_i(k, cyc(i  ,Nx) , j, Nz_bone, Nx  , Ny)
                    ic_w = flat_i(k, cyc(i-1,Nx) , j, Nz_bone, Nx  , Ny)

                    #u_bnd[k, i, j] = u[k, i-1, j] * (1.0 - weight_e[i, j]) + u[k, i, j] * weight_e[i, j]
                    add!(ib, ic_w, 1.0 - gi.weight_e[i, j])
                    add!(ib, ic_e, gi.weight_e[i, j])
                end
            end
        end
        mtx_interp_U = getSparse!(Nz_bone * (Nx+1) * Ny, Nz_bone * Nx * Ny)

        # y
        for i=1:Nx, j=2:Ny   # iterate through bounds
            for k=1:Nz[i, j]
               if noflux_y_mask3[k, i, j] != 0.0
                    ib   = flat_i(k, i, j  , Nz_bone, Nx, Ny+1)
                    ic_n = flat_i(k, i, j  , Nz_bone, Nx, Ny  )
                    ic_s = flat_i(k, i, j-1, Nz_bone, Nx, Ny  )

                    #v_bnd[k, i, j] = v[k, i, j-1] * (1.0 - weight_n[i, j]) + v[k, i, j] * weight_n[i, j]
                    add!(ib, ic_s, 1.0 - gi.weight_n[i, j])
                    add!(ib, ic_n, gi.weight_n[i, j])

                end

            end
        end
        mtx_interp_V = getSparse!(Nz_bone * Nx * (Ny+1), Nz_bone * Nx * Ny)

#=
        for i=1:Nx+1, j=1:Ny  # iterate through bounds
            for k=1:Nz[cyc(i, Nx), j]  # Bounds Nx+1 is the same as the bound 1
                if noflux_x_mask3[k, i, j] != 0.0
                    ib   = flat_i(k, i           , j, Nz_bone, Nx+1, Ny)
                    ic_e = flat_i(k, cyc(i  ,Nx) , j, Nz_bone, Nx  , Ny)
                    ic_w = flat_i(k, cyc(i-1,Nx) , j, Nz_bone, Nx  , Ny)

                    #u_bnd[k, i, j] = u[k, i-1, j] * (1.0 - weight_e[i, j]) + u[k, i, j] * weight_e[i, j]
                    mtx_interp_U[ic_w, ib] = 1.0 - gi.weight_e[i, j] 
                    mtx_interp_U[ic_e, ib] = gi.weight_e[i, j]
                end
            end
        end

        # y
        for i=1:Nx, j=2:Ny   # iterate through bounds
            for k=1:Nz[i, j]
               if noflux_y_mask3[k, i, j] != 0.0
                    ib   = flat_i(k, i, j  , Nz_bone, Nx, Ny+1)
                    ic_n = flat_i(k, i, j  , Nz_bone, Nx, Ny  )
                    ic_s = flat_i(k, i, j-1, Nz_bone, Nx, Ny  )

                    #v_bnd[k, i, j] = v[k, i, j-1] * (1.0 - weight_n[i, j]) + v[k, i, j] * weight_n[i, j]
                    mtx_interp_V[ic_s, ib] = 1.0 - gi.weight_n[i, j] 
                    mtx_interp_V[ic_n, ib] = gi.weight_n[i, j]
                end

            end
        end
=#
        # ===== [END] Making interp matrix =====

        println("Making Divergence Matrix")
        # ===== [BEGIN] Making divergent matrix =====

        # x
        for i=1:Nx, j=1:Ny  # iterate through face centers
            for k=1:Nz[i, j]
                if mask3[k, i, j] == 0.0
                    break
                end

                ic = flat_i(k, i, j, Nz_bone, Nx  , Ny)

                # X direction
                ib_e   = flat_i(k, i+1, j, Nz_bone, Nx+1, Ny)
                ib_w   = flat_i(k, i  , j, Nz_bone, Nx+1, Ny)

                add!(ic, ib_e,   gi.DY[i+1, j] / gi.dσ[i, j])
                add!(ic, ib_w, - gi.DY[i  , j] / gi.dσ[i, j])

            end
        end
        mtx_DIV_X = getSparse!(Nz_bone * Nx * Ny, Nz_bone * (Nx+1) * Ny)

        # y
        for i=1:Nx, j=1:Ny  # iterate through face centers
            for k=1:Nz[i, j]
                if mask3[k, i, j] == 0.0
                    break
                end

                ic = flat_i(k, i, j, Nz_bone, Nx  , Ny)

                # Y direction
                ib_n   = flat_i(k, i, j+1, Nz_bone, Nx, Ny+1)
                ib_s   = flat_i(k, i, j  , Nz_bone, Nx, Ny+1)


                #add!(ic, ib_n,   gi.DX[i, j] / gi.dσ[i, j])
                add!(ic, ib_n,   gi.DX[i, j+1] / gi.dσ[i, j])
                add!(ic, ib_s, - gi.DX[i, j  ] / gi.dσ[i, j])

                #add!(ic, ib_n, 0.0)#   gi.DX[i, j+1] / gi.dσ[i, j])
                #add!(ic, ib_s, 0.0)#- gi.DX[i, j  ] / gi.dσ[i, j])


            end
        end
        mtx_DIV_Y = getSparse!(Nz_bone * Nx * Ny, Nz_bone * Nx * (Ny+1))

        # z
        for i=1:Nx, j=1:Ny  # iterate through face centers
            for k=1:Nz[i, j]
                if mask3[k, i, j] == 0.0
                    break
                end

                ic = flat_i(k, i, j, Nz_bone, Nx  , Ny)

                # Z direction
                ib_t   = flat_i(k  , i, j, Nz_bone+1, Nx, Ny)
                ib_b   = flat_i(k+1, i, j, Nz_bone+1, Nx, Ny)

                add!(ic, ib_t,   1.0 / hs[k, i, j])
                add!(ic, ib_b, - 1.0 / hs[k, i, j])

            end
        end
        mtx_DIV_Z = getSparse!(Nz_bone * Nx * Ny, (Nz_bone+1) * Nx * Ny)
        # ===== [END] Making divergent matrix =====
        
        println("Making GRAD Matrix")
        # ===== [BEGIN] Making GRAD matrix =====
        # x
        for i=1:Nx+1, j=1:Ny  # iterate through bounds
            for k=1:Nz[cyc(i, Nx), j]  # Bounds Nx+1 is the same as the bound 1
                if noflux_x_mask3[k, i, j] != 0.0
                    ib   = flat_i(k, i           , j, Nz_bone, Nx+1, Ny)
                    ic_e = flat_i(k, cyc(i  ,Nx) , j, Nz_bone, Nx  , Ny)
                    ic_w = flat_i(k, cyc(i-1,Nx) , j, Nz_bone, Nx  , Ny)
                    
                    # ( qs[k, i, j] - qs[k, i-1, j] ) / gi.dx_w[i, j] 
                    add!(ib, ic_e,   1.0 / gi.dx_w[cyc(i, Nx), j])
                    add!(ib, ic_w, - 1.0 / gi.dx_w[cyc(i, Nx), j])
                end
            end
        end
        mtx_GRAD_X = getSparse!(Nz_bone * (Nx+1) * Ny, Nz_bone * Nx * Ny)

        # y
        for i=1:Nx, j=2:Ny   # iterate through bounds
            for k=1:Nz[i, j]
               if noflux_y_mask3[k, i, j] != 0.0
                    ib   = flat_i(k, i, j  , Nz_bone, Nx, Ny+1)
                    ic_n = flat_i(k, i, j  , Nz_bone, Nx, Ny  )
                    ic_s = flat_i(k, i, j-1, Nz_bone, Nx, Ny  )

                    # ( qs[k, i, j] - qs[k, i, j-1] ) / gi.dy_s[i, j]
                    add!(ib, ic_n,   1.0 / gi.dy_s[i, j])
                    add!(ib, ic_s, - 1.0 / gi.dy_s[i, j])
                end
            end
        end
        mtx_GRAD_Y = getSparse!(Nz_bone * Nx * (Ny+1), Nz_bone * Nx * Ny)

        # z
        for i=1:Nx, j=1:Ny   # iterate through bounds

            if mask3[1, i, j] == 0.0
                continue
            end
        
            _Nz = Nz[i, j]

            # The frist layer of w is zero -- means do not assign any value to this row
 
            # Assign from the second row
            for k=2:_Nz
                ib   = flat_i(k  , i, j, Nz_bone+1, Nx, Ny)
                ic_t = flat_i(k-1, i, j, Nz_bone  , Nx, Ny)
                ic_b = flat_i(k  , i, j, Nz_bone  , Nx, Ny)

                # ( qs[k-1, i, j] - qs[k, i, j] ) / Δzs[k-1, i, j]
                add!(ib, ic_t,   1.0 / Δzs[k-1, i, j])
                add!(ib, ic_b, - 1.0 / Δzs[k-1, i, j])


                # Bottom is the same as the layer right above it.
                # This is necessary because the thickness of last layer might be
                # very thin due to topography to create instability during
                # doing adveciton.
                if k == _Nz
                    ib_b = flat_i(k+1, i, j, Nz_bone+1, Nx, Ny)
                    add!(ib_b, ic_t,   1.0 / Δzs[k-1, i, j])
                    add!(ib_b, ic_b, - 1.0 / Δzs[k-1, i, j])
                end
            end

        end
        mtx_GRAD_Z = getSparse!((Nz_bone+1) * Nx * Ny, Nz_bone * Nx * Ny)
        # ===== [END] Making GRAD matrix =====
        
        println("Making CURV Matrix")
        # ===== [BEGIN] Making CURV matrix =====

        # x
        for i=1:Nx, j=1:Ny
            for k=1:Nz[i, j]
                if mask3[k, i, j] == 0.0
                    break
                end

                ic = flat_i(k, i, j, Nz_bone, Nx  , Ny)

                # X direction
                # CURV_x[k, i, j] = ( GRAD_bnd_x[k, i+1, j  ] - GRAD_bnd_x[k  , i, j] ) / gi.dx_c[i, j]
                ib_e   = flat_i(k, i+1, j, Nz_bone, Nx+1, Ny)
                ib_w   = flat_i(k, i  , j, Nz_bone, Nx+1, Ny)

                add!(ic, ib_e,   1.0 / gi.dx_c[i, j])
                add!(ic, ib_w, - 1.0 / gi.dx_c[i, j])

            end
        end
        mtx_CURV_X = getSparse!(Nz_bone * Nx * Ny, Nz_bone * (Nx+1) * Ny)

        for i=1:Nx, j=1:Ny
            for k=1:Nz[i, j]
                if mask3[k, i, j] == 0.0
                    break
                end

                ic = flat_i(k, i, j, Nz_bone, Nx  , Ny)

                # Y direction
                # CURV_y[k, i, j] = ( GRAD_bnd_y[k, i  , j+1] - GRAD_bnd_y[k  , i, j] ) / gi.dy_c[i, j]
                ib_n   = flat_i(k, i, j+1, Nz_bone, Nx, Ny+1)
                ib_s   = flat_i(k, i, j  , Nz_bone, Nx, Ny+1)

                add!(ic, ib_n,   1.0 / gi.dy_c[i, j])
                add!(ic, ib_s, - 1.0 / gi.dy_c[i, j])

            end
        end
        mtx_CURV_Y = getSparse!(Nz_bone * Nx * Ny, Nz_bone * Nx * (Ny+1))


        for i=1:Nx, j=1:Ny
            for k=1:Nz[i, j]
                if mask3[k, i, j] == 0.0
                    break
                end

                ic = flat_i(k, i, j, Nz_bone, Nx  , Ny)

                # Z direction
                # CURV_z[k, i, j] = ( GRAD_bnd_z[k, i  , j  ] - GRAD_bnd_z[k+1, i, j] ) / hs[k, i, j]
                ib_t   = flat_i(k  , i, j, Nz_bone+1, Nx, Ny)
                ib_b   = flat_i(k+1, i, j, Nz_bone+1, Nx, Ny)

                add!(ic, ib_t,   1.0 / hs[k, i, j])
                add!(ic, ib_b, - 1.0 / hs[k, i, j])
            end
        end
        mtx_CURV_Z = getSparse!(Nz_bone * Nx * Ny, (Nz_bone+1) * Nx * Ny)
        # ===== [END] Making CURV matrix =====

        return new(
            mtx_interp_U,
            mtx_interp_V,
            mtx_DIV_X, 
            mtx_DIV_Y,  
            mtx_DIV_Z,  
            mtx_GRAD_X,  
            mtx_GRAD_Y,  
            mtx_GRAD_Z,  
            mtx_CURV_X,  
            mtx_CURV_Y,  
            mtx_CURV_Z,  
        )
    end
end
