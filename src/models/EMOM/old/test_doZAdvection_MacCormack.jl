include("NKOM.jl")
using .NKOM

zs = - collect(Float64, range(0.0, stop=1000.0, length=101))

mid_zs = (zs[1:end-1] + zs[2:end]) / 2.0

Δhs = zs[1:end-1] - zs[2:end]
Δzs = (Δhs[1:end-1] + Δhs[2:end]) / 2.0

qs = zeros(Float64, length(zs)-1)


for k = 1:length(qs)
    qs[k] = exp(- ((mid_zs[k] + 500.0) / 100.0)^2.0 )
end


for k = 1:length(qs)

    if mid_zs[k] > -50.0
        qs[k] = 1.0
    elseif qs[k] > -500.0
        qs[k] = 1.0 - (-50 - mid_zs[k]) * 0.0001
    else
        qs[k] = qs[k-1]
    end

end

#qs .= 1


ws = copy(zs) * 0.0 .+ 1e-4
ws[1] = 0.0

Δt = 1e4 # 3600.0 * 3


Nz = length(qs)

qstmp  = copy(qs)
flxtmp = copy(qs)


steps = 5 

qs_rec = zeros(Float64, length(qs), steps + 1)
qs_rec[:, 1] = qs

for t = 1:steps

    NKOM.doZAdvection_MacCormack!(
        Nz = Nz,
        qs = qs,
        ws = ws,
        Δzs = Δzs,
        Δt = Δt,
        qstmp = qstmp,
        flxtmp=flxtmp,
    )

    qs_rec[:, t+1] = qs
    println(t, ": ", sum(qs .* Δhs))
end


using PyCall

plt = pyimport("matplotlib.pyplot")

fig, ax = plt.subplots(1, 1)

for t = 1:1:steps+1

    c = ["r", "g", "b", "k", "gray", "purple"][mod(t-1, 5)+1]
    for k = 1:Nz

        ax.plot([ qs_rec[k, t], qs_rec[k,   t]], [zs[k], zs[k+1]] , color=c)

        if k < Nz
            ax.plot([ qs_rec[k, t], qs_rec[k+1, t]], [zs[k+1], zs[k+1]] , color=c)
        end

    end


end

plt.show()
