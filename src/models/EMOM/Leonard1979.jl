function calDiffAdv_QUICKEST!(
    Xflx_U  :: AbstractArray{Float64},
    Xflx_V  :: AbstractArray{Float64},
    Xflx_W  :: AbstractArray{Float64},

    X       :: AbstractArray{Float64},
    u_U     :: AbstractArray{Float64},
    v_V     :: AbstractArray{Float64},
    w_W     :: AbstractArray{Float64},
    amo     :: AdvancedMatrixOperators,
    Kh      :: Float64,
    Kv      :: Float64,
    Δt      :: Float64,
)

    # x direction
    calFluxDensity_abstract!(;
        Xflx_bnd            = Xflx_U,
        
        X_T                 = X,
        u_bnd               = u_U,
        K                   = Kh,
        Δt                  = Δt,
        Δx_bnd              = amo.gd.Δx_U,

        
        bnd_∂x_T         = amo.U_∂x_T,
        T_∂x_bnd         = amo.T_∂x_U,
        bnd_pos_dir_T    = amo.bmo.U_E_T,
        bnd_neg_dir_T    = amo.bmo.U_W_T,
        bnd_interp_T     = amo.U_interp_T,
        bnd_mask_bnd     = amo.U_mask_U,
    )

    calFluxDensity_abstract!(;
        Xflx_bnd            = Xflx_V,
        
        X_T                 = X,
        u_bnd               = v_V,
        K                   = Kh,
        Δt                  = Δt,
        Δx_bnd              = amo.gd.Δy_V,

        
        bnd_∂x_T         = amo.V_∂y_T,
        T_∂x_bnd         = amo.T_∂y_V,
        bnd_pos_dir_T    = amo.bmo.V_N_T,
        bnd_neg_dir_T    = amo.bmo.V_S_T,
        bnd_interp_T     = amo.V_interp_T,
        bnd_mask_bnd     = amo.V_mask_V,
    )

    calFluxDensity_abstract!(;
        Xflx_bnd            = Xflx_W,
        
        X_T                 = X,
        u_bnd               = w_W,
        K                   = Kv,
        Δt                  = Δt,
        Δx_bnd              = amo.gd.Δz_W,

        
        bnd_∂x_T         = amo.W_∂z_T,
        T_∂x_bnd         = amo.T_∂z_W,
        bnd_pos_dir_T    = amo.bmo.W_UP_T,
        bnd_neg_dir_T    = amo.bmo.W_DN_T,
        bnd_interp_T     = amo.W_interp_T,
        bnd_mask_bnd   = amo.W_mask_W,
    )


end

function calFluxDensity_abstract!(;
    
    Xflx_bnd              :: AbstractArray{Float64},

    X_T                       :: AbstractArray{Float64},
    u_bnd                     :: AbstractArray{Float64},
    K                         :: Float64,
    Δt                        :: Float64,
    Δx_bnd                    :: AbstractArray{Float64},

    bnd_∂x_T                  :: AbstractArray{Float64, 2},
    T_∂x_bnd                  :: AbstractArray{Float64, 2},
    bnd_pos_dir_T             :: AbstractArray{Float64, 2},
    bnd_neg_dir_T             :: AbstractArray{Float64, 2},
    bnd_interp_T              :: AbstractArray{Float64, 2},
    bnd_mask_bnd            :: AbstractArray{Float64, 2},

)

    _X_T    = view(X_T, :)
    _u_bnd  = view(u_bnd, :)
    _Δx_bnd = view(Δx_bnd, :)

    GRAD_bnd = bnd_∂x_T * _X_T
    CURV_T   = T_∂x_bnd * GRAD_bnd

    CURV_on_pos_dir_bnd = bnd_neg_dir_T * CURV_T
    CURV_on_neg_dir_bnd = bnd_pos_dir_T * CURV_T
    
    pos_u_mask_bnd = _u_bnd .>= 0

    CURV_r_bnd = CURV_on_neg_dir_bnd .* pos_u_mask_bnd + CURV_on_pos_dir_bnd .* (1 .- pos_u_mask_bnd)

    uΔt_bnd    = u_bnd * Δt
    X_star_bnd = bnd_interp_T * _X_T

    X_star_bnd = bnd_interp_T * _X_T - uΔt_bnd / 2.0 .* GRAD_bnd + ( K * Δt / 2.0 .- (_Δx_bnd.^2.0)/6.0 + (uΔt_bnd.^2.0) / 6.0 ) .* CURV_r_bnd

    Xflx_bnd[:] = bnd_mask_bnd * ( u_bnd .* X_star_bnd - K * ( GRAD_bnd - uΔt_bnd / 2.0 .* CURV_r_bnd ) )

end
