include("IOM/src/share/LogSystem.jl")
include("IOM/src/share/PolelikeCoordinate.jl")
include("IOM/src/models/EMOM/ENGINE_EMOM.jl")
include("IOM/src/driver/driver_working.jl")
include("IOM/src/share/CyclicData.jl")
include("DataLoader.jl")
include("func_reinitModel.jl")
include("func_data2SOM.jl")

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

        "--hist-dir"
            help = "Annual forcing file. It should contain: TAUX, TAUY, SWFLX, NSWFLX, VSFLX"
            arg_type = String
            required = true

        "--year-rng"
            help = "The year range that the user wants to run. The begin date will be set to 12/31 of the year before the first year."
            nargs = 2
            required = true
            arg_type = Int64

        "--SOM"
            help = "If set then HMXL will be set to the deepest z_w_bot. Remember to double check Nz_bot file."
            arg_type = Bool
            default = false

    end

    return parse_args(s)
end

parsed = parse_commandline()

MPI.Init()
comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)
is_master = rank == 0

config = nothing
SOM_HMXL = nothing
if is_master

    year_rng = parsed["year-rng"]


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


    if parsed["SOM"]
        global SOM_HMXL = minimum(cfgmc["z_w"])
        cfgmc["Ks_V"] = 0.0

        println("`SOM` also set convective_adjustment = off and Ks_V = 0.0")
        println("HMXL will always be set to $(SOM_HMXL)")

    end

    dli = DataLoader.DataLoaderInfo(
        hist_dir = parsed["hist-dir"],
        casename = "paper2021_POP2_CTL",
        state_varnames = ["TEMP", "SALT", "HMXL",],
        forcing_varnames = ["SFWF", "TAUX", "TAUY", "SHF", "SHF_QSW",],
        year_rng = year_rng,
        layers = 1:Nz,
    )

    pred_steps = 5
    pred_cnt = 0

    t_start = DateTimeNoLeap(year_rng[1], 1, 1, 0, 0, 0) - pred_steps*Δt
    t_end   = DateTimeNoLeap(year_rng[2], 1, 1, 0, 0, 0)


end


global data = nothing
global QFLXT = nothing
global QFLXS = nothing
global Nz_bot = nothing

coupler_funcs = (

    master_before_model_init = function()

        return read_restart, t_start
    end,

    master_after_model_init! = function(OMMODULE, OMDATA)
            # setup forcing
        println("# Model beg time: $(string(t_start))")
        println("# Model end time: $(string(t_end))")
        
        if parsed["SOM"]
            println("SOM specific: Load Nz_bot for later usage.")
            global Nz_bot = OMDATA.mb.ev.topo.Nz_bot_sT
        end

    end,

    master_before_model_run! = function(OMMODULE, OMDATA)

        global first_run, data, SOM_HMXL

        if first_run

            first_run = false

            # only put the TEMP and SALT of
            # the day before start date into the model           
            
            data_init = DataLoader.loadInitDataAndForcing(dli, OMDATA.clock.time)
            if parsed["SOM"]
                println("SOM would propagate SST and SSS to the whole column")
                data2SOM!(data_init["TEMP"], Nz_bot)
                data2SOM!(data_init["SALT"], Nz_bot)
            end

            reinitModel!(
                OMDATA,
                data_init;
                forcing = true, 
                thermal = true,
                SOM_HMXL = SOM_HMXL, 
            ) 
            
            global QFLXT = copy(data_init["TEMP"])
            global QFLXS = copy(QFLXT)
            QFLXT .= 0.0
            QFLXS .= 0.0


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

        global pred_reinit, pred_cnt, data
            
        fi = OMDATA.mb.fi

        data_next = DataLoader.loadInitDataAndForcing(dli, OMDATA.clock.time + Δt)
        if parsed["SOM"]
            println("SOM would propagate SST and SSS to the whole column")
            data2SOM!(data_next["TEMP"], Nz_bot)
            data2SOM!(data_next["SALT"], Nz_bot)
        end


        #_, m, d = DataLoader.getYMD(OMDATA.clock.time)

        pred_cnt += 1
        #if any(d .== compute_qflx_dates[m])
        if pred_cnt == pred_steps 

            writeLog("# [Warning] Compare to OGCM, compute QFLX and reinitialize")

            # compute QFLX
            _Δt = Δt_float * pred_steps
#            @. fi.sv[:QFLXT] = (data_next["TEMP"] - fi.sv[:TEMP]) / _Δt
#            @. fi.sv[:QFLXS] = (data_next["SALT"] - fi.sv[:SALT]) / _Δt
            @. QFLXT = (data_next["TEMP"] - fi.sv[:TEMP]) / _Δt
            @. QFLXS = (data_next["SALT"] - fi.sv[:SALT]) / _Δt


            reinitModel!(OMDATA, data_next; forcing=true, thermal=true, SOM_HMXL=SOM_HMXL) 
            
            pred_cnt = 0
        else
            reinitModel!(OMDATA, data_next; forcing=true, thermal=false, SOM_HMXL=SOM_HMXL)
            #fi._QFLXX_ .= 0.0
        end

        fi.sv[:QFLXT] .= QFLXT
        fi.sv[:QFLXS] .= QFLXS

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
