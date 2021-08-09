
using SparseArrays

@inline function flat2_i(
    i :: Int64,
    j :: Int64,
    Nx :: Int64,
    Ny :: Int64,
)
    return i + (j-1) * Nx
end


@inline function flat3_i(
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
     
        mtx_interp_U = spzeros(Float64, (Nx+1) * Ny    , Nx     * Ny    )
        mtx_interp_V = spzeros(Float64, Nx     * (Ny+1), Nx     * Ny    )
        mtx_DIV_X    = spzeros(Float64, Nx     * Ny    , (Nx+1) * Ny    )
        mtx_DIV_Y    = spzeros(Float64, Nx     * Ny    , Nx     * (Ny+1))
        mtx_DIV_Z    = spzeros(Float64, Nx     * Ny    , Nx     * Ny    )
        mtx_GRAD_X   = spzeros(Float64, (Nx+1) * Ny    , Nx     * Ny    )
        mtx_GRAD_Y   = spzeros(Float64, Nx     * (Ny+1), Nx     * Ny    )
        mtx_GRAD_Z   = spzeros(Float64, (Nz_bone+1)    , Nz_bone        )
        mtx_CURV_X   = spzeros(Float64, Nx     * Ny    , (Nx+1) * Ny    )
        mtx_CURV_Y   = spzeros(Float64, Nx     * Ny    , Nx     * (Ny+1))
        mtx_CURV_Z   = spzeros(Float64, Nz_bone        , (Nz_bone+1)    )


        println("Making Interp Matrix")
        # ===== [BEGIN] Making interp matrix =====
        # x
        for i=1:Nx+1, j=1:Ny  # iterate through bounds
            ib   = flat2_i(i           , j, Nx+1, Ny)
            ic_e = flat2_i(cyc(i  ,Nx) , j, Nx  , Ny)
            ic_w = flat2_i(cyc(i-1,Nx) , j, Nx  , Ny)

            #u_bnd[k, i, j] = u[k, i-1, j] * (1.0 - weight_e[i, j]) + u[k, i, j] * weight_e[i, j]
            mtx_interp_U[ib, ic_w] = 1.0 - gi.weight_e[i, j] 
            mtx_interp_U[ib, ic_e] = gi.weight_e[i, j]
        end

        # y
        for i=1:Nx, j=2:Ny   # iterate through bounds
                    ib   = flat2_i(i, j  , Nx, Ny+1)
                    ic_n = flat2_i(i, j  , Nx, Ny  )
                    ic_s = flat2_i(i, j-1, Nx, Ny  )

                    #v_bnd[k, i, j] = v[k, i, j-1] * (1.0 - weight_n[i, j]) + v[k, i, j] * weight_n[i, j]
                    mtx_interp_V[ib, ic_s] = 1.0 - gi.weight_n[i, j] 
                    mtx_interp_V[ib, ic_n] = gi.weight_n[i, j]
        end
        # ===== [END] Making interp matrix =====

        println("Making Divergence Matrix")
        # ===== [BEGIN] Making divergent matrix =====
        # x and y
        for i=1:Nx, j=1:Ny  # iterate through face centers
            ic = flat2_i(i, j, Nx  , Ny)

            # X direction
            ib_e   = flat2_i(i+1, j, Nx+1, Ny)
            ib_w   = flat2_i(i  , j, Nx+1, Ny)

            mtx_DIV_X[ic, ib_e] =   gi.DY[i+1, j] / gi.dσ[i, j]
            mtx_DIV_X[ic, ib_w] = - gi.DY[i  , j] / gi.dσ[i, j]

            # Y direction
            ib_n   = flat2_i(i, j+1, Nx, Ny+1)
            ib_s   = flat2_i(i, j  , Nx, Ny+1)

            mtx_DIV_Y[ic, ib_n] =   gi.DX[i, j+1] / gi.dσ[i, j]
            mtx_DIV_Y[ic, ib_s] = - gi.DX[i, j  ] / gi.dσ[i, j]
        end

        for k=1:Nz_bone
            ic = k

            # Z direction
            ib_t   = k
            ib_b   = k+1

            mtx_DIV_Z[ic, ib_t] =   1.0 / hs[k, i, j]
            mtx_DIV_Z[ic, ib_b] = - 1.0 / hs[k, i, j]

        end
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
                    mtx_GRAD_X[ib, ic_e] =   1.0 / gi.dx_w[cyc(i, Nx), j]
                    mtx_GRAD_X[ib, ic_w] = - 1.0 / gi.dx_w[cyc(i, Nx), j] 
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

                    # ( qs[k, i, j] - qs[k, i, j-1] ) / gi.dy_s[i, j]
                    mtx_GRAD_Y[ib, ic_n] =   1.0 / gi.dy_s[i, j]
                    mtx_GRAD_Y[ib, ic_s] = - 1.0 / gi.dy_s[i, j]
                end
            end
        end

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
                mtx_GRAD_Z[ib, ic_t] =   1.0 / Δzs[k-1, i, j]
                mtx_GRAD_Z[ib, ic_b] = - 1.0 / Δzs[k-1, i, j]


                # Bottom is the same as the layer right above it.
                # This is necessary because the thickness of last layer might be
                # very thin due to topography to create instability during
                # doing adveciton.
                if k == _Nz
                    ib_b = flat_i(k+1, i, j, Nz_bone+1, Nx, Ny)
                    mtx_GRAD_Z[ib_b, ic_t] = mtx_GRAD_Z[ib, ic_t]
                    mtx_GRAD_Z[ib_b, ic_b] = mtx_GRAD_Z[ib, ic_b]
                end
            end

        end
        # ===== [END] Making GRAD matrix =====
        
        println("Making CURV Matrix")
        # ===== [BEGIN] Making CURV matrix =====
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

                mtx_CURV_X[ic, ib_e] =   1.0 / gi.dx_c[i, j]
                mtx_CURV_X[ic, ib_w] = - 1.0 / gi.dx_c[i, j]

                # Y direction
                # CURV_y[k, i, j] = ( GRAD_bnd_y[k, i  , j+1] - GRAD_bnd_y[k  , i, j] ) / gi.dy_c[i, j]
                ib_n   = flat_i(k, i, j+1, Nz_bone, Nx, Ny+1)
                ib_s   = flat_i(k, i, j  , Nz_bone, Nx, Ny+1)

                mtx_CURV_Y[ic, ib_n] =   1.0 / gi.dy_c[i, j]
                mtx_CURV_Y[ic, ib_s] = - 1.0 / gi.dy_c[i, j]

                # Z direction
                # CURV_z[k, i, j] = ( GRAD_bnd_z[k, i  , j  ] - GRAD_bnd_z[k+1, i, j] ) / hs[k, i, j]
                ib_t   = flat_i(k  , i, j, Nz_bone+1, Nx, Ny)
                ib_b   = flat_i(k+1, i, j, Nz_bone+1, Nx, Ny)

                mtx_CURV_Z[ic, ib_t] =   1.0 / hs[k, i, j]
                mtx_CURV_Z[ic, ib_b] = - 1.0 / hs[k, i, j]
            end
        end
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
