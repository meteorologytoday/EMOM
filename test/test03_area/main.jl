using NCDatasets
using Formatting

EMOM_root = joinpath(@__DIR__, "..", "..")

include(joinpath(EMOM_root, "src", "share", "PolelikeCoordinate.jl"))
include(joinpath(EMOM_root, "src", "share", "constants.jl"))

using .PolelikeCoordinate


domain_file = joinpath(EMOM_root, "data", "CESM_domains", "domain.ocn.gx1v6.090206.nc")
pop2_tarea_file = joinpath(EMOM_root, "data", "POP2_ref", "POP2_coord.nc")



Dataset(pop2_tarea_file, "r") do ds
    global area_pop2 = ds["TAREA"][:] / 1e4    # POP2 comes in cm^2

    global area_sum_pop2 = sum(area_pop2)

    area_pop2 /= area_sum_pop2
end



gf = PolelikeCoordinate.CurvilinearSphericalGridFile(
    domain_file;
    R  = Re,
    Ω  = Ω,
)
        
gd = PolelikeCoordinate.genGrid(gf, [0.0, -1.0])

area_gf = gf.area / sum(gf.area)

area_emom = (gd.Δx_T .* gd.Δy_T)[1, :, :]
area_sum_emom = sum(area_emom)
area_emom ./= area_sum_emom

err_emom = (area_emom - area_gf) ./ area_gf
err_pop2 = (area_pop2 - area_gf) ./ area_gf

if all(err_pop2 .== err_emom)
    throw(ErrorException("Error of POP2 and EMOM are exactly the same. This is weird."))
end

println("Loading PyPlot")
using PyPlot
println("Done")

err_rng = collect(range(-10, 10, length=41))
err_ticks = collect(range(-10, 10, length=11))

fig, ax = plt.subplots(1, 2, constrained_layout=true, figsize=(10, 4))

fig.suptitle(format("Sum of EMOM: {:.3e} \$\\mathrm{{m}}^2\$, POP2: {:.3e} \$\\mathrm{{m}}^2\$", area_sum_emom, area_sum_pop2))

mappable = ax[1].contourf(transpose(err_emom) * 1000, err_rng, cmap="bwr", extend="both")
cb = plt.colorbar(mappable, ax=ax[1], label="Difference ratio [\$ \\times 10^{-3} \$]", ticks=err_ticks)
ax[1].set_title("Area difference of EMOM")

mappable = ax[2].contourf(transpose(err_pop2) * 1000, err_rng, cmap="bwr", extend="both")
cb = plt.colorbar(mappable, ax=ax[2], label="Difference ratio [\$ \\times 10^{-3} \$]", ticks=err_ticks)
ax[2].set_title("Area difference of POP2")

plt.savefig("area_diff_ratio.png", dpi=70)

plt.show()


