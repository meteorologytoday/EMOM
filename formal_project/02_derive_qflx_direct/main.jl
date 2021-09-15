include("IOM/src/share/LogSystem.jl")
include("IOM/src/share/PolelikeCoordinate.jl")
include("IOM/src/models/EMOM/ENGINE_EMOM.jl")
include("IOM/src/driver/driver_working.jl")
include("IOM/src/share/CyclicData.jl")

using MPI
using CFTime, Dates
using ArgParse
using TOML
using DataStructures
using NCDatasets
using .PolelikeCoordinate
using .LogSystem
using .CyclicData

include("func_checkData.jl")
include("func_loadData.jl")
include("func_reinitModel.jl")


function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--config-file"
            help = "Configuration file."
            arg_type = String
            required = true

        "--hist-dir"
            help = "Annual forcing file. It should contain: TAUX, TAUY, SWFLX, NSWFLX, VSFLX"
            arg_type = String
            required = true

        "--year-rng"
            help = "The year range that the user wants to run. The begin date will be set to 12/31 of the year before the first year."
            nargs = 2
            required = true
            arg_type = Int64

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

    year_rng = parsed["year-rng"]
    cdata_varnames = ["TEMP", "SALT", "SFWF", "TAUX", "TAUY", "SHF", "SHF_QSW", "HMXL", "HBLT"]

    # check forcing files
    OGCM_files = checkData(
        parsed["hist-dir"],
        "paper2021_POP2_CTL",
        cdata_varnames,
        year_rng;
        verbose = true,
    )


    config = TOML.parsefile(parsed["config-file"])
    config["DRIVER"]["sync_thermo_state_before_stepping"] = true

    Δt_float = 86400.0
    Δt = Dates.Second(Δt_float)
    read_restart = false

    cfgmc = config["MODEL_CORE"]
    cfgmm = config["MODEL_MISC"]

    cfgmc["Qflx"] = "off"
    cfgmc["weak_restoring"] = "off"
    cfgmc["transform_vector_field"] = false
    
    Nz = length(cfgmc["z_w"])-1

    t_start = DateTimeNoLeap(year_rng[1],   1, 1, 0, 0, 0) - Δt
    #t_end   = DateTimeNoLeap(year_rng[2]+1, 1, 1, 0, 0, 0)
    t_end   = DateTimeNoLeap(year_rng[1], 2, 1, 0, 0, 0)

    first_run = true

    pred_steps = 5
    pred_cnt = 0

    Dataset("mixedlayer.nc", "r") do ds
        global h_mean = nomissing(ds["HBLT"][:, :, 1], NaN)
    end

end

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

        global first_run

        if first_run

            first_run = false
            
            t = OMDATA.clock.time 
            data = loadData(
                OGCM_files,
                cdata_varnames,
                Dates.year(t),
                Dates.month(t),
                Dates.day(t);
                layers = 1:Nz, 
            )
            reinitModel!(OMDATA, data; forcing=true, thermal=true) 
 
            global pred_reinit = false
            global pred_cnt = 0
          
        end

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

        global pred_reinit, pred_cnt
            
        fi = OMDATA.mb.fi

        t = OMDATA.clock.time + Δt # remember we need to step once more because clock has not advanced yet 
        data = loadData(
            OGCM_files,
            cdata_varnames,
            Dates.year(t),
            Dates.month(t),
            Dates.day(t);
            layers = 1:Nz, 
        )
#            data["TEMP"] .= 10.0
#            data["SALT"] .= 35.0
#            data["SHF"]  .= 100.0
#            data["SHF_QSW"] .= 0.0
            data["HBLT"] .= h_mean

        pred_cnt += 1

        if pred_cnt == pred_steps

            writeLog("Compare to OGCM, compute QFLX and reinitialize")

            # compute QFLX
            _Δt = Δt_float #* pred_steps
            @. fi.sv[:QFLXT] = (data["TEMP"] - fi.sv[:TEMP]) / _Δt
            @. fi.sv[:QFLXS] = (data["SALT"] - fi.sv[:SALT]) / _Δt

#            data["TEMP"] .= 10.0
#            data["SALT"] .= 35.0
            reinitModel!(OMDATA, data; forcing=true, thermal=true) 
             
            pred_cnt = 0
        else

            reinitModel!(OMDATA, data; forcing=true, thermal=false) 
            fi._QFLXX_ .= 0.0
        end
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
