
module ProgramTunnel_fs
using Formatting

export ProgramTunnelInfo, hello, recvText, sendText, reverseRole!

mutable struct ProgramTunnelInfo

    recv_fn  :: AbstractString
    send_fn  :: AbstractString
    lock_fn  :: AbstractString
    chk_freq :: AbstractFloat
    timeout  :: AbstractFloat
    timeout_limit_cnt :: Integer

    function ProgramTunnelInfo(;
        recv     :: AbstractString     = "ProgramTunnel-Y2X.txt",
        send     :: AbstractString     = "ProgramTunnel-X2Y.txt",
        lock     :: AbstractString     = "ProgramTunnel-lock.txt",
        chk_freq :: AbstractFloat                  = 0.05,
        path     :: Union{AbstractString, Nothing} = nothing,
        timeout  :: AbstractFloat                  = 10.0,
    )

        PTI = new(recv, send, lock, chk_freq, timeout, ceil(timeout / chk_freq))

        if path != nothing
            appendPath(PTI, path)
        end

        return PTI
    end
end

function appendPath(PTI::ProgramTunnelInfo, path::AbstractString)
    PTI.recv_fn = joinpath(path, PTI.recv_fn)
    PTI.send_fn = joinpath(path, PTI.send_fn)
    PTI.lock_fn = joinpath(path, PTI.lock_fn)
end

function reverseRole!(PTI::ProgramTunnelInfo)
    PTI.recv_fn, PTI.send_fn = PTI.send_fn, PTI.recv_fn
end

function lock(
    fn::Function,
    PTI::ProgramTunnelInfo,
)

    if obtainLock(PTI)
        fn()
        releaseLock(PTI)
    else
        ErrorException("Lock cannot be obtained before timeout.") |> throw
    end
end


function obtainLock(PTI::ProgramTunnelInfo)

    for cnt in 1:PTI.timeout_limit_cnt
        if ! isfile(PTI.lock_fn)

            try
                open(PTI.lock_fn, "w") do io
                end
                return true
            catch
                # do nothing
            end

        end

        sleep(PTI.chk_freq)
    end

    return false
end

function releaseLock(PTI::ProgramTunnelInfo)
    rm(PTI.lock_fn, force=true)
end

function recvText(PTI::ProgramTunnelInfo)
    local result

    get_through = false

    for cnt in 1:PTI.timeout_limit_cnt
        if isfile(PTI.recv_fn)
            get_through = true
            break
        end

        sleep(PTI.chk_freq)

    end

    if ! get_through
        ErrorException("No further incoming message within timeout.") |> throw
    end

    lock(PTI) do
        open(PTI.recv_fn, "r") do io
            result = strip(read(io, String))
        end

        rm(PTI.recv_fn, force=true)
        releaseLock(PTI)

    end

    return result
end

function sendText(PTI::ProgramTunnelInfo, msg::AbstractString)

    lock(PTI) do
        open(PTI.send_fn, "w") do io
            write(io, msg)
        end
    end
end


#=
function hello(PTI::ProgramTunnelInfo; max_try::Integer=default_max_try)
    send(PTI, "<<TEST>>", max_try)
    recv_msg = recv(PTI, max_try) 
    if recv_msg != "<<TEST>>"
        throw(ErrorException("Weird message: " * recv_msg))
    end
end
=#

end
