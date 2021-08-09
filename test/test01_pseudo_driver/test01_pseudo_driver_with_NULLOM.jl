include("HOOM/src/driver/pseudo_driver.jl")

include("CORE_NULLOM.jl")

using CFTime

t_start = DateTimeNoLeap(1, 1, 1)
Δt = Dates.Second(1800)
steps = Int64(2*86400 / Δt.value)
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
