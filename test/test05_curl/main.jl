include("IOM/src/share/constants.jl")
include("IOM/src/share/PolelikeCoordinate.jl")
include("IOM/src/share/BasicMatrixOperators.jl")
include("IOM/src/share/AdvancedMatrixOperators.jl")

using .PolelikeCoordinate
using NCDatasets
using ArgParse, JSON

output_file = "output.nc"

# Load domain and construct operators
domain_file = "CESM_domains/domain.ocn.gx1v6.090206.nc"
gf = PolelikeCoordinate.CurvilinearSphericalGridFile(
    domain_file;
    R  = Re,
    Ω  = Ω,
)

mask_sT = reshape(gf.mask, 1, size(gf.mask)...)
gd_slab = PolelikeCoordinate.genGrid(gf, [0, -50.0]) 

println("Constructing operators...")
@time amo_slab = AdvancedMatrixOperators(;
    gd     = gd_slab,
    mask_T     = mask_sT,
    deepmask_T = mask_sT,
)

u0 = 1.0
v0 = 1.0
a = 2.0
b = 3.0

ϕ_sT = gd_slab.ϕ_T
λ_sT = gd_slab.λ_T
u_east_sT  = u0 * cos.(ϕ_sT) .* sin.(a * λ_sT)
v_north_sT = v0 * cos.(ϕ_sT).^2 .* cos.(b * λ_sT)


ζ_ana_sT = 1 / gd_slab.R * ( 2 * u0 * sin.(ϕ_sT) .* sin.(a * λ_sT) - v0 * b * cos.(ϕ_sT) .* sin.(b * λ_sT) )

u_sT, v_sT = PolelikeCoordinate.project(
    gd_slab, 
    u_east_sT,
    v_north_sT,
    direction=:Forward,
    grid=:T,
)

ζ_num_sT = reshape(
    amo_slab.T_CURLx_T * view(v_sT, :) + amo_slab.T_CURLy_T * view(u_sT, :),
    gd_slab.Nx, gd_slab.Ny,
)

ζ_ana_sT = reshape(
    amo_slab.T_bordermask_T * view(ζ_ana_sT, :),
    gd_slab.Nx, gd_slab.Ny,
)

ζ_dif_sT = ζ_num_sT - ζ_ana_sT
ζ_dif_sT[gf.mask .== 0.0] .= NaN

Dataset(output_file, "c") do ds
    
    defDim(ds, "Nx", gd_slab.Nx)
    defDim(ds, "Ny", gd_slab.Ny)
    for (varname, vardata, vardim, attrib) in [
        ("zeta_num", ζ_num_sT, ("Nx", "Ny",), Dict()),
        ("zeta_ana", ζ_ana_sT, ("Nx", "Ny",), Dict()),
        ("zeta_dif", ζ_dif_sT, ("Nx", "Ny",), Dict()),
 
    ]

        var = defVar(ds, varname, Float64, vardim)
        var.attrib["_FillValue"] = 1e20
        
        for (k, v) in attrib
            var.attrib[k] = v
        end

        rng = []
        for i in 1:length(vardim)-1
            push!(rng, Colon())
        end
        push!(rng, 1:size(vardata)[end])
        var[rng...] = vardata

    end

end
