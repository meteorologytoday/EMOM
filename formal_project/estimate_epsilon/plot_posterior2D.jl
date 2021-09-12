using PyPlot
using NCDatasets
using Formatting
plt = PyPlot

schemes = ["AGA2020", ]#"KSC2018", "CO2012"]

d = Dict()

println("Loading data...")
for scheme in schemes
    global d, ϵ, ϵp

    filename = "epsilon_logpost2D_$(scheme).nc"
    println("Load file $(filename)")
    ds = Dataset(filename, "r")

    ϵ   = nomissing(ds["epsilon"][:], NaN) * 86400
    ϵp   = nomissing(ds["epsilon_prime"][:], NaN) * 86400
    post_w = transpose(nomissing(ds["post_w"][:], NaN))
    post_u = transpose(nomissing(ds["post_u"][:], NaN))
    post_uw = transpose(nomissing(ds["post_uw"][:], NaN))

    d[scheme] = Dict(
        :post_w => post_w,
        :post_u => post_u,
        :post_uw => post_uw,
    )
end


ϵ_vec  = collect(Float64, range(0.0, 2.0, length=11)) # day^-1
ϵp_vec = collect(Float64, range(0.0, 5.0, length=11)) # day^-1
#day_vec = collect(Float64, range(0.6, 2.0, length=7))
#day_on_ϵ_vec = 1 ./ (day_vec * 86400.0)

println("Plotting")
fig, ax = plt.subplots(1, 3, figsize=(8, 6), constrained_layout=true)

for _ax in ax
    _ax.plot([-10, 10], [-10, 10], "k--")
end

for scheme in schemes
    data = d[scheme]
    ax[1].contour(ϵ, ϵp, data[:post_w])
    ax[2].contour(ϵ, ϵp, data[:post_u])
    ax[3].contour(ϵ, ϵp, data[:post_uw])


end
    
ax[1].set_title("\$ w \$")
ax[2].set_title("\$\\vec{v}\$")
ax[3].set_title("\$w\$ and \$\\vec{v}\$")

for _ax in ax
    _ax.set_xticks(ϵ_vec)
    _ax.set_yticks(ϵp_vec)
    _ax.set_xlabel("\$ \\epsilon \$")
    _ax.set_ylabel("\$ \\epsilon' \$")

    _ax.set_xlim([0, 2])
    _ax.set_ylim([0, 2])
    _ax.set_aspect(1.0)
end
#ax.set_xticks(day_on_ϵ_vec)
#ax.set_xticklabels([ format("{:.2f}", day) for day in day_vec])

#ax.invert_xaxis()

plt.show()
