include("IOM/src/share/LogSystem.jl")
include("IOM/src/share/PolelikeCoordinate.jl")
include("IOM/src/models/EMOM/ENGINE_EMOM.jl")
include("IOM/src/driver/driver_working.jl")
include("IOM/src/share/CyclicData.jl")

using MPI
using CFTime, Dates
using ArgParse
using TOML

using .PolelikeCoordinate
using .LogSystem
using .CyclicData
function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--config-file"
            help = "Configuration file."
            arg_type = String
            required = true

        "--atm-forcing-dir"
            help = "Data containing atm forcing file. It should contain: TAUX, TAUY, SWFLX, NSWFLX, VSFLX"
            arg_type = String
            required = true

        "--nudging-timescale-day"
            help = "Nudging timescale used to replace weak restoring timescale when finding Q-flux in days. Default is 5 days."
            arg_type = Float64
            default = 5.0

        "--stop-n"
            help = "Core of the model."
            arg_type = Int64

        "--time-unit"
            help = "Unit of `stop-n`."
            arg_type = String

        "--verify-mode"
            help = "If specified then Qflx is applied and nudging timescale is changed to 1000 years."
            action = :store_true


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



    time_unit = Dict(
        "year" => Dates.Year,
        "month" => Dates.Month,
        "day"   => Dates.Day,
    )[parsed["time-unit"]]

    t_simulation = time_unit(parsed["stop-n"])

    Δt = Dates.Second(86400)
    read_restart = false

    cfgmc = config["MODEL_CORE"]
    cfgmm = config["MODEL_MISC"]


    cfgmc["Qflx"] = "off"
    cfgmc["weak_restoring"] = "on"
    cfgmc["τwk_TEMP"] = parsed["nudging-timescale-day"] * 86400.0
    cfgmc["τwk_SALT"] = parsed["nudging-timescale-day"] * 86400.0

    if parsed["verify-mode"]
        cfgmc["Qflx"] = "on"
        cfgmc["weak_restoring"] = "on"
        cfgmc["τwk_TEMP"] = 86400.0 * 365 * 1000.0
        cfgmc["τwk_SALT"] = 86400.0 * 365 * 1000.0
    end


    cfgmc["transform_vector_field"] = false

    t_start = DateTimeNoLeap(1, 1, 1, 0, 0, 0)
    t_end = t_start + t_simulation

end

coupler_funcs = (

    master_before_model_init = function()

        cdata_var_file_map = Dict()

        for varname in ["TAUX", "TAUY", "SWFLX", "NSWFLX", "VSFLX"]
            cdata_var_file_map[varname] = "$(parsed["atm-forcing-dir"])/$(varname).nc"
        end


        global cdatam = CyclicDataManager(;
            timetype     = getproperty(CFTime, Symbol(cfgmm["timetype"])),
            var_file_map = cdata_var_file_map,
            beg_time     = DateTimeNoLeap( 1, 1, 1),
            end_time     = DateTimeNoLeap(51, 1, 1),
            align_time   = DateTimeNoLeap( 1, 1, 1),
        )

        global datastream = makeDataContainer(cdatam)

        return read_restart, t_start
    end,

    master_after_model_init! = function(OMMODULE, OMDATA)
            # setup forcing

    end,

    master_before_model_run! = function(OMMODULE, OMDATA)

        global datastream

        t_end_reached = OMDATA.clock.time >= t_end

        if ! t_end_reached

            interpData!(cdatam, OMDATA.clock.time, datastream)
            OMDATA.x2o["SWFLX"]       .= datastream["SWFLX"]
            OMDATA.x2o["NSWFLX"]      .= datastream["NSWFLX"]
            OMDATA.x2o["VSFLX"]       .= datastream["VSFLX"]
            OMDATA.x2o["TAUX_east"]   .= datastream["TAUX"]
            OMDATA.x2o["TAUY_north"]  .= datastream["TAUY"]

            return_values = ( :RUN,  Δt, t_end_reached )
        else
            return_values = ( :END, 0.0, t_end_reached  )
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
