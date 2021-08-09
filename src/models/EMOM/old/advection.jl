function calDIV!(;
    ASUM      :: AdvectionSpeedUpMatrix,
    u_U       :: AbstractArray{Float64, 3},   # ( Nz_bone  , Nx  , Ny   )
    v_V       :: AbstractArray{Float64, 3},   # ( Nz_bone  , Nx  , Ny+1 )
    div       :: AbstractArray{Float64, 3},   # ( Nz_bone  , Nx  , Ny   )
    workspace :: AbstractArray{Float64, 3},   # ( Nz_bone  , Nx  , Ny   )
)

    
    mul_autoflat!(div,       ASUM.T_DIVx_U, u_U)
    mul_autoflat!(workspace, ASUM.T_DIVy_V, v_V)
    @. div += workspace

end


function calDiffAdv_QUICK_SpeedUp!(
    ocn         :: Ocean;
    qs          :: AbstractArray{Float64, 3},
    dΔqdt       :: AbstractArray{Float64, 2},     # ( Nx, Ny )
    FLUX_CONV   :: AbstractArray{Float64, 3},
    FLUX_CONV_h :: AbstractArray{Float64, 3},
    FLUX_DEN_x  :: AbstractArray{Float64, 3},     # ( Nz_bone   ,  Nx+1, Ny   )
    FLUX_DEN_y  :: AbstractArray{Float64, 3},     # ( Nz_bone   ,  Nx  , Ny+1 )
    FLUX_DEN_z  :: AbstractArray{Float64, 3},     # ( Nz_bone+1 ,  Nx  , Ny   )
    Dh          :: Float64,
    Dv          :: Float64,
    Δt          :: Float64,
)

    wksp = ocn.wksp
    ASUM = ocn.ASUM

    tmp1 = getSpace!(wksp, :T)
    tmp2 = getSpace!(wksp, :T)

   #println("GRAD_CRUV")
        
    mul_autoflat!(ocn.GRAD_bnd_x, ASUM.U_∂x_T, qs)
    mul_autoflat!(ocn.GRAD_bnd_y, ASUM.V_∂y_T, qs)
    mul_autoflat!(ocn.GRAD_bnd_z, ASUM.W_∂z_T, qs)
        
    mul_autoflat!(ocn.CURV_x, ASUM.T_∂x_U, ocn.GRAD_bnd_x)
    mul_autoflat!(ocn.CURV_y, ASUM.T_∂y_V, ocn.GRAD_bnd_y)
    mul_autoflat!(ocn.CURV_z, ASUM.T_∂z_W, ocn.GRAD_bnd_z)
    
    calFluxDensity_abstract!(;
        X_T                 = qs,
        u_bnd               = ocn.u_bnd,
        GRAD_bnd            = ocn.GRAD_bnd_x,
        CURV_T              = ocn.CURV_x,
        FLUX_DEN_bnd        = FLUX_DEN_x,
        K                   = Dh,
        Δt                  = Δt,
        Δx_bnd              = ASUM.Δx_U,
        
        op_bnd_∂x_T         = ASUM.U_∂x_T,
        op_T_∂x_bnd         = ASUM.T_∂x_U,
        op_bnd_pos_dir_T    = ASUM.op.U_E_T,
        op_bnd_neg_dir_T    = ASUM.op.U_W_T,
        op_bnd_interp_T     = ASUM.U_interp_T,
        op_filter_bnd       = ASUM.U_fluxmask_U,

        pos_u_mask_bnd      = getSpace!(wksp, :U),
        CURV_on_pos_dir_bnd = getSpace!(wksp, :U),
        CURV_on_neg_dir_bnd = getSpace!(wksp, :U),
        CURV_r_bnd          = getSpace!(wksp, :U),
        uΔt_bnd             = getSpace!(wksp, :U),
        X_star_bnd          = getSpace!(wksp, :U),

    )

    calFluxDensity_abstract!(;
        X_T                 = qs,
        u_bnd               = ocn.v_bnd,
        GRAD_bnd            = ocn.GRAD_bnd_y,
        CURV_T              = ocn.CURV_y,
        FLUX_DEN_bnd        = FLUX_DEN_y,
        K                   = Dh,
        Δt                  = Δt,
        Δx_bnd              = ASUM.Δy_V,

        op_bnd_∂x_T         = ASUM.V_∂y_T,
        op_T_∂x_bnd         = ASUM.T_∂y_V,
        op_bnd_pos_dir_T    = ASUM.op.V_N_T,
        op_bnd_neg_dir_T    = ASUM.op.V_S_T,
        op_bnd_interp_T     = ASUM.V_interp_T,
        op_filter_bnd       = ASUM.V_fluxmask_V,

        pos_u_mask_bnd      = getSpace!(wksp, :V),
        CURV_on_pos_dir_bnd = getSpace!(wksp, :V),
        CURV_on_neg_dir_bnd = getSpace!(wksp, :V),
        CURV_r_bnd          = getSpace!(wksp, :V),
        uΔt_bnd             = getSpace!(wksp, :V),
        X_star_bnd          = getSpace!(wksp, :V),
   
    )

    calFluxDensity_abstract!(;
        X_T                 = qs,
        u_bnd               = ocn.w_bnd,
        GRAD_bnd            = ocn.GRAD_bnd_z,
        CURV_T              = ocn.CURV_z,
        FLUX_DEN_bnd        = FLUX_DEN_z,
        K                   = Dv,
        Δt                  = Δt,
        Δx_bnd              = ASUM.Δz_W,
 
        op_bnd_∂x_T         = ASUM.W_∂z_T,
        op_T_∂x_bnd         = ASUM.T_∂z_W,
        op_bnd_pos_dir_T    = ASUM.op.W_UP_T,
        op_bnd_neg_dir_T    = ASUM.op.W_DN_T,
        op_bnd_interp_T     = ASUM.W_interp_T,
        op_filter_bnd       = ASUM.W_fluxmask_W,

        pos_u_mask_bnd      = getSpace!(wksp, :W),
        CURV_on_pos_dir_bnd = getSpace!(wksp, :W),
        CURV_on_neg_dir_bnd = getSpace!(wksp, :W),
        CURV_r_bnd          = getSpace!(wksp, :W),
        uΔt_bnd             = getSpace!(wksp, :W),
        X_star_bnd          = getSpace!(wksp, :W),
   
    )


    mul_autoflat!(FLUX_CONV_h, ASUM.T_DIVx_U, FLUX_DEN_x)
    mul_autoflat!(tmp1,        ASUM.T_DIVy_V, FLUX_DEN_y)
    mul_autoflat!(tmp2,        ASUM.T_DIVz_W, FLUX_DEN_z)

    @. FLUX_CONV_h = -1.0 * (FLUX_CONV_h + tmp1)
    @. FLUX_CONV = FLUX_CONV_h - tmp2


   #println("CALMIXEDLAYER")
    calMixedLayer_dΔqdt!(
        Nx          = ocn.Nx,
        Ny          = ocn.Ny,
        Nz          = ocn.Nz,
        FLUX_CONV_h = FLUX_CONV_h,
        FLUX_DEN_z  = FLUX_DEN_z,
        dΔqdt       = dΔqdt,
        mask        = ocn.mask,
        FLDO        = ocn.FLDO,
        h_ML        = ocn.h_ML,
        hs          = ocn.hs,
        zs          = ocn.zs,
    )
end

function calFluxDensity_abstract!(;
    X_T                       :: AbstractArray{Float64, 3},
    u_bnd                     :: AbstractArray{Float64, 3},
    GRAD_bnd                  :: AbstractArray{Float64, 3}, 
    CURV_T                    :: AbstractArray{Float64, 3},
    FLUX_DEN_bnd              :: AbstractArray{Float64, 3},
    K                         :: Float64,
    Δt                        :: Float64,
    Δx_bnd                    :: AbstractArray{Float64, 3},

    op_bnd_∂x_T               :: AbstractArray{Float64, 2},
    op_T_∂x_bnd               :: AbstractArray{Float64, 2},
    op_bnd_pos_dir_T          :: AbstractArray{Float64, 2},
    op_bnd_neg_dir_T          :: AbstractArray{Float64, 2},
    op_bnd_interp_T           :: AbstractArray{Float64, 2},
    op_filter_bnd             :: AbstractArray{Float64, 2},

    pos_u_mask_bnd            :: AbstractArray{Float64, 3},
    CURV_on_pos_dir_bnd       :: AbstractArray{Float64, 3},
    CURV_on_neg_dir_bnd       :: AbstractArray{Float64, 3},
    CURV_r_bnd                :: AbstractArray{Float64, 3},
    uΔt_bnd                   :: AbstractArray{Float64, 3},
    X_star_bnd                :: AbstractArray{Float64, 3},
)

    mul_autoflat!(GRAD_bnd, op_bnd_∂x_T, X_T)
    mul_autoflat!(CURV_T, op_T_∂x_bnd, GRAD_bnd)

    @. pos_u_mask_bnd = u_bnd >= 0
    mul_autoflat!(CURV_on_pos_dir_bnd, op_bnd_neg_dir_T, CURV_T)
    mul_autoflat!(CURV_on_neg_dir_bnd, op_bnd_pos_dir_T, CURV_T)
    @. CURV_r_bnd = CURV_on_neg_dir_bnd * pos_u_mask_bnd + CURV_on_pos_dir_bnd * (1-pos_u_mask_bnd)

    @. uΔt_bnd    = u_bnd * Δt
    mul_autoflat!(X_star_bnd, op_bnd_interp_T, X_T)
    #verbose && println("interpolated: ", X_T[1,37,23])
    @. X_star_bnd = X_star_bnd - uΔt_bnd / 2.0 * GRAD_bnd + ( K * Δt / 2.0 - Δx_bnd^2.0/6.0 + uΔt_bnd^2.0 / 6.0 ) * CURV_r_bnd
    #verbose && println("X_star_bnd: ", X_T[1,37,23])

    # reuse
    empty = uΔt_bnd
    @. empty = u_bnd * X_star_bnd - K * ( GRAD_bnd - uΔt_bnd / 2.0 * CURV_r_bnd )
    
    #verbose && println("Flux: ", empty[1,37,23])

    mul_autoflat!(FLUX_DEN_bnd, op_filter_bnd, empty)
    

    #verbose && println("Flux after filter: ", FLUX_DEN_bnd[1,37,23])
    #verbose && println("speed bnd : ", u_bnd[1,37,23])

    

end


function calMixedLayer_dΔqdt!(;
    Nx          :: Integer,
    Ny          :: Integer,
    Nz          :: AbstractArray{Int64, 2},
    FLUX_CONV_h :: AbstractArray{Float64, 3},     # ( Nz_bone  ,  Nx, Ny )
    FLUX_DEN_z  :: AbstractArray{Float64, 3},     # ( Nz_bone+1,  Nx, Ny )
    dΔqdt       :: AbstractArray{Float64, 2},     # ( Nx, Ny )
    mask        :: AbstractArray{Float64, 2},     # ( Nx, Ny )
    FLDO        :: AbstractArray{Int64, 2},       # ( Nx, Ny )
    h_ML        :: AbstractArray{Float64, 2},     # ( Nx, Ny )
    hs          :: AbstractArray{Float64, 3},     # ( Nz_bone  ,  Nx, Ny )
    zs          :: AbstractArray{Float64, 3},     # ( Nz_bone+1,  Nx, Ny )
) 

    for i=1:Nx, j=1:Ny

        if mask[i, j] == 0.0
            continue
        end

        _FLDO = FLDO[i, j]

        if _FLDO == -1
            continue
        end

        tmp = 0.0
        for k = 1:_FLDO-1
            tmp += FLUX_CONV_h[k, i, j] * hs[k, i, j]
        end
        tmp += ( 
              FLUX_CONV_h[_FLDO, i, j] * zs[_FLDO, i, j] 
            + ( FLUX_DEN_z[_FLDO+1, i, j] * zs[_FLDO, i, j] - FLUX_DEN_z[_FLDO, i, j] * zs[_FLDO+1, i, j] ) / hs[_FLDO, i, j]
        )

        dΔqdt[i, j] = tmp / h_ML[i, j]
    end

end

function calDIV!(;
    gi       :: DisplacedPoleCoordinate.GridInfo,
    Nx       :: Integer,
    Ny       :: Integer,
    Nz       :: AbstractArray{Int64, 2},
    u_bnd    :: AbstractArray{Float64, 3},   # ( Nz_bone  , Nx+1, Ny   )
    v_bnd    :: AbstractArray{Float64, 3},   # ( Nz_bone  , Nx  , Ny+1 )
    div      :: AbstractArray{Float64, 3},   # ( Nz_bone  , Nx  , Ny   )
    mask3    :: AbstractArray{Float64, 3},   # ( Nz_bone  , Nx  , Ny   )
)

#    local tmp = tmp_σ = 0.0
    for i=1:Nx, j=1:Ny

        for k=1:Nz[i, j]

            if mask3[k, i, j] == 0.0
                break
            end
            
            div[k, i, j] =  (  
                u_bnd[k, i+1, j  ]  * gi.DY[i+1, j  ]
              - u_bnd[k, i,   j  ]  * gi.DY[i  , j  ]
              + v_bnd[k, i,   j+1]  * gi.DX[i  , j+1]
              - v_bnd[k, i,   j  ]  * gi.DX[i  , j  ]
            ) / gi.dσ[i, j]

        end

    end


end



function calVerVelBnd!(;
    gi       :: DisplacedPoleCoordinate.GridInfo,
    Nx       :: Integer,
    Ny       :: Integer,
    Nz       :: AbstractArray{Int64, 2},
    w_bnd    :: AbstractArray{Float64, 3},   # ( Nz_bone+1, Nx  , Ny   )
    hs       :: AbstractArray{Float64, 3},   # ( Nz_bone  , Nx  , Ny   )
    div      :: AbstractArray{Float64, 3},   # ( Nz_bone  , Nx  , Ny   )
    mask3    :: AbstractArray{Float64, 3},   # ( Nz_bone  , Nx  , Ny   )
)

#    local tmp = tmp_σ = 0.0
    for i=1:Nx, j=1:Ny

        w_bnd[1, i, j] = 0.0

        for k=1:Nz[i, j]

            if mask3[k, i, j] == 0.0
                break
            end
            
            w_bnd[k+1, i, j] = w_bnd[k, i, j] + div[k, i, j] * hs[k, i, j]
        end

#        tmp   += w_bnd[Nz[i, j]+1, i, j] * gi.dσ[i, j]
#        tmp_σ += gi.dσ[i, j]
    end

#   #println("tmp: ", tmp, "; tmp_σ: ", tmp_σ, "; Average w: ", tmp/tmp_σ)

end



function calHorVelBnd!(;
    Nx       :: Integer,
    Ny       :: Integer,
    Nz       :: AbstractArray{Int64, 2},
    weight_e :: AbstractArray{Float64, 2},   # (Nx+1, Ny)
    weight_n :: AbstractArray{Float64, 2},   # (Nx, Ny+1)
    u        :: AbstractArray{Float64, 3},   # (Nz_bone, Nx, Ny)
    v        :: AbstractArray{Float64, 3},   # (Nz_bone, Nx, Ny)
    u_bnd    :: AbstractArray{Float64, 3},   # (Nz_bone, Nx+1, Ny)
    v_bnd    :: AbstractArray{Float64, 3},   # (Nz_bone, Nx, Ny+1)
    mask3    :: AbstractArray{Float64, 3},   # (Nz_bone, Nx, Ny)
    noflux_x_mask3 :: AbstractArray{Float64, 3}, # (Nz_bone, Nx+1, Ny)
    noflux_y_mask3 :: AbstractArray{Float64, 3}, # (Nz_bone, Nx, Ny+1)
)

    # x
    for i=2:Nx, j=1:Ny
        for k=1:Nz[i, j]
            if noflux_x_mask3[k, i, j] == 0.0
                u_bnd[k, i, j] = 0.0
            else
                u_bnd[k, i, j] = u[k, i-1, j] * (1.0 - weight_e[i, j]) + u[k, i, j] * weight_e[i, j]
                #u_bnd[k, i, j] = (u[k, i-1, j] + u[k, i, j]) / 2.0
            end
        end
    end
    
    # x - periodic
    for j=1:Ny
        for k=1:Nz[1, j]
            if noflux_x_mask3[k, 1, j] == 0.0
                u_bnd[k, 1, j] = u_bnd[k, Nx+1, j] = 0.0
            else
                u_bnd[k, 1, j] = u_bnd[k, Nx+1, j] = u[k, Nx, j] * (1.0 - weight_e[1, j]) + u[k, 1, j] * weight_e[1, j]
                #u_bnd[k, 1, j] = u_bnd[k, Nx+1, j] = (u[k, Nx, j] + u[k, 1, j]) / 2.0
            end
        end
    end

    # y
    for i=1:Nx, j=2:Ny
        for k=1:Nz[i, j]
            if noflux_y_mask3[k, i, j] == 0.0
                v_bnd[k, i, j] = 0.0
            else
                v_bnd[k, i, j] = v[k, i, j-1] * (1.0 - weight_n[i, j]) + v[k, i, j] * weight_n[i, j]
                #v_bnd[k, i, j] = (v[k, i, j-1] + v[k, i, j]) / 2.0
            end
        end
    end

end
