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
            help = "The year range that the user wants to run."
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
    cdata_varnames = ["TEMP", "SALT", "SFWF", "TAUX", "TAUY", "SHF", "SHF_QSW"]

    # check forcing files
    OGCM_files = checkData(
        parsed["hist-dir"],
        "paper2021_POP2_CTL",
        cdata_varnames,
        year_rng;
        verbose = true,
    )


    config = TOML.parsefile(parsed["config-file"])

    t_simulation = time_unit(parsed["stop-n"])
    Δt = Dates.Second(86400)
    read_restart = false

    cfgmc = config["MODEL_CORE"]
    cfgmm = config["MODEL_MISC"]

    cfgmc["Qflx"] = "off"
    cfgmc["weak_restoring"] = "off"
    cfgmc["transform_vector_field"] = false

    t_start = DateTimeNoLeap(1, 1, 1, 0, 0, 0)
    t_end = t_start + t_simulation

end

coupler_funcs = (

    master_before_model_init = function()

        return read_restart, t_start
    end,

    master_after_model_init! = function(OMMODULE, OMDATA)
            # setup forcing

    end,

    master_before_model_run! = function(OMMODULE, OMDATA)

        global cdata_var_file_map

        if flag_new_month
            cdata_var_file_map = Dict()
        for varname in cdata_varnames
            cdata_var_file_map[varname] = 
        end


            global cdatam = CyclicDataManager(;
                timetype     = getproperty(CFTime, Symbol(cfgmm["timetype"])),
                filename     = parsed["forcing-file"],
                varnames     = ["TAUX", "TAUY", "SWFLX", "NSWFLX", "VSFLX"],
                beg_time     = DateTimeNoLeap(1, 1, 1),
                end_time     = DateTimeNoLeap(2, 1, 1),
                align_time   = DateTimeNoLeap(1, 1, 1),
            )

            global datastream = makeDataContainer(cdatam)


        global datastream

        write_restart = OMDATA.clock.time == t_end
        end_phase = OMDATA.clock.time > t_end

        if ! end_phase

            interpData!(cdatam, OMDATA.clock.time, datastream)
            OMDATA.x2o["SWFLX"]       .= datastream["SWFLX"]
            OMDATA.x2o["NSWFLX"]      .= datastream["NSWFLX"]
            OMDATA.x2o["VSFLX"]       .= datastream["VSFLX"]
            OMDATA.x2o["TAUX_east"]   .= datastream["TAUX"]
            OMDATA.x2o["TAUY_north"]  .= datastream["TAUY"]

            return_values = ( :RUN,  Δt, write_restart )
        else
            return_values = ( :END, 0.0, write_restart  )
        end

        return return_values
    end,

    master_after_model_run! = function(OMMODULE, OMDATA)
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
