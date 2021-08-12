

include("IOM/src/share/LogSystem.jl")
include("IOM/src/share/PolelikeCoordinate.jl")

include("IOM/src/models/EMOM/ENGINE_EMOM.jl")
include("IOM/src/driver/driver.jl")

using MPI
using CFTime
using Dates
using ArgParse
using .PolelikeCoordinate
using .LogSystem

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin
        "--read-restart"
            help = "Configuration file."
            arg_type = Bool
       
        "--stop-n"
            help = "Core of the model."
            arg_type = Int64

        
        "--time-unit"
            help = "."
            arg_type = String
    end

    return parse_args(s)
end

parsed = parse_commandline()

t_start = DateTimeNoLeap(1, 1, 1)

time_unit = Dict(
    "year" => Dates.Year,
    "month" => Dates.Month,
    "day"   => Dates.Day,
)[parsed["time-unit"]]

t_simulation = time_unit(parsed["stop-n"])

MPI.Init()
comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)
Δt = Second(86400)

include("config.jl")

if rank == 0
    gf = PolelikeCoordinate.CurvilinearSphericalGridFile(
        config[:MODEL_CORE][:domain_file],
        R  = 6371229.0,
        Ω  = 2π / (86400 / (1 + 365/365)),
    )

end


coupler_funcs = (
    after_model_init! = function(OMMODULE, OMDATA)
        writeLog("[Coupler] After model init")
    end,

    before_model_run! = function(OMMODULE, OMDATA)
        writeLog("[Coupler] Before model run")
        writeLog("[Coupler] This is where flux exchange happens.")

        global comm, rank
        
        is_master = rank == 0
        
        # Test if t_end is reached
        return_values = nothing
        if is_master
            t_end_reached = OMDATA.clock.time >= t_end
           
            if t_end_reached
                return_values = ( :END, Δt, t_end_reached )
            else
                return_values = ( :RUN, Δt, t_end_reached )
            end
        end

        return_values = MPI.bcast(return_values, 0, comm)

        # Deal with coupling
        if is_master

            writeLog("[Coupler] Need to broadcast forcing fields.")
            # compute flux
            lat = gf.yc
            lon = gf.xc

            OMDATA.x2o["SWFLX"][1, :, :] .= - (cos.(deg2rad.(lat).+0.1) .+ 1) / 2 .* (sin.(deg2rad.(lon)) .+ 1)/2 * 100.0
            OMDATA.x2o["TAUX_east"][1, :, :]   .= 0.2 * (cos.(deg2rad.(lat).+0.1) .+ 1) / 2
            OMDATA.x2o["TAUY_north"][1, :, :]  .= 0.1 * (sin.(deg2rad.(lon)) .+ 1) / 2
#cos.(deg2rad.(lat))
            
        end


        return return_values

    end,

    after_model_run! = function(OMMODULE, OMDATA)
        writeLog("[Coupler] After model run")
    end,

    final = function(OMMODULE, OMDATA)
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
