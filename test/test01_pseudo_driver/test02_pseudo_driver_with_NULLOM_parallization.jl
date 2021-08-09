include("HOOM/src/driver/pseudo_driver.jl")
include("CORE_NULLOM_MPI.jl")

using CFTime
using MPI

MPI.Init()

comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)
println("Hello world, I am $(rank) of $(MPI.Comm_size(comm))")
MPI.Barrier(comm)

if MPI.Comm_rank(comm) == 0
     
    println(format("I am rank 0. Initiating ocean model..."))

    t_start = DateTimeNoLeap(1, 1, 1)
    Δt = Dates.Second(1800)
    steps = Int64(1*86400 / Δt.value)
    t_end = t_start + Δt * steps

    read_restart = false

    configs = Dict(
        :casename => "mini_model_NULLOM"
    )

    coupler_funcs = (
        before_model_init! = function()
            println("[Coupler] before model init")
            return t_start, read_restart
        end,
        after_model_init! = function(OMMODULE, OMDATA)
            println("[Coupler] After model init")
        end,
        before_model_run! = function(OMMODULE, OMDATA)
            println("[Coupler] Before model run")

            t_end_reached = OMDATA.clock.time >= t_end
            
            return ((t_end_reached) ? :END : :RUN), Δt, t_end_reached
        end,
        after_model_run! = function(OMMODULE, OMDATA)
            println("[Coupler] After model run")
        end,
        finalize! = function(OMMODULE, OMDATA)
            println("[Coupler] Finalize")
        end 
    )


    runModel(
        CORE_NULLOM, 
        configs,
        coupler_funcs,
    )

else

    println(format("I am rank {:d}. Waiting for information from master.", rank))
    Irecv! 
end 
