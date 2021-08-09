module ModelClockSystem

    export ModelAlarm, ModelClock, advanceClock!, setClock!, addAlarm!, clock2str, dt2str, dt2tuple

    using CFTime, Formatting

    using Dates
    using Dates: CompoundPeriod

    mutable struct ModelAlarm
        name      :: String
        time      :: AbstractCFDateTime
        priority  :: Integer   # There might be multiple alarms ring at the same time. And if order is important, then the higher the number the higher the priority.
        callbacks :: Array{Function, 1}
        recurring :: Union{Nothing, Period, CompoundPeriod}
        done      :: Bool
    end

    function isEarlier(x :: ModelAlarm, y :: ModelAlarm)
        return (x.time < y.time) || ( (x.time == y.time) && (x.priority > y.priority))
    end

    function isEqual(x :: ModelAlarm, y :: ModelAlarm)
        return (x.time == y.time) && (x.priority == y.priority)
    end

    function isLater(x :: ModelAlarm, y :: ModelAlarm)
        return ! ( isEarlier(x, y) ||  isEqual(x, y) )
    end


    mutable struct ModelClock
        
        name         :: String
        time         :: AbstractCFDateTime
        alarms       :: Array{ModelAlarm, 1}
        alarms_dict  :: Dict
        alarm_ptr    :: Integer 
        
        function ModelClock(
            name :: String,
            time :: AbstractCFDateTime,
        )
            alarms = Array{ModelAlarm}(undef, 0)
            alarms_dict = Dict()
            return new(
                name,
                time + Dates.Second(0),
                alarms,
                alarms_dict,
                0,
            )
        end

    end

    function checkType(time1 :: AbstractCFDateTime, time2 :: AbstractCFDateTime)
        if typeof(time1) != typeof(time2)
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

        # Only check alarms when there is any
        if length(mc.alarms) > 0
            if mc.alarm_ptr == 0 && mc.time >= mc.alarms[1].time
                mc.alarm_ptr = 1
            end

            while (0 < mc.alarm_ptr <= length(mc.alarms)) && (mc.time >= mc.alarms[mc.alarm_ptr].time)
                    ringAlarm!(mc, mc.alarms[mc.alarm_ptr])

                    # In case we are at the end of alarm array
                    if mc.alarm_ptr == length(mc.alarms) 
                        break
                    else
                        mc.alarm_ptr += 1
                    end
            end
        end

    end

    function ringAlarm!(mc :: ModelClock, alarm :: ModelAlarm)
        if ! alarm.done
            println(format("Alarm '{:s}' rings at {:s}", alarm.name, dt2str(alarm.time)))

            for callback in alarm.callbacks
                callback(mc, alarm)
            end

            if alarm.recurring != nothing
                addAlarm!(
                    mc,
                    alarm.name,
                    alarm.time + alarm.recurring,
                    alarm.priority;
                    callback = alarm.callbacks,
                    recurring = alarm.recurring * 1,
                )
            end

            alarm.done = true
        end
    end

    function clock2str(mc :: ModelClock)
        return dt2str(mc.time)
    end

    function dt2str(dt)
        return format("{:04d}-{:02d}-{:02d} {:02d}:{:02d}:{:02d}", dt2tuple(dt)...)
    end

    function dt2tuple(dt)
        return (Dates.year(dt), Dates.month(dt), Dates.day(dt), Dates.hour(dt), Dates.minute(dt), Dates.second(dt))
    end

    function addAlarm!(
        mc   :: ModelClock,
        name :: String,
        time :: AbstractCFDateTime,
        priority :: Integer;
        callback :: Union{Array{Function, 1}, Function, Nothing} = nothing,
        recurring :: Union{ Nothing, Period, CompoundPeriod} = nothing,
    )

        checkType(time, mc.time)
        
        if callback == nothing
            callbacks = Array{Function, 1}(undef, 0)
        elseif typeof(callback) <: Function
            callbacks = [ callback ]
        else # it is already an array
            callbacks = callback
        end        

        alarm = ModelAlarm(
            name,
            time,
            priority,
            callbacks,
            recurring,
            false,
        )
        
        if mc.alarm_ptr == 0
            mc.alarm_ptr = 1
        end

        if alarm.time < mc.time 
            println("alarm.time = ", dt2str(alarm.time))
            throw(ErrorException("Alarm needs to be set in the future."))
        end

        push!(mc.alarms, alarm)
        if ! haskey(mc.alarms_dict, name)
            mc.alarms_dict[name] = []
        end



        if (mc.alarm_ptr > 1) && (isEarlier(alarm, mc.alarms[mc.alarm_ptr]) || isEqual(alarm, mc.alarms[mc.alarm_ptr]))
            mc.alarm_ptr -= 1
        end
        
        push!(mc.alarms_dict[name], alarm)
        # lt = less than = earlier and higher priority
        sort!(mc.alarms, lt = isEarlier)

        if alarm.time == mc.time
            # Ring immediately
            advanceClock!(mc, Second(0))
        end


    end

end
