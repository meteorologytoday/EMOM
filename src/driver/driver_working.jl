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

if !(:Config in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "share", "Config.jl")))
end
using .Config

if !(:appendLine in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "share", "AppendLine.jl")))
end
    
include(normpath(joinpath(dirname(@__FILE__), "..", "configs", "driver_configs.jl")))

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
        config["DRIVER"] = validateConfigEntries(config["DRIVER"], getDriverConfigDescriptors()["DRIVER"])
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
    local Δt = nothing
 
    if is_master

        writeLog("Getting model start time.")
        read_restart, t_start, Δt = coupler_funcs.master_before_model_init()
        
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

        # By design, CESM ends the simulation of month m after the run of 
        # the first day of (m+1) month. For example, suppose the model 
        # run for Jan and Feb, the restart file will be written after stepping
        # March 1. This means, the read_restart phase is an already done step.
        # Therefore, after the read_restart phase, we need to advance the time.
        if read_restart
            writeLog("read_restart is true.")
            writeLog("Current time: {:s}", clock2str(clock))
            advanceClock!(clock, Δt)
            dropRungAlarm!(clock)
        end

    end

    # =======================================
    # IMPORTANT: need to sync time
    _time = MPI.bcast(clock.time, 0, comm) 
    if !is_master
        setClock!(clock, _time)
    end
    # =======================================
    
    writeLog("Ready to run the model.")
    while true

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

                # This advanced option is needed when deriving
                # qflux in direct method: Coupler needs to load
                # the initial data of each day and force master
                # to sync thermo variables with slaves. 
                if config["DRIVER"]["compute_QFLX_direct_method"]
                    OMMODULE.syncM2S!(OMDATA)
                end

                # Do the run and THEN advance the clock

                OMMODULE.run!(
                    OMDATA;
                    Δt = Δt,
                    write_restart = write_restart,
                )
                MPI.Barrier(comm)
                
            end

            writeLog("Computation cost: {:.2f} secs.", cost)

            if write_restart && is_master

                driver_restart_file = "model_restart.jld2"
                writeLog("Writing restart time of driver: $(driver_restart_file)")
                JLD2.save(driver_restart_file, "timestamp", clock.time)

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
                        driver_restart_file,
                        config["DRIVER"]["caserun"],
                        joinpath(config["DRIVER"]["archive_root"], "rest", timestamp_str)
                    )
                ) 

            end

            if is_master
                coupler_funcs.master_after_model_run!(OMMODULE, OMDATA)
            end
            
            if config["DRIVER"]["compute_QFLX_direct_method"]
                writeLog("compute_QFLX_direct_method is true")
                OMMODULE.syncM2S!(OMDATA)
            end


            # ==========================================
            if is_master
                # Advance the clock AFTER the run
                advanceClock!(clock, Δt)
                dropRungAlarm!(clock)
            end
           
            # Broadcast time to workers. Workers need time
            # because datastream needs time interpolation. 
            _time = MPI.bcast(clock.time, 0, comm) 
            if !is_master
                setClock!(clock, _time)
            end
            
            # ==========================================

        elseif stage == :END

            writeLog("Receive :END. Entering finalizing phase now.")
            break

        else
            
            throw(ErrorException("Unknown stage : " * string(stage)))

        end

    end
    
    if is_master
       
        OMMODULE.final(OMDATA)
        coupler_funcs.master_finalize!(OMMODULE, OMDATA)
        
        archive(joinpath(
            config["DRIVER"]["caserun"],
            config["DRIVER"]["archive_list"],
        ))

    end
 
    writeLog("Program Ends.")

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
