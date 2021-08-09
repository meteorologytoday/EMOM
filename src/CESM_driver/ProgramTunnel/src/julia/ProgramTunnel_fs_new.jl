
include("TBIO.jl")

module ProgramTunnel_fs

    using Formatting
    using ..TBIO

    export ProgramTunnelInfo, sendData, recvData!

    mutable struct Timing
        chk_freq             :: Float64
        timeout              :: Float64
        buffer               :: Float64
        recv_first_sleep     :: Float64
        recv_first_sleep_max :: Float64

        timeout_limit_cnt    :: Integer
        buffer_cnt           :: Integer
        recv_first_cnt       :: Integer




        function Timing(;
            chk_freq             :: Float64,
            timeout              :: Float64,
            buffer               :: Float64,
            recv_first_sleep_max :: Float64,
            recv_first_sleep     :: Float64,
        )

            T = new(
                chk_freq,
                timeout,
                buffer,
                recv_first_sleep,
                recv_first_sleep_max,
                0,
                0,
                0,
            )
    
            updateCount!(T)

            return T
        end

    end

    function updateCount!(T::Timing)
        T.timeout_limit_cnt = ceil(T.timeout          / T.chk_freq)
        T.buffer_cnt        = ceil(T.buffer           / T.chk_freq)
        T.recv_first_cnt    = ceil(T.recv_first_sleep / T.chk_freq)
    end

    mutable struct ProgramTunnelInfo

        nchars       :: Integer
        
        recv_fn      :: AbstractString
        send_fn      :: AbstractString

        recv_channels :: AbstractArray{Timing}

        rotate       :: Integer
        recv_trackno :: Integer
        send_trackno :: Integer

        path         :: AbstractString
        error_sleep  :: Float64

        history_len  :: Integer

        recv_fns     :: AbstractArray
        send_fns     :: AbstractArray


        function ProgramTunnelInfo(;
            path                 :: Union{AbstractString, Nothing} = "x_tmp",
            nchars               :: Integer            = 512,
            recv_fn              :: AbstractString     = "Y2X",
            send_fn              :: AbstractString     = "X2Y",
            recv_channels        :: Integer            = 1,
            chk_freq             :: AbstractFloat      = 0.05,
            timeout              :: AbstractFloat      = 60.0 * 30,
            buffer               :: AbstractFloat      = 0.1,
            recv_first_sleep_max :: AbstractFloat      = 5.00,
            recv_first_sleep     :: AbstractFloat      = 0.0,
            reverse_role         :: Bool               = false,
            rotate               :: Integer            = 100,
            error_sleep          :: Float64            = 0.05,
            history_len          :: Integer            = 5,
        )

            if chk_freq <= 0.0
                ErrorException("chk_freq must be positive.") |> throw
            end
            
            recv_channels = [
                Timing(
                    chk_freq             = chk_freq,
                    timeout              = timeout,
                    buffer               = buffer,
                    recv_first_sleep_max = recv_first_sleep_max,
                    recv_first_sleep     = recv_first_sleep,
                )
                for i = 1:recv_channels
            ]


            PTI = new(
                nchars,
                recv_fn,
                send_fn,
                recv_channels,
                rotate, 1, 1,
                path,
                1.0, history_len,
                [], [],
            )

            if reverse_role
                reverseRole!(PTI)
            end
            
            mkpath(path)
            updateFiles!(PTI)        


            return PTI
        end
    end

    function updateFiles!(PTI::ProgramTunnelInfo)
        recv_fns = []
        send_fns = []
        for i = 1:PTI.rotate
            push!(recv_fns, joinpath(PTI.path, format("{:s}_{:03d}.tb", PTI.recv_fn, i)))
            push!(send_fns, joinpath(PTI.path, format("{:s}_{:03d}.tb", PTI.send_fn, i)))
        end

        PTI.recv_fns = recv_fns
        PTI.send_fns = send_fns
    end

    function cleanHistory(PTI::ProgramTunnelInfo)
        cleanDir(PTI, ((PTI.send_trackno-1 - PTI.history_length -1) % PTI.rotate) + 1)
    end


    function reverseRole!(PTI::ProgramTunnelInfo)
        PTI.recv_fn, PTI.send_fn = PTI.send_fn, PTI.recv_fn
    end

    function incTrackno(PTI::ProgramTunnelInfo, which::Symbol)
        if which == :recv
            rm( PTI.recv_fns[mod( PTI.recv_trackno - 1 - PTI.history_len, PTI.rotate) + 1], force=true)
            PTI.recv_trackno += 1

        elseif which == :send
            rm( PTI.send_fns[mod( PTI.send_trackno - 1 - PTI.history_len, PTI.rotate) + 1], force=true)
            PTI.send_trackno += 1

        end
    end

    function sendData(
        PTI  :: ProgramTunnelInfo,
        msg  :: AbstractString,
        arrs :: AbstractArray,
    )

        send_fn = PTI.send_fns[mod(PTI.send_trackno - 1, PTI.rotate) + 1]

        while true
            try
            
                writeTB(
                    send_fn,
                    format("{:d}#{:s}", PTI.send_trackno, msg),
                    PTI.nchars,
                    arrs,
                )
            catch ex
                throw(ex)
                println(string(ex))
                println("keep sending msg.")
                sleep(PTI.error_sleep)
            end
            break
        end

        incTrackno(PTI, :send)

    end


    function recvData!(
        PTI     :: ProgramTunnelInfo,
        arrs    :: AbstractArray;
        which   :: Integer = 1,
    )

        channel = PTI.recv_channels[which]

        recv_fn = PTI.recv_fns[mod(PTI.recv_trackno - 1, PTI.rotate) + 1]

        println(format("[recvData!] [{:d}] Expecting file: {:s}. First sleep: {:.2f} ", which, recv_fn, channel.recv_first_sleep))
        get_through = false
        sleep(channel.recv_first_sleep)
        if isfile(recv_fn)
            channel.recv_first_sleep -= channel.chk_freq
            channel.recv_first_sleep = max(0.0, channel.recv_first_sleep)

            get_through = true
            println(format("[recvData!] [{:d}] Message is already there. Adjust recv_first_sleep to : {:.2f}", which, channel.recv_first_sleep))
        else
            for cnt in 1:(channel.timeout_limit_cnt - channel.recv_first_cnt)

                sleep(channel.chk_freq)

                if isfile(recv_fn)
                    get_through = true

                    if cnt <= channel.buffer_cnt

                        println(format("[recvData!] [{:d}] Good guess of the recv_first_sleep : {:.2f}", which, channel.recv_first_sleep))

                    elseif channel.recv_first_sleep < channel.recv_first_sleep_max

                        # Out of buffer, need to adjust: increase PTI.recv_first_sleep
                        channel.recv_first_sleep += channel.chk_freq 
                        channel.recv_first_sleep = min(channel.recv_first_sleep_max, channel.recv_first_sleep)
                        println(format("[recvData!] [{:d}] Out of buffer. recv_first_sleep to : {:.2f} ", which, channel.recv_first_sleep))

                    else
                        println(format("[recvData!] [{:d}] Out of buffer. But reach to recv_first_sleep_max : {:.2f}", which, channel.recv_first_sleep))
                    end
                        
                    break

                end

            end
        end
            
        updateCount!(channel)

        if ! get_through
            ErrorException(format("[recvData!] [{:d}] No further incoming message within timeout.", which)) |> throw
        end

        local msg

        while true
            try
                msg = readTB!(
                    recv_fn,
                    PTI.nchars,
                    arrs,
                )

                if msg == nothing

                    println("File does not exist / not the expected size / checksum failed. Keep receiving...")
                    sleep(PTI.error_sleep)
                    continue

                end

                recv_no, msg = split(msg, "#")
                if parse(Int, recv_no) != PTI.recv_trackno
                    println(format("Recive file trackno does not match. Expect {:d} but got {:s}. Keep receiving...", PTI.recv_trackno, recv_no))
                    sleep(PTI.error_sleep)
                    continue
                end

            catch ex
                println(string(ex))
                println("Keep receiving...")
                sleep(PTI.error_sleep)
                continue
            end


            break
        end

        incTrackno(PTI, :recv)
        
        return msg 
    end


end
