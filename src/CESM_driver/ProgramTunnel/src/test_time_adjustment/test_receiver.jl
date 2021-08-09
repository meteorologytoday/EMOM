include("../julia/ProgramTunnel_fs.jl")

using .ProgramTunnel_fs
using Formatting

PTI = ProgramTunnelInfo(recv_first_sleep=2.0)

println(PTI)

for i=1:100
    println(format("[{:3d}]", i))
    msg = recvText(PTI)
end

