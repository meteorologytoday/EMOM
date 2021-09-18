include("IOM/src/share/LogSystem.jl")
include("IOM/src/share/PolelikeCoordinate.jl")
include("IOM/src/models/EMOM/ENGINE_EMOM.jl")
include("IOM/src/driver/driver_working.jl")
include("IOM/src/share/CyclicData.jl")
include("DataLoader.jl")

using MPI
using CFTime, Dates
using ArgParse
using TOML
using DataStructures
using NCDatasets
using .PolelikeCoordinate
using .LogSystem
using .CyclicData
using .DataLoader

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

parsed = parse_commandline()

MPI.Init()
comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)
is_master = rank == 0

config = nothing
if is_master

    config = TOML.parsefile(parsed["config-file"])
    config["DRIVER"]["sync_thermo_state_before_stepping"] = true

    # We will strictly use a day
    Δt_float = 86400.0
    Δt = Dates.Second(Δt_float)
    read_restart = false

    cfgmc = config["MODEL_CORE"]
    cfgmm = config["MODEL_MISC"]

    cfgmc["Qflx"] = "off"
    cfgmc["weak_restoring"] = "off"
    cfgmc["transform_vector_field"] = false
    
    Nz = length(cfgmc["z_w"])-1

    first_run = true


    t_start = DateTimeNoLeap(1, 1, 1, 0, 0, 0)
    t_end   = DateTimeNoLeap(1, 2, 1, 0, 0, 0)


end


global data = nothing
coupler_funcs = (

    master_before_model_init = function()

        return read_restart, t_start
    end,

    master_after_model_init! = function(OMMODULE, OMDATA)
            # setup forcing
        println("# Model beg time: $(string(t_start))")
        println("# Model end time: $(string(t_end))")

    end,

    master_before_model_run! = function(OMMODULE, OMDATA)

        global first_run, data

        if first_run

            first_run = false
        
        end

        OMDATA.x2o["NSWFLX"] .=  -2000.0

        write_restart = OMDATA.clock.time == t_end
        end_phase = OMDATA.clock.time > t_end

        if ! end_phase
            return_values = ( :RUN,  Δt, write_restart )
        else
            return_values = ( :END, 0.0, write_restart  )
        end

        return return_values
    end,

    master_after_model_run! = function(OMMODULE, OMDATA)

        fi = OMDATA.mb.fi

#        data_next = DataLoader.loadInitDataAndForcing(dli, OMDATA.clock.time + Δt)

        #_, m, d = DataLoader.getYMD(OMDATA.clock.time)

#        pred_cnt += 1
        #if any(d .== compute_qflx_dates[m])
#        if pred_cnt == pred_steps 

#            writeLog("# [Warning] Compare to OGCM, compute QFLX and reinitialize")

            # compute QFLX
#            _Δt = Δt_float * pred_steps
#            @. fi.sv[:QFLXT] = (data_next["TEMP"] - fi.sv[:TEMP]) / _Δt
#            @. fi.sv[:QFLXS] = (data_next["SALT"] - fi.sv[:SALT]) / _Δt
#
#            reinitModel!(OMDATA, data_next; forcing=true, thermal=true) 
            

    end,

    master_finalize! = function(OMMODULE, OMDATA)
        writeLog("[Coupler] Finalize")
    end, 
)

runModel(
    ENGINE_EMOM, 
    coupler_funcs,
    config, 
)
