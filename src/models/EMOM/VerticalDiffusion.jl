

mutable struct VerticalDiffusion
    
    amo :: AdvancedMatrixOperators

    eT_length    :: Int64
   
    eT_send_T    :: AbstractArray{Float64, 2}
    T_send_eT    :: AbstractArray{Float64, 2}
    eT_I_eT      :: AbstractArray{Float64, 2}

    K_iso :: Float64
    K_cva :: Float64

    K_func :: Function

    wksp

    function VerticalDiffusion(
        amo   :: AdvancedMatrixOperators;
        K_iso :: Float64,
        K_cva :: Float64,
    )

        cvtDiagOp = (a,) -> spdiagm(0 => view(a, :))
        Nz, Ny, Nx = amo.bmo.T_dim
         
        # Create coversion matrix and its inverse
        T_num        = reshape(amo.T_mask_T * collect(1:amo.bmo.T_pts), Nz, Ny, Nx)
        active_T_num = T_num[ T_num .!= 0.0 ]
        eT_send_T    = amo.bmo.T_I_T[active_T_num, :]
        T_send_eT    = eT_send_T' |> sparse
        eT_I_eT      = eT_send_T * T_send_eT

        eT_length = size(eT_I_eT)[1]

        #K = spdiagm(0 => ones(Float64, amo.bmo.W_pts))
       
        K_func = (dbdz,) -> (dbdz > 0.0) ? K_iso : K_cva

        # iEBD = inverse of Euler Backward Diffusion ( I - Δt * ∇K∇ ) 
        wksp = (
            above_W    = zeros(Float64, amo.bmo.W_pts),
            below_W    = zeros(Float64, amo.bmo.W_pts),
            Δ_W        = zeros(Float64, amo.bmo.W_pts),
            K_W        = zeros(Float64, amo.bmo.W_pts),
            W_K_W      = spdiagm(0 => ones(Float64, amo.bmo.W_pts)),
            W_K∇_T     = spzeros(Float64, amo.bmo.W_pts, amo.bmo.T_pts),
            T_∇K∇_T    = spzeros(Float64, amo.bmo.T_pts, amo.bmo.T_pts),
            eT_∇K∇_T   = spzeros(Float64, eT_length, amo.bmo.T_pts),
            eT_∇K∇_eT  = spzeros(Float64, eT_length, eT_length),
            eT_iEBD_eT = spzeros(Float64, eT_length, eT_length),
            rhs_eT     = zeros(Float64, eT_length),
            lhs_eT     = zeros(Float64, eT_length),
        )


        return new(
            amo,
            eT_length,
            eT_send_T,
            T_send_eT,
            eT_I_eT,
            K_iso,
            K_cva,
            K_func,
            wksp,
        )

    end
end

function calOp_vdiff(
    vd   :: VerticalDiffusion,
    b    :: AbstractArray, # of grid :T
    HMXL :: AbstractArray, # of grid :sT
    TEMP :: AbstractArray, # of grid :T
)

    amo = vd.amo
    bmo = amo.bmo
    gd  = amo.gd

    dbdz = vd.amo.W_∂z_T * view(b, :)
    HMXL = reshape(HMXL, 1, gd.Nx, gd.Ny)

    K_W = reshape( vd.K_func.(dbdz), bmo.W_dim...)
    K_W[gd.z_W .> - HMXL] .= vd.K_cva 

    # below this W-pts the temperature is below freezing point.
    # reasoning please see stepColumn discussing about Q_FRZHEAT / frzmlt
    below_frz_below = (bmo.W_UP_T * view(TEMP, :)) .< T_sw_frz
    K_W[below_frz_below] .= vd.K_cva

    op_vdiff = sparse(vd.amo.T_DIVz_W * vd.amo.W_mask_W * spdiagm( 0 => view(K_W,:)) * vd.amo.W_∂z_T)

    dropzeros!(op_vdiff)

    return op_vdiff
end

