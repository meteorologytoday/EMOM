using CFTime
using Dates
using Formatting
using JLD2
using Distributed
using SharedArrays
using MPI

if !(:ModelClockSystem in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "share", "LogSystem.jl")))
end
using .LogSystem


if !(:ModelClockSystem in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "share", "ModelClockSystem.jl")))
end
using .ModelClockSystem

if !(:ConfigCheck in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "share", "ConfigCheck.jl")))
end
using .ConfigCheck

if !(:appendLine in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "share", "AppendLine.jl")))
end




function runModel(
    OMMODULE      :: Any,
    coupler_funcs :: Any,
    t_start       :: AbstractCFDateTime,
    t_simulation  :: Any,
    read_restart  :: Bool,
    config        :: Dict, 
)

    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)

    writeLog("===== [ Master Created ] =====")

    MPI.Barrier(comm)

    is_master = rank == 0

    if is_master
        writeLog("Validate driver config.")
        config[:DRIVER] = validateConfigEntries(config[:DRIVER], getDriverConfigDescriptor())
    end


    writeLog("Setting working directory: {:s}", config[:DRIVER][:caserun])
    cd(config[:DRIVER][:caserun])

    if is_master

        global t_start, t_end

        if read_restart
            writeLog("read_restart is true.")
            restart_info = JLD2.load("model_restart.jld2")
            t_start = restart_info["timestamp"]
        end

        t_end = t_start + t_simulation

        writeLog("### Simulation time start: {:s}", Dates.format(t_start, "yyyy-mm-dd HH:MM:SS"))
        writeLog("### Simulation time end  : {:s}", Dates.format(t_end, "yyyy-mm-dd HH:MM:SS"))
         
    end

    writeLog("Passing t_start and config to slaves.")
    if ! is_master
        t_start = nothing 
        config = nothing
    end
    t_start = MPI.bcast(t_start, 0, comm) 
    config = MPI.bcast(config, 0, comm) 



    # copy the start time
    beg_datetime = t_start + Dates.Second(0)

    writeLog("Read restart  : {}", read_restart)

    # Construct model clock
    clock = ModelClock("Model", beg_datetime)

    # initializing
    is_master && println("===== INITIALIZING MODEL: ", OMMODULE.name , " =====")
    
    OMDATA = OMMODULE.init(
        casename     = config[:DRIVER][:casename],
        clock        = clock,
        config      = config,
        read_restart = read_restart,
    )

    coupler_funcs.after_model_init!(OMMODULE, OMDATA)
    
    is_master && println("Ready to run the model.")
    step = 0
    while true

        step += 1
        
        writeLog("Current time: {:s}", clock2str(clock))

        stage, Δt, write_restart = coupler_funcs.before_model_run!(OMMODULE, OMDATA)

        if stage == :RUN 

            cost = @elapsed let

                OMMODULE.run!(
                    OMDATA;
                    Δt = Δt,
                )

                MPI.Barrier(comm)

            end
            writeLog("Computation cost: {:f} secs.", cost)
            coupler_funcs.after_model_run!(OMMODULE, OMDATA)
            
            advanceClock!(clock, Δt)

            

        elseif stage == :END
            writeLog("stage == :END. Break loop now.")
            break
        end

    end
    
    OMMODULE.final(OMDATA) 
    coupler_funcs.final(OMMODULE, OMDATA)
        
    if is_master

        writeLog("Writing restart file of driver")
        
        JLD2.save("model_restart.jld2", "timestamp", clock.time)
        archive_list_file = joinpath(
            config[:DRIVER][:caserun],
            config[:DRIVER][:archive_list],
        )

        timestamp_str = format(
            "{:s}-{:05d}",
            Dates.format(clock.time, "yyyy-mm-dd"),
            floor(Int64, Dates.hour(clock.time)*3600+Dates.minute(clock.time)*60+Dates.second(clock.time)),
        )

        appendLine(archive_list_file,
            format("cp,{},{},{}",
                "model_restart.jld2",
                config[:DRIVER][:caserun],
                joinpath(config[:DRIVER][:archive_root], "rest", timestamp_str)
            )
        ) 

    end

    if is_master
        archive(joinpath(
            config[:DRIVER][:caserun],
            config[:DRIVER][:archive_list],
        ))
    end
 
    is_master && println("Program Ends.")

end

function getDriverConfigDescriptor()

    return [
            ConfigEntry(
                :casename,
                :required,
                [String,],
            ),

            ConfigEntry(
                :caseroot,
                :required,
                [String,],
            ),

            ConfigEntry(
                :caserun,
                :required,
                [String,],
            ),

            ConfigEntry(
                :archive_root,
                :required,
                [String,],
            ),

            ConfigEntry(
                :archive_list,
                :optional,
                [String,],
                "archive_list.txt",
            ),
   ]
end

function archive(
    archive_list_file :: String,
)

    println("===== Archiving files BEGIN =====")
    
    for line in eachline(archive_list_file)

        args = split(line, ",")

        if length(args) == 0
            continue
        end
      
        action = args[1]
        args = args[2:end]

        if action in ["mv", "cp"]

            fname, src_dir, dst_dir = args

            if ! isdir(dst_dir)
                mkpath(dst_dir)
            end
 
            src_file = joinpath(src_dir, fname)
            dst_file = joinpath(dst_dir, fname)

            if isfile(src_file)

                if action == "mv"
                    mv(src_file, dst_file, force=true)
                    println(format("Moving file: {:s} ( {:s} => {:s} )", fname, src_dir, dst_dir))
                elseif action == "cp"
                    cp(src_file, dst_file, force=true)
                    println(format("Copying file: {:s} ( {:s} => {:s} )", fname, src_dir, dst_dir))
                end

            else
                println("File does not exist: ", src_file)
            end

        elseif action == "rm"
            fname, fdir = args
            rm(joinpath(fdir, fname), force=true)
            println(format("Removing file: {:s} in {:s}", fname, fdir))
        else
            throw(ErrorException(format("Unknown action in archive list: {:s}", action)))
        end

    end

    println("===== Archiving files END =====")

end
