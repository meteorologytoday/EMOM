include("MLMML.jl")

include("../lib/Newton.jl")
using ForwardDiff
using .MLMML
using PyPlot

PERIOD = 86400.0 * 360.0
J0 = 100.0 * MLMML.α * MLMML.g / MLMML.ρ / MLMML.c_p
J_func(t) = J0 / 90.0 / 86400.0 * t 
E_func(t) = - J_func(t) * t/2.0
#J_func(t) = J0 
#E_func(t) = - J_func(t) * t


ω  = 2π / PERIOD
h0 = 50.0
s  = 30.0 / 5000.0 * MLMML.α * MLMML.g
k  = MLMML.getTKE(fric_u=MLMML.getFricU(ua=0.0))
n  = 0.2 
Δb0 = 10.0 * MLMML.α * MLMML.g *0
#sol = t -> (m * h0)^(-1.0) * (√(k^2.0 + (2.0*m*h0^2.0*(-J0)*n)/ω * (1.0 - cos(ω*t))) - k)
ts = collect(Float64, range(0.0, stop=90.0*86400.0, length=1000))
#ana_h = h0 .+ sol.(ts)


using DifferentialEquations
f(h, p, t) = h * n * J_func(t) / ( s * (h^2.0 - h0^2.0) / 2.0 + k + Δb0 * h0 + E_func(t))
prob = ODEProblem(f, h0, (ts[1], ts[end]))
num_h = solve(prob, Tsit5(), reltol=1e-8, abstol=1e-8)
num_dhdt = [f(num_h.u[i], 0 , num_h.t[i]) for i = 1:length(num_h.u)]

# dh/dt
#ana_dhdt = - ana_h * J0 .* sin.(ω*ts) * n ./ (m/2.0 * (ana_h.^2.0 .- h0^2.0) .+ k)
#num_dhdt = (ana_h[2:end] - ana_h[1:end-1]) / (ts[2] - ts[1])
#ana_dhdt = [f(h, 0, ts[i]) for i = 1:length(ts)]

fig, ax = plt[:subplots](2, 1, sharex=true)
ax[1][:set_title]("solution for MLD")
ax[1][:plot](num_h.t/86400.0, - (num_h.u ), "--", label="numerical")
ax[1][:legend]()

#ax[2][:plot](ts/86400.0, ana_dhdt, label="analytical")
#ax[2][:plot]((ts[2:end] + ts[1:end-1])/2.0/86400.0, num_dhdt, "--", label="numerical")
ax[2][:set_title]("dh/dt")
ax[2][:plot](num_h.t/86400.0, num_dhdt, "--", label="numerical")
ax[2][:legend]()
plt[:show]()
