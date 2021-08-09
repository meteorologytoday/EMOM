function OC_doDeepOcnCorrectionOfT!(
    ocn :: Ocean,
    i   :: Integer,
    j   :: Integer;
    Δt  :: Float64,
    τ   :: Float64 = ocn.Ts_clim_relax_time,
    start_layer :: Integer,
)

    return doDeepOcnCorrection!(
        h_ML    = ocn.h_ML[i, j],
        qs      = ocn.cols.Ts[i, j],
        qs_clim = ocn.cols.Ts_clim[i, j],
        FLDO    = ocn.FLDO[i, j],
        Nz      = ocn.Nz[i, j],
        τ       = τ,
        Δt      = Δt,
        hs      = ocn.cols.hs[i, j],
        zs      = ocn.cols.zs[i, j],
        start_layer = start_layer,
    )

end

function OC_doDeepOcnCorrectionOfS!(
    ocn :: Ocean,
    i   :: Integer,
    j   :: Integer;
    Δt  :: Float64,
    start_layer :: Integer,
)

    return doDeepOcnCorrection!(
        h_ML    = ocn.h_ML[i, j],
        qs      = ocn.cols.Ss[i, j],
        qs_clim = ocn.cols.Ss_clim[i, j],
        FLDO    = ocn.FLDO[i, j],
        Nz      = ocn.Nz[i, j],
        τ       = ocn.Ss_clim_relax_time,
        Δt      = Δt,
        hs      = ocn.cols.hs[i, j],
        zs      = ocn.cols.zs[i, j],
        start_layer = start_layer,
    )

end


"""

    This function newtonian-relaxes `qs` to `qs_clim` with e-folding time `τ`.
    It has to be noted that mixed-layer is not relaxed.

    Also, Euler backward integration scheme is used.

"""
function doDeepOcnCorrection!(;
    h_ML       :: Float64,
    qs         :: AbstractArray{Float64, 1},
    qs_clim    :: AbstractArray{Float64, 1},
    FLDO       :: Integer,
    Nz         :: Integer,
    τ          :: Float64,
    Δt         :: Float64,
    hs         :: AbstractArray{Float64, 1},
    zs         :: AbstractArray{Float64, 1},
    start_layer:: Integer,
)

    src_and_sink = 0.0


    if τ > 0.0

        r = Δt / τ
        if FLDO != -1 && start_layer <= Nz

            for i = max(FLDO, start_layer):Nz
                dq = r * (qs_clim[i] - qs[i]) / (1.0 + r)
                src_and_sink += ((i == FLDO) ? - zs[FLDO+1] - h_ML : hs[i]) * dq
                #qs[i] = (qs[i] + r * qs_clim[i]) / (1+r)
                qs[i] += dq
            end

        end

    elseif τ == 0.0
 
        if FLDO != -1 && start_layer <= Nz
            for i = max(FLDO, start_layer):Nz
                src_and_sink += ((i == FLDO) ? - zs[FLDO+1] - h_ML : hs[i]) * (qs_clim[i] - qs[i])
                qs[i] = qs_clim[i]
            end
        end
   
    end

    return src_and_sink / Δt
end

