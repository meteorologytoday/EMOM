module ModelClockSystem

    export ModelAlarm, ModelClock, advanceClock!, setClock!, addAlarm!, clock2str, dt2str, dt2tuple, dropRungAlarm!

    using CFTime, Formatting

    using Dates
    using Dates: CompoundPeriod

    mutable struct ModelAlarm
        name      :: String
        time      :: AbstractCFDateTime
        priority  :: Integer   # There might be multiple alarms ring at the same time. And if order is important, then the higher the number the higher the priority.
        callbacks :: Array{Function, 1}
        recurring :: Union{Nothing, Period, CompoundPeriod, Function}
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
            #    println("Before ring alarm: mc.alarm_ptr  = $(mc.alarm_ptr)")
                # In case we are at the end of alarm array
               
                alarm_ptr_tmp = mc.alarm_ptr 
                if mc.alarm_ptr < length(mc.alarms) 
                    mc.alarm_ptr += 1
                end 
                ringAlarm!(mc, mc.alarms[alarm_ptr_tmp])
             #   println("xxx alarm_ptr = $(mc.alarm_ptr)")
                if mc.alarm_ptr == length(mc.alarms) 
                    break
                end
            end
        end


    end

    function ringAlarm!(mc :: ModelClock, alarm :: ModelAlarm)
        #println("alarm.time = $(alarm.time). done = $(alarm.done)")
        if ! alarm.done
            println(format("Alarm '{:s}' rings at {:s}", alarm.name, dt2str(alarm.time)))

            for callback in alarm.callbacks
                callback(mc, alarm)
            end
            
            # IMPORTANT: alarm.done has to be here.
            # If it is after addAlarm!, there is a potential recursive loop because
            # advanceClock! might be called when calling addAlarm! (i.e. ring immediately)
            alarm.done = true

            if alarm.recurring != nothing
                
                if isa(alarm.recurring, Function)
                    next_time = alarm.recurring(alarm.time)
                else
                    next_time = alarm.time + alarm.recurring
                end
                #println("Current time: $(string(alarm.time))")
                #println("Next alarm: " * string(next_time))
                addAlarm!(
                    mc,
                    alarm.name,
                    next_time,
                    alarm.priority;
                    callback = alarm.callbacks,
                    recurring = alarm.recurring,
                )
            end
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
        recurring :: Union{ Nothing, Period, CompoundPeriod, Function } = nothing,
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
            advanceClock!(mc, Second(0))
        end


    end

    function dropRungAlarm!(
        mc   :: ModelClock,
    )
        while length(mc.alarms) > 0 && mc.alarms[1].done
            alarm = popfirst!(mc.alarms)
            delete!(mc.alarms_dict, alarm.name)
            mc.alarm_ptr -= 1
            if mc.alarm_ptr < 0 
                throw(ErrorException("Error happens in alarm counts. Please check."))
            end
        end
    end

    function listAlarms(
        mc :: ModelClock,
    )
        for (i, alarm) in enumerate(mc.alarms)
            println("Alarm[$(i)] = $(alarm.time). [$( (alarm.done) ? "v" : " " )] $( (i==mc.alarm_ptr) ? "*" : "" )")
        end
    end
end
