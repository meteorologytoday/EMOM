
module CORE_NULLOM

    using MPI
    using Dates
    using Formatting
    using ..ModelClockSystem
    
    name = "CORE_NULLOM"

    mutable struct NULLOM_DATA
        casename    :: AbstractString
        clock       :: ModelClock
        configs     :: Dict
        data        :: Dict
    end

    function init(;
        casename     :: AbstractString,
        clock        :: ModelClock,
        configs      :: Dict,
        read_restart :: Bool,
    )

        data = Dict(
            :x => 0.0,
            :y => zeros(Float64, 10),
        )

        MD = NULLOM_DATA(
            casename,
            clock,
            configs,
            data,
        ) 


        addAlarm!(
            clock,
            "Every 2 hours alarm",
            clock.time,
            3;
            recurring = Hour(2),
        )

        addAlarm!(
            clock,
            "Everyday alarm",
            clock.time,
            2;
            recurring = Hour(24),
        )


        return MD

    end

    function run!(
        MD            :: NULLOM_DATA;
        Δt            :: TimePeriod,
        write_restart :: Bool,
    )

        println(format("Model Run with Δt = {:d} seconds", Second(Δt).value))

        if write_restart
            println("`write_restart` is ture.")
        end

    end

    function final(MD::NULLOM_DATA)
        println("Finalization.")
    end

    function newDay()
        println("New day! We are suppose to create file.")
    end


    function record()
        println("Record!")
    end

end

