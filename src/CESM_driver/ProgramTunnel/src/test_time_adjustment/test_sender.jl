include("../julia/ProgramTunnel_fs.jl")

using .ProgramTunnel_fs
using Formatting

PTI = ProgramTunnelInfo()
reverseRole!(PTI)

t_mean = 2.0
t_std  = 0.2

for i=1:100
    global t_mean

    t = t_mean + rand()*t_std
    msg = format("[{:3d}] This time: {:03f}.", i, t)

    println(msg)
    sleep(t)

    sendText(PTI, msg)

    t_mean += 0.02
    if i == 30
        t_mean *= 0.7
    end
     
end

