using Formatting

include("NKOM.jl")
using .NKOM

zs = - collect(Float64, range(0.0, stop=1000.0, length=11))
zs = [0.0, -100, -150, -222, -300, -407, -550, -600, -666.0, -700, -750]
zs = [0.0, -10, -20, -30, -40, -50, -60, -70.0]
Nz = 7

qs = zeros(Float64, length(zs)-1)
qs[:] = [277.334, 277.349, 277.349, 277.349, 277.349, 277.346, 277.345]

Δhs = zs[1:end-1] - zs[2:end]

h_ML = 16.072753
old_q_ML = qs[1]


FLDO = NKOM.getFLDO(zs=zs, h_ML=h_ML, Nz=Nz)


if FLDO != -1
    qs[1:FLDO-1] .= old_q_ML
else
    qs .= old_q_ML
end

println("##### 1. SETTING #####")

println("zs: ", zs)
println("Δhs: ", Δhs)
println("h_ML: ", h_ML)
println(format("old_q_ML: {:f}", old_q_ML))
println("Old qs: ", qs)

println("##### 2. MIX #####")
Δq = NKOM.mixFLDO!(
    qs = qs,
    zs = zs,
    hs = Δhs,
    q_ML = old_q_ML,
    h_ML = h_ML,
    FLDO = FLDO,
)

println(format("Δq: {:f}", Δq))
println("After Mix, qs = ", qs)

println("##### 3. UNMIX #####")
new_q_ML = NKOM.unmixFLDOKeepDiff!(;
    qs = qs,
    zs = zs,
    hs = Δhs,
    h_ML = h_ML,
    FLDO = FLDO,
    Nz = Nz,
    Δq = Δq,
)

if FLDO != -1
    Δq = new_q_ML - qs[FLDO]
else
    Δq = 0.0
end


println("New qs: ", qs) 

println(format("new_q_ML: {:f}", new_q_ML))
println(format("new_Δq: {:f}", Δq))
