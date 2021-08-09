
module ProgramTunnel_fs
using Formatting

export ProgramTunnelInfo, hello, recvText, sendText, reverseRole!

mutable struct ProgramTunnelInfo

    recv_fn      :: AbstractString
    send_fn      :: AbstractString
    done_recv_fn :: AbstractString
    done_send_fn :: AbstractString

    chk_freq     :: AbstractFloat
    timeout    :: AbstractFloat
    timeout_limit_cnt :: Integer
    buffer_cnt :: Integer

    recv_first_sleep_max :: AbstractFloat
    recv_first_sleep :: AbstractFloat
    recv_first_cnt   :: Integer

    rotate       :: Integer
    recv_trackno :: Integer
    send_trackno :: Integer

    paths        :: AbstractArray
    error_sleep  :: Float64

    history_length :: Integer


    function ProgramTunnelInfo(;
        recv          :: AbstractString     = "ProgramTunnel-Y2X.txt",
        send          :: AbstractString     = "ProgramTunnel-X2Y.txt",
        done_recv     :: AbstractString     = "ProgramTunnel-DONE-Y2X.txt",
        done_send     :: AbstractString     = "ProgramTunnel-DONE-X2Y.txt",
        chk_freq      :: AbstractFloat                  = 0.05,
        path          :: Union{AbstractString, Nothing} = nothing,
        timeout       :: AbstractFloat                  = 10.0,
        buffer        :: AbstractFloat                  = 0.1,
        recv_first_sleep_max :: AbstractFloat = 5.00,
        recv_first_sleep :: AbstractFloat = 0.0,
        reverseRole   :: Bool = false,
        rotate        :: Integer = 100,
        history_length:: Integer = 20,
    )

        if chk_freq <= 0.0
            ErrorException("chk_freq must be positive.") |> throw
        end
        

        paths = []
        for i = 1:rotate
            push!(paths, joinpath(MPI.path, format("{:03d}")))
        end

        PTI = new(
            recv,
            send,
            lock,
            chk_freq,
            timeout,
            ceil(timeout / chk_freq),
            ceil(buffer / chk_freq),
            recv_first_sleep_max,
            recv_first_sleep,
            ceil(recv_first_sleep / chk_freq),
            rotate, 1, 1, paths, 1.0, history_length,
        )

        if path != nothing
            appendPath(PTI, path)
        end

        if reverseRole
            reverseRole!(PTI)
        end

        makeDirs(PTI)

        return PTI
    end
end

function makeDirs(PTI::ProgramTunnelInfo)
    for path in PTI.paths
        makepath(path)
    end
end

function cleanDir(PTI::ProgramTunnelInfo, i::Integer)
    rm(PTI.paths[i], recursive=true, force=true)
    makepath(PTI.paths[i])
end

function cleanHistory(PTI::ProgramTunelInfo)
    cleanDir(PTI, ((PTI.send_trackno-1 - PTI.history_length -1) % PTI.rotate) + 1)
end


function appendPath(PTI::ProgramTunnelInfo, path::AbstractString)
    for i = 1:PTI.rotate
        PTI.paths[i] = joinpath(path, PTI.paths[i])
    end
end

function reverseRole!(PTI::ProgramTunnelInfo)
    PTI.recv_fn, PTI.send_fn = PTI.send_fn, PTI.recv_fn
    PTI.done_recv_fn, PTI.done_send_fn = PTI.done_send_fn, PTI.done_recv_fn
end


function sendText(PTI::ProgramTunnelInfo, msg::AbstractString)
#    local double_chk_msg

    if strip(msg) == ""
        throw(ErrorException("Cannot send empty msg."))
    end

    while true
        try
            open(joinpath(PTI.paths[PTI.send_trackno], PTI.send_fn), "w") do io
                write(io, msg)
            end
        catch ex
            println(string(ex))
            println("keep sending msg.")
            sleep(PTI.error_sleep)
        end
        break
    end

    while true
        try
            open(joinpath(PTI.paths[PTI.send_trackno], PTI.done_send_fn), "w") do io
                write(io, "DONE")
            end
        catch ex
            println(string(ex))
            println("keep sending done.")
            sleep(PTI.error_sleep)
        end
        break
    end
    
    PTI.send_trackno = (PTI.send_trackno % PTI.rotate) + 1

end

function recvText(PTI::ProgramTunnelInfo)

    recv_fn = joinpath(PTI.paths[PTI.recv_trackno], PTI.recv_fn)
    done_recv_fn = joinpath(PTI.paths[PTI.recv_trackno], PTI.done_recv_fn)

    get_through = false
    sleep(PTI.recv_first_sleep)

    if ! (isfile(recv_fn) && isfile(done_recv_fn))
        PTI.recv_first_sleep -= PTI.chk_freq
        PTI.recv_first_sleep = max(0.0, PTI.recv_first_sleep)
        get_through = true

        println("[recvText] Message is already there. Adjust recv_first_sleep to : ", PTI.recv_first_sleep)
    else
        for cnt in 1:(PTI.timeout_limit_cnt - PTI.recv_first_cnt)

            sleep(PTI.chk_freq)

            if isfile(recv_fn) && isfile(done_recv_fn)
                get_through = true

                if cnt <= PTI.buffer_cnt

                    println("[recvText] Good guess of the recv_first_sleep : ", PTI.recv_first_sleep)

                elseif PTI.recv_first_sleep < PTI.recv_first_sleep_max

                    # Out of buffer, need to adjust: increase PTI.recv_first_sleep
                    PTI.recv_first_sleep += PTI.chk_freq 
                    PTI.recv_first_sleep = min(PTI.recv_first_sleep_max, PTI.chk_freq)
                    println("[recvText] Out of buffer. Adjust recv_first_sleep to : ", PTI.recv_first_sleep)

                else
                    println("[recvText] Out of buffer. But reach to recv_first_sleep_max : ", PTI.recv_first_sleep)
                end
                    
                break

            end

        end
    end

    if ! get_through
        ErrorException("[recvText] No further incoming message within timeout.") |> throw
    end

    result = ""

    while true

        try
            open(PTI.recv_fn, "r") do io
                result = strip(read(io, String))
            end
        catch ex
            println(string(ex))
            println("Keep receiving...")
            sleep(PTI.error_sleep)
            continue
        end

        if result == ""
            println("Empty msg received. Maybe due to IO delay. Sleep and do it again.")
            sleep(PTI.error_sleep)
            continue
        end

        break
    end



    PTI.recv_trackno = (PTI.recv_trackno % PTI.rotate) + 1
    
    cleanHistory(PTI)
    
    return result
end



end
