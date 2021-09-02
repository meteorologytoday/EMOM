using CFTime
using Dates
using Formatting
using JLD2
using Distributed
using SharedArrays
using MPI

if !(:LogSystem in names(Main))
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
    config        :: Union{Dict, Nothing} = nothing, 
)

    comm = MPI.COMM_WORLD
    rank = MPI.Comm_rank(comm)
    ntask = MPI.Comm_size(comm)

    writeLog("===== [ Master Created ] =====")
    writeLog("Number of total tasks       : {:d}", ntask)
    writeLog("Number of total worker tasks: {:d}", ntask-1)


    MPI.Barrier(comm)

    is_master = rank == 0

    if is_master
        if config == nothing
            throw(ErrorException("Master thread needs to provide config parameter."))
        end

        writeLog("Validate driver config.")
        config["DRIVER"] = validateConfigEntries(config["DRIVER"], getDriverConfigDescriptor())
    end

    writeLog("Broadcast config to slaves.")
    config = MPI.bcast(config, 0, comm) 


    p = config["DRIVER"]["caserun"]
    writeLog("Setting working directory to {:s}", p)
    if is_master
        if ! isdir(p)
            writeLog("Working directory does not exist. Create it.")
            mkpath(p)
        end
    end
    MPI.Barrier(comm)
    cd(p)

    local t_start = nothing 
    local read_restart = nothing
 
    if is_master

        writeLog("Getting model start time.")
        read_restart, t_start = coupler_funcs.master_before_model_init()
        
        if read_restart

            writeLog("read_restart is true.")

            restart_info = JLD2.load("model_restart.jld2")
            restart_t_start = restart_info["timestamp"]

            if t_start == nothing
                writeLog("t_start == nothing. Skip checking restart time.")
            elseif t_start != restart_t_start
                throw(ErrorException(format("Model restart time inconsistent! The start time received from the coupler is {:s} while the restart file is {:s}.")))
            else
                writeLog("Model restart time is consistent.")
            end

        end

        writeLog("### Simulation time start: {:s}", Dates.format(t_start, "yyyy-mm-dd HH:MM:SS"))
         
    end

    writeLog("Broadcast t_start and read_restart to slaves.")
    t_start = MPI.bcast(t_start, 0, comm) 
    read_restart = MPI.bcast(read_restart, 0, comm) 


    # copy the start time by adding 0 seconds
    beg_datetime = t_start + Dates.Second(0)

    # Construct model clock
    clock = ModelClock("Model", beg_datetime)

    # initializing
    writeLog("===== INITIALIZING MODEL: {:s} =====", OMMODULE.name)
    
    OMDATA = OMMODULE.init(
        casename     = config["DRIVER"]["casename"],
        clock        = clock,
        config       = config,
        read_restart = read_restart,
    )

    if is_master
        coupler_funcs.master_after_model_init!(OMMODULE, OMDATA)
    end
    
    writeLog("Ready to run the model.")
    step = 0
    while true

        step += 1
       
        if is_master 
            writeLog("Current time: {:s}", clock2str(clock))
        end

        stage = nothing
        Δt    = nothing
        write_restart = nothing

        if is_master
            stage, Δt, write_restart = coupler_funcs.master_before_model_run!(OMMODULE, OMDATA)
        end
        stage         = MPI.bcast(stage, 0, comm) 
        Δt            = MPI.bcast(Δt, 0, comm) 
        write_restart = MPI.bcast(write_restart, 0, comm) 

        if stage == :RUN 

            cost = @elapsed let

                OMMODULE.run!(
                    OMDATA;
                    Δt = Δt,
                )

                MPI.Barrier(comm)

            end

            writeLog("Computation cost: {:.2f} secs.", cost)

            if is_master
                coupler_funcs.master_after_model_run!(OMMODULE, OMDATA)
                advanceClock!(clock, Δt)
                dropRungAlarm!(clock)
            end
           
            # Broadcast time to workers. Workers need time
            # because datastream needs time interpolation. 
            _time = MPI.bcast(clock.time, 0, comm) 
            if !is_master
                setClock!(clock, _time)
            end

        elseif stage == :END

            writeLog("Receive :END. Entering finalizing phase now.")
            break

        else
            
            throw(ErrorException("Unknown stage : " * string(stage)))

        end

    end
    
    if is_master

        coupler_funcs.master_finalize!(OMMODULE, OMDATA)

        writeLog("Writing restart time of driver")
        JLD2.save("model_restart.jld2", "timestamp", clock.time)

        archive_list_file = joinpath(
            config["DRIVER"]["caserun"],
            config["DRIVER"]["archive_list"],
        )

        timestamp_str = format(
            "{:s}-{:05d}",
            Dates.format(clock.time, "yyyy-mm-dd"),
            floor(Int64, Dates.hour(clock.time)*3600+Dates.minute(clock.time)*60+Dates.second(clock.time)),
        )

        appendLine(archive_list_file,
            format("cp,{},{},{}",
                "model_restart.jld2",
                config["DRIVER"]["caserun"],
                joinpath(config["DRIVER"]["archive_root"], "rest", timestamp_str)
            )
        ) 

    end

    if is_master
        archive(joinpath(
            config["DRIVER"]["caserun"],
            config["DRIVER"]["archive_list"],
        ))
    end
 
    writeLog("Program Ends.")

end

function getDriverConfigDescriptor()

    return [
            ConfigEntry(
                "casename",
                :required,
                [String,],
            ),

            ConfigEntry(
                "caseroot",
                :required,
                [String,],
            ),

            ConfigEntry(
                "caserun",
                :required,
                [String,],
            ),

            ConfigEntry(
                "archive_root",
                :required,
                [String,],
            ),

            ConfigEntry(
                "archive_list",
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
