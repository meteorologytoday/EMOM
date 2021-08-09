using CFTime
using Dates
using Formatting
using JSON
using Distributed
using SharedArrays


if !(:ModelClockSystem in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "share", "ModelClockSystem.jl")))
end
using .ModelClockSystem


function runModel(
    OMMODULE      :: Any,
    configs       :: Dict,
    coupler_funcs :: Any, 
)


    t_start, read_restart = coupler_funcs.before_model_init!()

    # copy the start time
    beg_datetime = t_start + Dates.Second(0)
    println(format("Begin datetime: {:s}", dt2str(beg_datetime) ))
    println(format("Read restart  : {}", read_restart))

    # Construct model clock
    clock = ModelClock("Model", beg_datetime)

    # initializing
    println("===== INITIALIZING MODEL: ", OMMODULE.name , " =====")
    OMDATA = OMMODULE.init(
        casename     = configs[:casename],
        clock        = clock,
        configs      = configs,
        read_restart = read_restart,
    )

    coupler_funcs.after_model_init!(OMMODULE, OMDATA)
    
    println("Ready to run the model.")
    step = 0
    while true

        step += 1
        
        println(format("Current time: {:s}", clock2str(clock)))

        stage, Δt, write_restart = coupler_funcs.before_model_run!(OMMODULE, OMDATA)

        if stage == :RUN 
            cost = @elapsed let

                OMMODULE.run!(
                    OMDATA;
                    Δt = Δt,
                    write_restart = write_restart,
                )

            end
            advanceClock!(clock, Δt)
            coupler_funcs.after_model_run!(OMMODULE, OMDATA)

        elseif stage == :END
            println("stage == :END. Break loop now.")
            break
        end
    end
        
    coupler_funcs.finalize!(OMMODULE, OMDATA)
    
    println("Program Ends.")

end
  
