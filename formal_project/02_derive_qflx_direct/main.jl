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
    cdata_varnames = ["TEMP", "SALT", "SFWF", "TAUX", "TAUY", "SHF", "SHF_QSW", "HMXL"]

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
    t_end   = DateTimeNoLeap(year_rng[2]+1, 1, 1, 0, 0, 0)

    first_run = true
end

coupler_funcs = (

    master_before_model_init = function()

        return read_restart, t_start
    end,

    master_after_model_init! = function(OMMODULE, OMDATA)
            # setup forcing

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
            reinitModel!(OMDATA, data) 
           
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

        data = loadData(
            OGCM_files,
            cdata_varnames,
            Dates.year(t),
            Dates.month(t),
            Dates.day(t), 
        )

        fi = OMDATA.mb.fi

        # compute QFLX
        @. fi.sv[:QFLXT] = (data["TEMP"] - fi.TEMP) / Δt_float
        @. fi.sv[:QFLXS] = (data["SALT"] - fi.SALT) / Δt_float

        reinitModel!(OMDATA, data) 

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
