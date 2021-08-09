include("../julia/ProgramTunnel_fs_new.jl")

using .ProgramTunnel_fs
using Formatting
using JSON

PTI = ProgramTunnelInfo(reverse_role=true, rotate=30)


sarrs = [ collect(Float64, 1:5),  collect(Float64, 101:105) / 2.0 ]
rarrs = [ collect(Float64, 1:5),  collect(Float64, 1:5)           ]

for t=1:100
    msg = format("[SSM] This is the {:d} time", t)
    println("MSG: ", msg)

    for i = 1:2
        for k = 1:5
            sarrs[i][k] = t*100 + i*10 + k
        end
        rarrs[i] .= 0.0
    end

    sendData(PTI, msg, sarrs)
    msg = recvData!(PTI, rarrs)


    println("Received msg:", msg)
    println("Recved arrs: ")
    print(json(rarrs, 4))
end
