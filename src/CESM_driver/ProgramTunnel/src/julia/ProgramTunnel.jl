include("./BinaryIO.jl")

module ProgramTunnel

using Formatting
using ..BinaryIO

export recvText, sendText, recvBinary!, sendBinary!,
       mkTunnel, defaultTunnelSet, getTunnelFilename!, reverseRole!

mutable struct Tunnel
    fns      :: AbstractArray{AbstractString}
    next_ptr :: Integer

    function Tunnel(name::AbstractString)
        fns = Array{AbstractString}(undef, 2)
        for i in 1:length(fns)
            fns[i] = format("_{}_{:d}.fifo", name, i)
        end
        return new(fns, 1)
    end
end

mutable struct TunnelSet
    
    tnls :: Dict{Symbol, Tunnel}
    
    function TunnelSet(;
        recv_txt :: AbstractString,
        send_txt :: AbstractString,
        recv_bin :: AbstractString,
        send_bin :: AbstractString,
        path :: AbstractString = ".",
    )

        tnls = Dict{Symbol, Tunnel}(
            :recv_txt => Tunnel(recv_txt),
            :send_txt => Tunnel(send_txt),
            :recv_bin => Tunnel(recv_bin),
            :send_bin => Tunnel(send_bin),
        )
       
        for (k, tnl) in tnls
            for i in 1:length(tnl.fns)
                tnl.fns[i] = normpath(joinpath(path, tnl.fns[i]))
            end

        end
 
        return new(tnls)
    end

end


function getTunnelFilename!(tnl::Tunnel)
    next_ptr = tnl.next_ptr
    tnl.next_ptr = mod(next_ptr, length(tnl.fns)) + 1
    return tnl.fns[next_ptr]
end

function getTunnelFilename!(ts::TunnelSet, key::Symbol)
    return getTunnelFilename!(ts.tnls[key])
end


function defaultTunnelSet(;path::AbstractString=".")
    return TunnelSet(
        send_txt = "X2Y_txt",
        recv_txt = "Y2X_txt",
        send_bin = "X2Y_bin",
        recv_bin = "Y2X_bin",
        path = path,
    )
end

function mkTunnel(TS::TunnelSet)
    
    for (k, tnl) in TS.tnls
        for fn in tnl.fns
            if !isfifo(fn)
                println(fn, " is not a fifo or does not exist. Remove it and create a new one.")
                rm(fn, force=true)
                run(`mkfifo $fn`)
            end
        end
    end
end


function reverseRole!(TS::TunnelSet)
    TS.tnls[:send_txt], TS.tnls[:recv_txt] = TS.tnls[:recv_txt], TS.tnls[:send_txt]
    TS.tnls[:send_bin], TS.tnls[:recv_bin] = TS.tnls[:recv_bin], TS.tnls[:send_bin]
end

function recvText(TS::TunnelSet)
    local result

    open(getTunnelFilename!(TS, :recv_txt), "r") do io
        result = strip(read(io, String))
    end

    return result
end

function sendText(TS::TunnelSet, msg::AbstractString)

    open(getTunnelFilename!(TS, :send_txt), "w") do io
        write(io, msg)
    end
end

function recvBinary!(
    TS        :: TunnelSet,
    #msg       :: AbstractString,
    arr       :: AbstractArray{Float64},
    buffer    :: AbstractArray{UInt8};
    endianess :: Symbol=:little_endian,
)
    #recv_msg = recvText(TS)
    #println("[", recv_msg, "]")
    #if recv_msg != msg
    #    throw(ErrorException("Expect message ", msg, ", but get ", recv_msg))
    #end

    BinaryIO.readBinary!(
        getTunnelFilename!(TS, :recv_bin),
        arr,
        buffer;
        endianess=endianess
    )
end

function sendBinary!(
    TS        :: TunnelSet,
    #msg       :: AbstractString, 
    arr       :: AbstractArray{Float64},
    buffer    :: AbstractArray{UInt8};
    endianess :: Symbol=:little_endian,
)

    #sendText(TS, msg)
    BinaryIO.writeBinary!(
        getTunnelFilename!(TS, :send_bin),
        arr,
        buffer;
        endianess=endianess
    )
end


function hello(TS::TunnelSet)
    sendText(TS, "<<TEST>>")
    recv_msg = recvText(TS) 
    if recv_msg != "<<TEST>>"
        throw(ErrorException("Weird message: " * recv_msg))
    end
end


end
