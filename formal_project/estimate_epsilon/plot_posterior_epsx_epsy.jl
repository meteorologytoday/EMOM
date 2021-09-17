using PyPlot
using NCDatasets
using Formatting
plt = PyPlot

schemes = ["CO2012", ]#"KSC2018", "CO2012"]

d = Dict()

println("Loading data...")
for scheme in schemes
    global d, ϵx, ϵy

    filename = "epsx_epsy_logpost_$(scheme).nc"
    println("Load file $(filename)")
    ds = Dataset(filename, "r")

    ϵx   = nomissing(ds["eps_x"][:], NaN) * 86400
    ϵy   = nomissing(ds["eps_y"][:], NaN) * 86400
    post_w = transpose(nomissing(ds["post_w"][:], NaN))
    post_u = transpose(nomissing(ds["post_u"][:], NaN))
    post_uw = transpose(nomissing(ds["post_uw"][:], NaN))

    d[scheme] = Dict(
        :post_w => post_w,
        :post_u => post_u,
        :post_uw => post_uw,
    )
end

ϵx_vec  = collect(Float64, range(0, 1, length=11)) # day^-1
ϵy_vec =  collect(Float64, range(0, 5, length=11)) # day^-1
#day_vec = collect(Float64, range(0.6, 2.0, length=7))
#day_on_ϵx_vec = 1 ./ (day_vec * 86400.0)

println("Plotting")
fig, ax = plt.subplots(1, 3, figsize=(8, 6), constrained_layout=true)

for _ax in ax
    _ax.plot([-10, 10], [-10, 10], "k--")
end

for scheme in schemes
    data = d[scheme]
    map1 = ax[1].contourf(ϵx, ϵy, data[:post_w])
    map2 = ax[2].contourf(ϵx, ϵy, data[:post_u])
    map3 = ax[3].contourf(ϵx, ϵy, data[:post_uw])

    plt.colorbar(ax=ax[1], mappable=map1)
end
    
ax[1].set_title("\$ w \$")
ax[2].set_title("\$\\vec{v}\$")
ax[3].set_title("\$w\$ and \$\\vec{v}\$")

for _ax in ax
#    _ax.set_xticks(ϵx_vec)
#    _ax.set_yticks(ϵy_vec)
    _ax.set_xlabel("\$ \\epsilon_x \$")
    _ax.set_ylabel("\$ \\epsilon_y \$")

    _ax.set_xlim([ϵx[1], ϵx[end]])
    _ax.set_ylim([ϵy[1], ϵy[end]])
#    _ax.set_xlim([0, 1])
#    _ax.set_ylim([0, 5])
#    _ax.set_aspect(1.0)
end
#ax.set_xticks(day_on_ϵ_vec)
#ax.set_xticklabels([ format("{:.2f}", day) for day in day_vec])

#ax.invert_xaxis()

plt.show()
