using PyPlot
using NCDatasets
using Formatting
plt = PyPlot

schemes = ["AGA2020", "KSC2018", "CO2012"]

d = Dict()

for scheme in schemes
    global d, ϵ

    ds = Dataset("epsilon_logpost_$(scheme).nc", "r")

    ϵ    = nomissing(ds["epsilon"][:], NaN)
    post = nomissing(ds["post"][:], NaN)

    d[scheme] = post
end


ϵ_vec = collect(Float64, range(0.0, 2.0, length=11)) # day^-1
#day_vec = collect(Float64, range(0.6, 2.0, length=7))
#day_on_ϵ_vec = 1 ./ (day_vec * 86400.0)

fig, ax = plt.subplots(1, 1, figsize=(6,4))

for scheme in schemes
    ax.plot(ϵ*86400.0, d[scheme], label=scheme)
end

ax.legend()

ax.set_xticks(ϵ_vec)
#ax.set_xticks(day_on_ϵ_vec)
#ax.set_xticklabels([ format("{:.2f}", day) for day in day_vec])

#ax.invert_xaxis()

plt.show()
