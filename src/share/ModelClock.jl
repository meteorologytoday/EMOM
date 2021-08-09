module ModelClockSystem

    using CFTime
    using Dates

    mutable struct Alarm
        name :: String
        time :: AbstractCFDateTime
        callbacks :: Array{Function, 1}
    end

    mutable struct ModelClock

        time         :: AbstractCFDateTime
        alarms       :: Array{Alarm, 1}

        function ModelClock(time :: AbstractCFDateTime)
            alarms = Array{Alarm}(undef, 0)
            return new(
                time + Dates.Second(0),
                alarms,
            )
        end

    end

    function checkType(time1 :: AbstractCFDateTime, time2 :: AbstractCFDateTime)
        if typeof(time1) != timeof(time2)
            throw(ErrorException("Time type does not match!"))
        end
    end

    function setClock!(
        mc :: ModelClock,
        time :: AbstractCFDateTime,
    )

        checkType(mc.time, time)
        mc.time = time + Second(0)

    end

    function advanceClock!(
        mc :: ModelClock,
        t :: Union{Second, AbstractCFDateTime},
    )
        
        if typeof(t) <: Second  # inteprete as time interval
            mc.time += t
        elseif typeof(Δt) <: AbstractCFDateTime
            setClock!(mc, t)
        end

    end

end
