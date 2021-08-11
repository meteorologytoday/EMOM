include("IOM/src/share/LogSystem.jl")
include("IOM/src/share/PolelikeCoordinate.jl")
include("IOM/src/models/EMOM/ENGINE_EMOM.jl")
include("IOM/src/driver/driver.jl")

include("ProgramTunnel/src/julia/ProgramTunnel_fs_new.jl")

using MPI
using CFTime, Dates
using ArgParse

using .ProgramTunnel_fs
using .PolelikeCoordinate
using .BinaryIO
using .LogSystem

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin
        "--config-file"
            help = "Configuration file."
            arg_type = String
            required = true
    end

    return parse_args(s)
end

function parseCESMTIME(t_str::AbstractString)

    yyyy = parse(Int, t_str[1:4])
    mm   = parse(Int, t_str[5:6])
    dd   = parse(Int, t_str[7:8])
    HH   = parse(Int, t_str[10:11])
    MM   = parse(Int, t_str[13:14])
    SS   = parse(Int, t_str[16:17])

    return DateTimeNoLeap(yyyy,mm,dd,HH,MM,SS)

end

function parseMsg(msg::AbstractString)
    pairs = split(msg, ";")
    d = Dict{AbstractString, Any}()
    for i = 1:length(pairs)

        if strip(pairs[i]) == ""
            continue
        end

        key, val = split(pairs[i], ":")
        key = String(key)
        val = String(val)
        d[key] = val
    end
    return d
end

parsed = parse_commandline()


include(parsed["config-file"])

MPI.Init()
comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)
is_master = rank == 0

PTI = ProgramTunnelInfo(
    reverse_role  = true,
    recv_channels = 2,
)
nullbin  = [zeros(Float64, 1)]

function recvMsg()
    global msg = parseMsg( recvData!(PTI, nullbin, which=1) )
end

coupler_funcs = (

    master_before_model_init = function()
        
        recvMsg()
       
        if msg["MSG"] != "INIT"
            throw(ErrorException("Unexpected `MSG` : " * string(msg["MSG"])))
        end
 
        read_restart = (msg["READ_RESTART"] == "TRUE") ? true : false
        coupler_time = parseCESMTIME(msg["CESMTIME"])

        
        return read_restart, coupler_time
        
    end

    master_after_model_init! = function(OMMODULE, OMDATA)

        writeLog("[Coupler] After model init")

        global lsize = parse(Int64, msg["lsize"])

        global send_data_list = Array{Float64}[OMDATA.o2x["SST"], OMDATA.o2x["QFLX2ATM"]]
        global recv_data_list = Array{Float64}[]

        global x2o_available_varnames = split(msg["VAR2D"], ",")
        global x2o_wanted_varnames = keys(OMDATA.x2o)
        global x2o_wanted_flag     = [(x2o_available_varnames[i] in x2o_wanted_varnames) for i = 1:length(x2o_available_varnames)]


        println("List of available x2o variables:")
        for (i, varname) in enumerate(x2o_available_varnames)
            push!(recv_data_list , ( x2o_wanted_flag[i] ) ? OMDATA.x2o[varname] :  zeros(Float64, lsize))
            println(format(" ({:d}) {:s} => {:s}", i, varname, ( x2o_wanted_flag[i] ) ? "Wanted" : "Dropped" ))
        end

        sendData(PTI, "OK", send_data_list)

    end,

    master_before_model_run! = function(OMMODULE, OMDATA)
        #writeLog("[Coupler] Before model run")
        #writeLog("[Coupler] This is where flux exchange happens.")
        recvMsg() 

        if ! ( msg["MSG"] in [ "RUN", "END" ] ) 
            throw(ErrorException("Unexpected `MSG` : " * string(msg["MSG"])))
        end
 
        recvData!(
            PTI,
            recv_data_list,
            which=2,
        )
       
        return_values = nothing
        if msg["MSG"] == "RUN"
            Δt = parse(Float64, msg["DT"])
            return_values = ( :RUN,  Δt, false )
        else
            return_values = ( :END, 0.0, true  )
        end


        return return_values

    end,

    master_after_model_run! = function(OMMODULE, OMDATA)
        #writeLog("[Coupler] After model run")
        sendData(PTI, "OK", send_data_list)
    end,

    master_finalize! = function(OMMODULE, OMDATA)
        writeLog("[Coupler] Finalize")
    end 
)



runModel(
    ENGINE_EMOM, 
    coupler_funcs,
    t_start,
    t_simulation,
    parsed["read-restart"],
    config, 
)
