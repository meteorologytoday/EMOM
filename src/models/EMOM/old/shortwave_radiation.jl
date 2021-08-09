function OC_doShortwaveRadiation!(
    ocn    :: Ocean,
    i      :: Integer,
    j      :: Integer;
    Tswflx :: Float64,
    Δt     :: Float64,
)
    ocn.T_ML[i, j] = doShortwaveRadiation!(
        Tswflx = Tswflx,
        Ts   = ocn.cols.Ts[i, j],
        zs   = ocn.cols.zs[i, j],
        hs   = ocn.cols.hs[i, j],
        rad_decay_coes  = ocn.cols.rad_decay_coes[i, j],
        rad_absorp_coes = ocn.cols.rad_absorp_coes[i, j],
        T_ML = ocn.T_ML[i, j],
        h_ML = ocn.h_ML[i, j],
        Nz   = ocn.Nz[i, j],
        FLDO = ocn.FLDO[i, j],
        ζ    = ocn.ζ,
        Δt   = Δt,
    )



end


function doShortwaveRadiation!(;
    Tswflx          :: Float64,
    Ts              :: AbstractArray{Float64, 1}, 
    zs              :: AbstractArray{Float64, 1}, 
    hs              :: AbstractArray{Float64, 1}, 
    rad_decay_coes  :: AbstractArray{Float64, 1}, 
    rad_absorp_coes :: AbstractArray{Float64, 1}, 
    T_ML            :: Float64,
    h_ML            :: Float64,
    Nz              :: Integer,
    FLDO            :: Integer,
    ζ               :: Float64,
    Δt              :: Float64,
)

    
    # ===== [BEGIN] Mixed layer =====

    if FLDO == -1      # Entire ocean column is mixed-layer
        T_ML += - Tswflx * Δt / h_ML
        Ts[1:Nz] .= T_ML
        return T_ML
    end


    rad_decay_coes_ML = exp(-h_ML/ζ)
    T_ML += - Tswflx * (1.0 - rad_decay_coes_ML) * Δt / h_ML
    
    if FLDO > 1        
        Ts[1:FLDO-1] .= T_ML
    elseif FLDO == -1
        Ts[1:Nz] .= T_ML
    end

    # ===== [END] Mixed layer =====

    # ===== [BEGIN] FLDO layer =====

    h_FLDO = - h_ML - zs[FLDO+1]

    if FLDO == Nz  # FLDO is last layer
        Ts[FLDO] += - Tswflx * rad_decay_coes_ML * Δt / h_FLDO
        return T_ML
    else
        Ts[FLDO] += - Tswflx * (rad_decay_coes_ML - rad_decay_coes[FLDO+1]) * Δt / h_FLDO
    end
    # ===== [END] FLDO layer =====

    # ===== [BEGIN] Rest layers =====

    for k=FLDO+1:Nz
        Ts[k] += - Tswflx * rad_decay_coes[k] * rad_absorp_coes[k] * Δt / hs[k]
    end

    # ===== [END] Rest layers =====
        
    return T_ML
end

