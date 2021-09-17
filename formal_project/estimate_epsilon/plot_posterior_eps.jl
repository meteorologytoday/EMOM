using PyPlot
using NCDatasets
using Formatting
plt = PyPlot

schemes = ["CO2012", ]#"KSC2018", "CO2012"]

d = Dict()

println("Loading data...")
for scheme in schemes
    global d, ϵx, ϵy

    filename = "eps_logpost_$(scheme).nc"
    println("Load file $(filename)")
    ds = Dataset(filename, "r")

    ϵx   = nomissing(ds["eps_x"][:], NaN) * 86400
    post_w = transpose(nomissing(ds["post_w"][:], NaN))
    post_u = transpose(nomissing(ds["post_u"][:], NaN))
    post_uw = transpose(nomissing(ds["post_uw"][:], NaN))

    d[scheme] = Dict(
        :post_w => post_w,
        :post_u => post_u,
        :post_uw => post_uw,
    )
end

ϵx_vec  = collect(Float64, range(0, 2, length=11)) # day^-1
#day_vec = collect(Float64, range(0.6, 2.0, length=7))
#day_on_ϵx_vec = 1 ./ (day_vec * 86400.0)

println("Plotting")
fig, ax = plt.subplots(1, 3, figsize=(8, 6), constrained_layout=true)

for _ax in ax
    _ax.plot([-10, 10], [-10, 10], "k--")
end

for scheme in schemes
    data = d[scheme]
    ax[1].plot(ϵx, data[:post_w])
    ax[2].plot(ϵx, data[:post_u])
    ax[3].plot(ϵx, data[:post_uw])
end
    
ax[1].set_title("\$ w \$")
ax[2].set_title("\$\\vec{v}\$")
ax[3].set_title("\$w\$ and \$\\vec{v}\$")

for _ax in ax
    _ax.set_xlabel("\$ \\epsilon \$")
    _ax.set_ylabel("\$ P_\\epsilon\$")
    _ax.set_xticks(ϵx_vec)
    _ax.set_xlim([0, 2])
end
#ax.set_xticks(day_on_ϵ_vec)
#ax.set_xticklabels([ format("{:.2f}", day) for day in day_vec])

#ax.invert_xaxis()

plt.show()
