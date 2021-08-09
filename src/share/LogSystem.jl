
module LogSystem

    using Formatting
    using MPI
    
    export writeLog
    
    function writeLog(args...; force :: Bool = false)
        
        comm = MPI.COMM_WORLD
        rank = MPI.Comm_rank(comm)

        if force || rank == 0
            println(format(args...))
        end
    end
end
