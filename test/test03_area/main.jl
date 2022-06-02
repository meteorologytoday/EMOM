EMOM_root = joinpath(@__DIR__, "..", "..")

include(joinpath(EMOM_root, "src", "share", "PolelikeCoordinate.jl"))
include(joinpath(EMOM_root, "src", "share", "constants.jl"))

using .PolelikeCoordinate

domain_file = joinpath(EMOM_root, "data", "CESM_domains", "domain.ocn.gx3v7.120323.nc")
domain_file = joinpath(EMOM_root, "data", "CESM_domains", "domain.ocn.gx1v6.090206.nc")


gf = PolelikeCoordinate.CurvilinearSphericalGridFile(
    domain_file;
    R  = Re,
    Ω  = Ω,
)
        
gd = PolelikeCoordinate.genGrid(gf, [0.0, -1.0])

area_gf = gf.area / sum(gf.area)

area_gd = (gd.Δx_T .* gd.Δy_T)[1, :, :]
area_gd ./= sum(area_gd)
err = (area_gd - area_gf) ./ area_gf

println("Loading PyPlot")
using PyPlot
println("Done")

mappable = plt.contourf(transpose(err) * 1000, collect(range(-10, 10, length=41)), cmap="bwr", extend="both")
cb = plt.colorbar(mappable, label="Difference ratio [\$ \\times 10^{-3} \$]", ticks = collect(range(-10, 10, length=11)))

plt.savefig("area_diff_ratio.png", dpi=70)

plt.show()


