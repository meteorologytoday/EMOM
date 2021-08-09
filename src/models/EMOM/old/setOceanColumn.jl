
"""

  This function only sets the value in mixed layer without
  conserving quantity 

"""
 function setMixedLayer!(;
    Ts   :: AbstractArray{Float64, 1},
    Ss   :: AbstractArray{Float64, 1},
    zs   :: AbstractArray{Float64, 1},
    Nz   :: Integer,
    T_ML :: Float64,
    S_ML :: Float64,
    h_ML :: Float64,
)
    FLDO = getFLDO(zs=zs, h_ML=h_ML, Nz=Nz)

    if FLDO > 1
        Ts[1:FLDO-1] .= T_ML
        Ss[1:FLDO-1] .= S_ML
    elseif FLDO == -1
        Ts[1:Nz] .= T_ML
        Ss[1:Nz] .= S_ML
    end
   
    return FLDO 
end


function OC_setMixedLayer!(
    ocn  :: Ocean,
    i    :: Integer,
    j    :: Integer;
    T_ML :: Float64,
    S_ML :: Float64,
    h_ML :: Float64,
)

    ocn.h_ML[i, j] = h_ML
    ocn.T_ML[i, j] = T_ML
    ocn.S_ML[i, j] = S_ML
    ocn.FLDO[i, j] = setMixedLayer!(
        Ts   = ocn.cols.Ts[i, j],
        Ss   = ocn.cols.Ss[i, j],
        zs   = ocn.cols.zs[i, j],
        Nz   = ocn.Nz[i, j],
        T_ML = T_ML,
        S_ML = S_ML,
        h_ML = h_ML,
    )

end


function OC_setBuoyancy!(
    ocn  :: Ocean,
    i    :: Integer,
    j    :: Integer;
    bs   :: AbstractArray{Float64,1},
    b_ML :: Float64,
    h_ML :: Float64,
)

    ocn.bs[i, j, :] = bs
    OC_setMixedLayer!(ocn, i, j; b_ML=b_ML, h_ML=h_ML)

end


#=
function makeBlankOceanColumn(;zs::Array{Float64, 1})
    N     = length(zs) - 1
    bs    = zeros(Float64, N)
    K     = 0.0
    b_ML  = 0.0
    h_ML  = h_ML_min
    FLDO  = 1

    oc = OceanColumn(N=N, zs=zs, bs=bs, K=K, b_ML=b_ML, h_ML=h_ML, FLDO=FLDO)
    OC_updateFLDO!(oc)

    return oc
end


function makeSimpleOceanColumn(;
    zs      :: AbstractArray{Float64, 1},
    b_slope :: Float64 = 30.0 / 5000.0 * g * α,
    b_ML    :: Float64 = 1.0,
    h_ML    :: Float64 = h_ML_min,
    Δb      :: Float64 = 0.0,
    K       :: Float64 = 1e-5
)

    oc = makeBlankOceanColumn(zs=zs)

    bs = zeros(Float64, length(zs)-1)
    for i = 1:length(bs)
        z = (zs[i] + zs[i+1]) / 2.0
        if z > -h_ML
            bs[i] = b_ML
        else
            bs[i] = b_ML - Δb - b_slope * (-z - h_ML)
        end
    end

    OC_setBuoyancy!(oc, bs=bs, b_ML=b_ML, h_ML=h_ML)
    oc.K = K
    OC_updateFLDO!(oc)

    return oc

end
=#
