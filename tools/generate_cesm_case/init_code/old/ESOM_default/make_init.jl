include("load_files.jl")
include(joinpath(src, "ESOM", "ESOM.jl"))
using .ESOM

include("load_files.jl")

Δz_1 =  50.0 
Δz_2 = 250.0

for i = 1:length(zs)
    if 0.0 - zs[i] >= Δz_1
        global bnd_1 = i
        break
    end
end

for i = bnd_1:length(zs)
    if zs[bnd_1]- zs[i] >= Δz_2
        global bnd_2 = i
        break
    end
end

bnds_1 =     1:bnd_1
bnds_2 = bnd_1:bnd_2

layers_1 = bnds_1[1] : bnds_1[2] - 1
layers_2 = bnds_2[1] : bnds_2[2] - 1


zs_1 = zs[bnds_1]
zs_2 = zs[bnds_2]

hs_1 = zs_1[1:end-1] - zs_1[2:end]
hs_2 = zs_2[1:end-1] - zs_2[2:end]

_Ts_clim = zeros(Float64, Nx, Ny, 2)
_Ss_clim = zeros(Float64, Nx, Ny, 2)

_Ts_clim .= NaN
_Ss_clim .= NaN


sum_hs_1 = sum(hs_1)
sum_hs_2 = sum(hs_2)

for i=1:Nx, j=1:Ny

    if mask[i, j] == 0
        continue
    end
    
    _Ts_clim[i, j, 1] = sum(hs_1 .* Ts_clim[i, j, layers_1]) / sum_hs_1
    _Ts_clim[i, j, 2] = sum(hs_2 .* Ts_clim[i, j, layers_2]) / sum_hs_2
 
    _Ss_clim[i, j, 1] = sum(hs_1 .* Ss_clim[i, j, layers_1]) / sum_hs_1
    _Ss_clim[i, j, 2] = sum(hs_2 .* Ss_clim[i, j, layers_2]) / sum_hs_2
   
    # Might touch the bottom of ocean
    if isnan(_Ts_clim[i, j, 1])
        _Ts_clim[i, j, 1] = Ts_clim[i, j, 1]
        _Ts_clim[i, j, 2] = Ts_clim[i, j, 1]
    elseif isnan(Ts_clim[i, j, 2])
        _Ts_clim[i, j, 2] = Ts_clim[i, j, 1]
    end
 
    if isnan(_Ss_clim[i, j, 1])
        _Ss_clim[i, j, 1] = Ss_clim[i, j, 1]
        _Ss_clim[i, j, 2] = Ss_clim[i, j, 1]
    elseif isnan(Ss_clim[i, j, 2])
        _Ss_clim[i, j, 2] = Ss_clim[i, j, 1]
    end
     
end

# Check if weird
for i=1:Nx, j=1:Ny
    if mask[i, j] != 0
        if any(isnan.(_Ts_clim[i, j, :])) || any(isnan.(_Ss_clim[i, j, :]))
            throw(ErrorException("Some data are missing at ", i, ", ", j))
        end
    end
end
occ = ESOM.OceanColumnCollection(
    gridinfo_file = parsed["domain-file"],
    Nx       = Nx,
    Ny       = Ny,
    hs       = [Δz_1, Δz_2],
    Ts       = _Ts_clim,
    Ss       = _Ss_clim,
    Kh_T     = 25000.0,
    Kh_S     = 25000.0,
    fs       = nothing,
    ϵs       = 1e-5,    # 1 day
    mask     = mask,
    topo     = topo,
)

ESOM.takeSnapshot(occ, parsed["output-file"])


