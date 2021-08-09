function allocate(datakind::Symbol, dtype::DataType, dims...)
    if datakind == :local
        return zeros(dtype, dims...)
    elseif datakind == :shared
        return SharedArray{dtype}(dims...)
    else
        ErrorException("Unknown kind: " * string(datakind)) |> throw
    end
end

#=
"""
This function checks if CFL criteria is satisfied which is required by Euler Forward Scheme. Explicitly,

 K Δt       1
------  <= ---
(Δz)^2      2

for every layer. This function returns true every layer is satisfied, returns false if any of the layers is not.

"""
function checkAllDiffusionStability(;
    Δzs:: AbstractArray{Float64, 1},
    K  :: Float64,
    Δt :: Float64,
)

    return all( Δzs .>= √(2.0 * K * Δt) )
end

function checkDiffusionStability(;
    Δz :: Float64,
    K  :: Float64,
    Δt :: Float64,
)

    return Δz >= √(2.0 * K * Δt)
end

function checkDiffusionStability(oc::OceanColumn; Δt)
    return checkAllDiffusionStability(Δzs=oc.Δzs, K=oc.K, Δt=Δt)
end


function minΔz(;
    K :: Float64,
    Δt:: Float64,
)
    return √(2.0 * K * Δt)
end

=#

function boundMLD(h_ML::Float64; h_ML_min::Float64, h_ML_max::Float64)
    return max(min(h_ML, h_ML_max), h_ML_min)
end


"""
    getTKE(fric_u)

# Description
This function returns the TKE (turbulent kinetic energy) `k = 0.5 * (v'^2)` of ML. This parameterization is given by Kim 1976: "A Generalized Bulk Model of the Oceanic Mixed Layer" in its equation (11)

"""
function getTKE(;
    fric_u :: Float64
)
    cm = max(3e-2, 3.0 * fric_u)
    return  0.5 * cm^2.0
end


function updateFLDO!(
        ocn :: Ocean,
    )

    @loop_hor ocn i j let
        OC_updateFLDO!(ocn, i, j)
    end
end


function OC_updateFLDO!(
        ocn :: Ocean,
        i   :: Integer,
        j   :: Integer,
    )
    ocn.FLDO[i, j] = getFLDO(zs=ocn.cols.zs[i, j], h_ML=ocn.h_ML[i, j], Nz=ocn.Nz[i, j])
end

"""

    Returns the FLDO. If mixed-layer depth is equal to the total depth
    of ocean column, -1 will be returned.

"""
function getFLDO(;
    zs   :: AbstractArray{Float64,1},
    h_ML :: Float64,
    Nz   :: Integer,
)
    for i = 1:Nz
        if h_ML < - zs[i+1]  # I don't use equality in order to avoid Δb = 0 during some initialization
            return i
        end
    end

    return -1
end

function getLayerFromDepth(;
    zs   :: AbstractArray{Float64,1},
    z    :: Float64,
    Nz   :: Integer,
)
    for i = 1:Nz
        if zs[i+1] < z  # I don't use equality in order to avoid Δb = 0 during some initialization
            return i
        end
    end

    return -1
end

function getWindStress(;
    u10::Float64
)

    return u10 * 1e-3 * ( (u10 < 25.0) 
                    ? 2.7 + 0.142 * u10 + 0.0764 * u10^2.0
                    : u10 * (2.16 + 0.5406 * (1.0 - exp(- (u10 - 25.0) / 7.5)))
    )

end

function getFricU(;
    ua::Float64
)
    return √(getWindStress(u10=ua) / ρ)
end

function OC_updateB!(
    ocn :: Ocean,
    i   :: Integer,
    j   :: Integer,
)

    ocn.b_ML[i, j] = TS2b(ocn.T_ML[i, j], ocn.S_ML[i, j])
    for k=1:ocn.Nz[i, j]
        ocn.bs[k, i, j] = TS2b(ocn.Ts[k, i, j], ocn.Ss[k, i, j])
    end

end

function updateB!(ocn::Ocean)

    @loop_hor ocn i j let
        OC_updateB!(ocn, i, j)
    end

end


