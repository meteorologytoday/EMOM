include(joinpath(@__DIR__, "..", "share", "LogSystem.jl"))
include(joinpath(@__DIR__, "..", "dyn_core", "ENGINE_EMOM.jl"))
include(joinpath(@__DIR__, "..", "driver", "driver_working.jl"))
include(joinpath(@__DIR__, "ProgramTunnel", "src", "julia", "BinaryIO.jl"))
include(joinpath(@__DIR__, "ProgramTunnel", "src", "julia", "ProgramTunnel_fs_new.jl"))

using MPI
using CFTime, Dates
using ArgParse
using JSON
using TOML

using .ProgramTunnel_fs
using .BinaryIO
using .LogSystem

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin
        "--config-file"
            help = "Configuration file in TOML format."
            arg_type = String
            required = true
    end

    return parse_args(s)
end

function parseCESMTIME(
        t_str    :: AbstractString,
        timetype :: DataType,
)

    yyyy = parse(Int64, t_str[1:4])
    mm   = parse(Int64, t_str[5:6])
    dd   = parse(Int64, t_str[7:8])
    HH   = parse(Int64, t_str[10:11])
    MM   = parse(Int64, t_str[13:14])
    SS   = parse(Int64, t_str[16:17])

    return timetype(yyyy,mm,dd,HH,MM,SS)

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




MPI.Init()
comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)
is_master = rank == 0

msg = nothing
config = nothing
if is_master

    config = TOML.parsefile(parsed["config-file"])

    timetype = getproperty(CFTime, Symbol(config["MODEL_MISC"]["timetype"])) 

    PTI = ProgramTunnelInfo(
        path = joinpath(config["DRIVER"]["caserun"], "x_tmp"),
        reverse_role  = true,
        recv_channels = 2,
        chk_freq = 0.2,
    )
    nullbin  = [zeros(Float64, 1)]

    function recvMsg(;verbose::Bool = true)
        global msg = parseMsg( recvData!(PTI, nullbin, which=1) )
        if verbose
            writeLog("Receive message: ")
            JSON.print(msg, 4)
        end
    end

end

coupler_funcs = (

    master_before_model_init = function()

        global msg
        
        writeLog("[Coupler] Before model init. My rank = {:d}", rank)
        
        recvMsg()
       
        if msg["MSG"] != "INIT"
            throw(ErrorException("Unexpected `MSG` : " * string(msg["MSG"])))
        end
 
        read_restart = (msg["READ_RESTART"] == "TRUE") ? true : false
        cesm_coupler_time = parseCESMTIME(msg["CESMTIME"], timetype)
        Δt = Dates.Second(parse(Float64, msg["DT"]))

        return read_restart, cesm_coupler_time, Δt
        
    end,

    master_after_model_init! = function(OMMODULE, OMDATA)

        global msg

        writeLog("[Coupler] After model init. My rank = {:d}", rank)

        global lsize = parse(Int64, msg["LSIZE"])

        global send_data_list = [OMDATA.o2x["SST"], OMDATA.o2x["Q_FRZMLTPOT"], OMDATA.o2x["USFC"], OMDATA.o2x["VSFC"]]
        global recv_data_list = []

        global x2o_available_varnames = split(msg["VAR2D"], ",")
        global x2o_wanted_varnames = keys(OMDATA.x2o)
        global x2o_wanted_flag     = [(x2o_available_varnames[i] in x2o_wanted_varnames) for i = 1:length(x2o_available_varnames)]


        writeLog("# Check if all the requested variables are provided by cesm end...")
        local pass = true
        for varname in x2o_wanted_varnames
            if ! ( varname in x2o_available_varnames )
                writeLog("Error: $(varname) is requested by ocean model but not provided on cesm side.")
                pass = false
            end 
        end

        if pass
            writeLog("All variables requested are provided.")
        else
            throw(ErrorException("Some variable are not provided. Please check."))
        end

        writeLog("# List of provided x2o variables:")
        for (i, varname) in enumerate(x2o_available_varnames)
            push!(recv_data_list , ( x2o_wanted_flag[i] ) ? OMDATA.x2o[varname] :  zeros(Float64, lsize))
            println(format(" ({:d}) {:s} => {:s}", i, varname, ( x2o_wanted_flag[i] ) ? "Wanted" : "Dropped" ))
        end


        sendData(PTI, "OK", send_data_list)
        sendData(PTI, "mask",  [OMDATA.o2x["mask"],])

    end,

    master_before_model_run! = function(OMMODULE, OMDATA)
        #writeLog("[Coupler] Before model run")
        #writeLog("[Coupler] This is where flux exchange happens.")
        recvMsg() 

        return_values = nothing
        if msg["MSG"] == "RUN"
            Δt = Dates.Second(parse(Float64, msg["DT"]))
            recvData!(
                PTI,
                recv_data_list,
                which=2,
            )
            
            cesm_coupler_time = parseCESMTIME(msg["CESMTIME"], timetype)
            if OMDATA.clock.time != cesm_coupler_time
                writeLog("Warning: time inconsistent. `cesm_coupler_time` is $(string(cesm_coupler_time)), but ocean model's time is $(string(OMDATA.clock.time)). This can happen if this is a startup run or hybrid run. Because my implementation cannot tell, I have to just forward the model time. Please be extra cautious about this.")
           
                error_t = Second(cesm_coupler_time - OMDATA.clock.time)
                if error_t.value < 0
                    throw(ErrorException("Error: ocean model time is ahead of `cesm_coupler_time`. This is absolutely an error."))
                end
                advanceClock!(OMDATA.clock, error_t)
                
            end
 
            write_restart = msg["WRITE_RESTART"] == "TRUE"

            return_values = ( :RUN,  Δt, write_restart )

        elseif msg["MSG"] == "END"
            return_values = ( :END, 0.0, false  )
        else
            throw(ErrorException("Unexpected `MSG` : " * string(msg["MSG"])))
        end

        return return_values

    end,

    master_after_model_run! = function(OMMODULE, OMDATA)
        #writeLog("[Coupler] After model run")
        global send_data_list = [OMDATA.o2x["SST"], OMDATA.o2x["Q_FRZMLTPOT"], OMDATA.o2x["USFC"], OMDATA.o2x["VSFC"]]
        sendData(PTI, "OK", send_data_list)
    end,

    master_finalize! = function(OMMODULE, OMDATA)
        writeLog("[Coupler] Finalize")
        writeLog("Sleep for 30 seconds before archiving to avoid conflicting with CESM archiving process.")
        sleep(30.0)
    end 
)



runModel(
    ENGINE_EMOM, 
    coupler_funcs,
    config, 
)
