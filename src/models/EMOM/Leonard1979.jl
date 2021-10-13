function calDiffAdv_QUICKEST!(
    Xflx_U  :: AbstractArray{Float64},
    Xflx_V  :: AbstractArray{Float64},
    Xflx_W  :: AbstractArray{Float64},

    X       :: AbstractArray{Float64},
    u_U     :: AbstractArray{Float64},
    v_V     :: AbstractArray{Float64},
    w_W     :: AbstractArray{Float64},
    amo     :: AdvancedMatrixOperators,
    Kh_U    :: AbstractArray{Float64},
    Kh_V    :: AbstractArray{Float64},
    Kv      :: Float64,
    Δt      :: Float64,
    wksp    :: Workspace,
)

    # x direction
    calFluxDensity_abstract!(;
        Xflx_bnd            = Xflx_U,
        
        X_T                 = X,
        u_bnd               = u_U,
        K_bnd               = Kh_U,
        Δt                  = Δt,
        Δx_bnd              = amo.gd.Δx_U,

        
        bnd_∂x_T         = amo.U_∂x_T,
        T_∂x_bnd         = amo.T_∂x_U,
        bnd_pos_dir_T    = amo.bmo.U_E_T,
        bnd_neg_dir_T    = amo.bmo.U_W_T,
        bnd_interp_T     = amo.U_interp_T,
        bnd_mask_bnd     = amo.U_mask_U,

        grid_bnd = :U,
        wksp = wksp,
    )

    calFluxDensity_abstract!(;
        Xflx_bnd            = Xflx_V,
        
        X_T                 = X,
        u_bnd               = v_V,
        K_bnd               = Kh_V,
        Δt                  = Δt,
        Δx_bnd              = amo.gd.Δy_V,

        
        bnd_∂x_T         = amo.V_∂y_T,
        T_∂x_bnd         = amo.T_∂y_V,
        bnd_pos_dir_T    = amo.bmo.V_N_T,
        bnd_neg_dir_T    = amo.bmo.V_S_T,
        bnd_interp_T     = amo.V_interp_T,
        bnd_mask_bnd     = amo.V_mask_V,

        grid_bnd = :V,
        wksp = wksp,
    )

    calFluxDensity_abstract!(;
        Xflx_bnd            = Xflx_W,
        
        X_T                 = X,
        u_bnd               = w_W,
        K_bnd               = Kv,
        Δt                  = Δt,
        Δx_bnd              = amo.gd.Δz_W,

        
        bnd_∂x_T         = amo.W_∂z_T,
        T_∂x_bnd         = amo.T_∂z_W,
        bnd_pos_dir_T    = amo.bmo.W_UP_T,
        bnd_neg_dir_T    = amo.bmo.W_DN_T,
        bnd_interp_T     = amo.W_interp_T,
        bnd_mask_bnd   = amo.W_mask_W,

        grid_bnd = :W,
        wksp = wksp,
    )


end

function calFluxDensity_abstract!(;
    
    Xflx_bnd              :: AbstractArray{Float64},

    X_T                       :: AbstractArray{Float64},
    u_bnd                     :: AbstractArray{Float64},
    K_bnd                     :: Union{Float64, Array{Float64}},
    Δt                        :: Float64,
    Δx_bnd                    :: AbstractArray{Float64},

    bnd_∂x_T                  :: AbstractArray{Float64, 2},
    T_∂x_bnd                  :: AbstractArray{Float64, 2},
    bnd_pos_dir_T             :: AbstractArray{Float64, 2},
    bnd_neg_dir_T             :: AbstractArray{Float64, 2},
    bnd_interp_T              :: AbstractArray{Float64, 2},
    bnd_mask_bnd              :: AbstractArray{Float64, 2},

    grid_bnd :: Symbol,
    wksp     :: Workspace,
)

    # I keep the original memory intensive code for reference.
    # The original code does not utilize Workspace. When running
    # with 4 cores, 35 vertical layers, gx1v6 grid and 8 substeps,
    # it takes about 12.5 secs while new code using Workspace 
    # takes about 7 secs. This is a huge improvement.

    #=
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

    =#
    _X_T    = view(X_T, :)
    _u_bnd  = view(u_bnd, :)
    _Δx_bnd = view(Δx_bnd, :)
    _Xflx_bnd = view(Xflx_bnd, :)

    GRAD_bnd            = getSpace!(wksp, grid_bnd, true) 
    CURV_T              = getSpace!(wksp, :T, true)
    CURV_on_pos_dir_bnd = getSpace!(wksp, grid_bnd, true)
    CURV_on_neg_dir_bnd = getSpace!(wksp, grid_bnd, true)
    pos_u_mask_bnd      = getSpace!(wksp, grid_bnd, true)
    CURV_r_bnd          = getSpace!(wksp, grid_bnd, true)
    uΔt_bnd             = getSpace!(wksp, grid_bnd, true)
    X_star_bnd          = getSpace!(wksp, grid_bnd, true)
    tmp_bnd             = getSpace!(wksp, grid_bnd, true)

    mul!(GRAD_bnd, bnd_∂x_T, _X_T)
    mul!(CURV_T,   T_∂x_bnd, GRAD_bnd)

    mul!(CURV_on_pos_dir_bnd, bnd_neg_dir_T, CURV_T)
    mul!(CURV_on_neg_dir_bnd, bnd_pos_dir_T, CURV_T)
    
    @. pos_u_mask_bnd = _u_bnd >= 0

    @. CURV_r_bnd = CURV_on_neg_dir_bnd * pos_u_mask_bnd + CURV_on_pos_dir_bnd * (1 - pos_u_mask_bnd)

    @. uΔt_bnd = u_bnd * Δt

    mul!(X_star_bnd, bnd_interp_T, _X_T)
    @. X_star_bnd += - uΔt_bnd / 2.0 * GRAD_bnd + ( K_bnd * Δt / 2.0 - (_Δx_bnd^2.0)/6.0 + (uΔt_bnd^2.0) / 6.0 ) * CURV_r_bnd

    @. tmp_bnd = u_bnd .* X_star_bnd - K_bnd * ( GRAD_bnd - uΔt_bnd / 2.0 .* CURV_r_bnd )
    mul!(_Xflx_bnd, bnd_mask_bnd, tmp_bnd)
end
