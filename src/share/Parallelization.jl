module Parallization

    using ..DataManager
    using MPI
    using Formatting
  
    export JobDistributionInfo, getYsplitInfoByRank, syncField!
    export printJobDistributionInfo


    mutable struct YSplitInfo
        pull_fr_rng      :: UnitRange
        pull_to_rng      :: UnitRange
        push_fr_rng      :: UnitRange
        push_to_rng      :: UnitRange
        
        pull_fr_rng_bnd  :: AbstractArray{Union{UnitRange, Nothing}}
        pull_to_rng_bnd  :: AbstractArray{Union{UnitRange, Nothing}}
        push_fr_rng_bnd  :: AbstractArray{Union{UnitRange, Nothing}}
        push_to_rng_bnd  :: AbstractArray{Union{UnitRange, Nothing}}
    end

    mutable struct JobDistributionInfo

        overlap       :: Int64
        nworkers      :: Int64
        wranks        :: Array{Int64, 1} # worker ranks
        wrank_to_idx  :: Dict{Int64, Int64}
        y_split_infos :: AbstractArray{YSplitInfo, 1}

        function JobDistributionInfo(;
            nworkers :: Int64,
            Ny       :: Int64,
            overlap  :: Int64 = 3,
        )
            if nworkers == 0
                throw(ErrorException("No available workers!"))
            end

            wranks = collect(1:nworkers)

            (
                pull_fr_rngs,
                pull_to_rngs,
                push_fr_rngs,
                push_to_rngs,
                pull_fr_rngs_bnd,
                pull_to_rngs_bnd,
                push_fr_rngs_bnd,
                push_to_rngs_bnd 

            ) = calParallizationRange(N=Ny, P=nworkers, L=overlap)
      
            wrank_to_idx = Dict() 
            for i = 1:nworkers
                wrank_to_idx[i] = i
            end

 
            y_split_infos = Array{YSplitInfo}(undef, nworkers)

            for (i, p) in enumerate(wranks)

                y_split_infos[i] = YSplitInfo(
                    pull_fr_rngs[i],
                    pull_to_rngs[i],
                    push_fr_rngs[i],
                    push_to_rngs[i],
                    pull_fr_rngs_bnd[i, :],
                    pull_to_rngs_bnd[i, :],
                    push_fr_rngs_bnd[i, :],
                    push_to_rngs_bnd[i, :],
                )

            end
          
            return new(
                overlap,
                nworkers,
                wranks,
                wrank_to_idx,
                y_split_infos,
            ) 

        end

    end

    function calParallizationRange(;
        N = Integer,     # Total grids
        P = Integer,     # Number of procs
        L = Integer,     # Overlapping grids
    )

        if ! (N >= max(1, L) * P)
            throw(ErrorException("Condition must be satisfied: N >= max(1, L) * P"))
        end

        n̄ = floor(Integer, N / P)
        R = N - n̄ * P

        # "Here" is slave, "there" is master.
        # So "pull" means receiving data from master.
        # and "push" means sending data to master.

        pull_fr_rngs = Array{Union{UnitRange, Nothing}}(undef, P)
        pull_to_rngs = Array{Union{UnitRange, Nothing}}(undef, P)
        push_fr_rngs = Array{Union{UnitRange, Nothing}}(undef, P)
        push_to_rngs = Array{Union{UnitRange, Nothing}}(undef, P)
        
        # 1: lower latitude side (south), 2: higher latitude side (north)
        pull_fr_rngs_bnd = Array{Union{UnitRange, Nothing}}(undef, P, 2)
        pull_to_rngs_bnd = Array{Union{UnitRange, Nothing}}(undef, P, 2)
        push_fr_rngs_bnd = Array{Union{UnitRange, Nothing}}(undef, P, 2)
        push_to_rngs_bnd = Array{Union{UnitRange, Nothing}}(undef, P, 2)



        cnt = 1
        for p = 1:P
            m = (p <= R) ? n̄ + 1 : n̄  # assigned grids

            pull_fr_rngs[p] = cnt-L:cnt+m-1+L
            pull_to_rngs[p] = 1:length(pull_fr_rngs[p])
            push_fr_rngs[p] = L+1:L+m
            push_to_rngs[p] = cnt:cnt+m-1


            # Boundary
            pull_fr_rngs_bnd[p, 1] = cnt-L:cnt-1
            pull_fr_rngs_bnd[p, 2] = cnt+m:cnt+m+L-1

            pull_to_rngs_bnd[p, 1] = 1:L
            pull_to_rngs_bnd[p, 2] = L+m+1:L+m+L

            push_fr_rngs_bnd[p, 1] = L+1:L+L
            push_fr_rngs_bnd[p, 2] = L+m-L+1:L+m

            push_to_rngs_bnd[p, 1] = cnt:cnt+L-1
            push_to_rngs_bnd[p, 2] = cnt+m-L:cnt+m-1

            cnt += m
        end

        # South pole and north pole do not have boundaries
        pull_fr_rngs_bnd[1, 1] = nothing
        pull_to_rngs_bnd[1, 1] = nothing
        push_fr_rngs_bnd[1, 1] = nothing
        push_to_rngs_bnd[1, 1] = nothing

        pull_fr_rngs_bnd[end, 2] = nothing
        pull_to_rngs_bnd[end, 2] = nothing
        push_fr_rngs_bnd[end, 2] = nothing
        push_to_rngs_bnd[end, 2] = nothing

        # Adjust the first and last range (south pole and north pole)
        pull_fr_rngs[1] = (pull_fr_rngs[1][1]+L):pull_fr_rngs[1][end]
        pull_fr_rngs[end] = pull_fr_rngs[end][1]:(pull_fr_rngs[end][end]-L)

        pull_to_rngs[1] = 1:length(pull_fr_rngs[1])
        pull_to_rngs[end] = 1:length(pull_fr_rngs[end])
 
        push_fr_rngs[1] = 1:length(push_fr_rngs[1])


        # Change range because to southmost boundary is trimmed
        if P > 1
            pull_to_rngs_bnd[1, 2] = pull_to_rngs_bnd[1, 2] .- L
            push_fr_rngs_bnd[1, 2] = push_fr_rngs_bnd[1, 2] .- L
        end

        return pull_fr_rngs,
               pull_to_rngs,
               push_fr_rngs,
               push_to_rngs,
               pull_fr_rngs_bnd,
               pull_to_rngs_bnd,
               push_fr_rngs_bnd,
               push_to_rngs_bnd

    end

    function getYsplitInfoByRank(
        jdi :: JobDistributionInfo,
        rank :: Integer,
    )
        return jdi.y_split_infos[jdi.wrank_to_idx[rank]]
    end


    mutable struct SyncInfo
        vars         :: AbstractArray{DataUnit, 1}
        y_split_info :: AbstractArray{DataUnit, 1}
    end

    function syncField!(
        vars         :: AbstractArray{DataUnit},
        jdi          :: JobDistributionInfo,
        direction    :: Symbol,
        sync_type    :: Symbol,
    )

        comm = MPI.COMM_WORLD
        rank = MPI.Comm_rank(comm)

        is_master = (rank == 0)
        
        reqs = Array{MPI.Request}(undef,0)

        if direction == :S2M  # Slave to master
            if sync_type == :BLOCK
                if is_master
                    for (i, _rank) in enumerate(jdi.wranks)
                        for (j, var) in enumerate(vars)
                            v = view(var.data, :, :, getYsplitInfoByRank(jdi, _rank).push_to_rng) 
                            push!(reqs, MPI.Irecv!(v, i, j, comm))
                        end
                    end
                else
                    for (j, var) in enumerate(vars)
                        v = view(var.data, :, :, getYsplitInfoByRank(jdi, rank).push_fr_rng) 
                        push!(reqs, MPI.Isend(v, 0, j, comm))
                    end
                end
            end

            if sync_type == :BND
                if is_master
                    for (i, _rank) in enumerate(jdi.wranks)
                        for (k, push_to_rng_bnd) in enumerate(getYsplitInfoByRank(jdi, _rank).push_to_rng_bnd)
                            (push_to_rng_bnd == nothing) && continue
                            for (j, var) in enumerate(vars)
                                v = view(var.data, :, :, push_to_rng_bnd) 
                                push!(reqs, MPI.Irecv!(v, i, k*length(vars) + j, comm))
                            end
                        end
                    end
                else
                    for (k, push_fr_rng_bnd) in enumerate(getYsplitInfoByRank(jdi, rank).push_fr_rng_bnd)
                        (push_fr_rng_bnd == nothing) && continue
                        for (j, var) in enumerate(vars)
                            v = view(var.data, :, :, push_fr_rng_bnd) 
                            push!(reqs, MPI.Isend(v, 0, k*length(vars) + j, comm))
                        end
                    end
                end
            end


        elseif direction == :M2S  # Master to slave

            if sync_type == :BLOCK
                if is_master
                    for (i, _rank) in enumerate(jdi.wranks)
                        for (j, var) in enumerate(vars)
                            v = view(var.data, :, :, getYsplitInfoByRank(jdi, _rank).pull_fr_rng) 
                            push!(reqs, MPI.Isend(v, i, j, comm))
                        end
                    end
                else
                    for (j, var) in enumerate(vars)
                        v = view(var.data, :, :, getYsplitInfoByRank(jdi, rank).pull_to_rng) 
                        push!(reqs, MPI.Irecv!(v, 0, j, comm))
                    end
                end
            end

            if sync_type == :BND
                if is_master
                    for (i, _rank) in enumerate(jdi.wranks)
                        for (k, pull_fr_rng_bnd) in enumerate(getYsplitInfoByRank(jdi, _rank).pull_fr_rng_bnd)
                            (pull_fr_rng_bnd == nothing) && continue
                            for (j, var) in enumerate(vars)
                                v = view(var.data, :, :, pull_fr_rng_bnd) 
                                push!(reqs, MPI.Isend(v, i, k * length(vars) + j, comm))
                            end
                        end
                    end
                else
                    for (k, pull_to_rng_bnd) in enumerate(getYsplitInfoByRank(jdi, rank).pull_to_rng_bnd)
                        (pull_to_rng_bnd == nothing) && continue
                        for (j, var) in enumerate(vars)
                            v = view(var.data, :, :, pull_to_rng_bnd) 
                            push!(reqs, MPI.Irecv!(v, 0, k*length(vars) + j, comm))
                        end
                    end
                end
            end
        end

        MPI.Waitall!(reqs)
      
        MPI.Barrier(comm) 
        #= 
        if direction == :M2S && rank==1
            for (_, var) in enumerate(vars)
                if var.id == "TEMP"
                    println("detect TEMP.")
                    if var.sdata1[1, 1, end] == 0
                        println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                    end
                end
            end
        end  # Master to slave
        =#
    end

    function printJobDistributionInfo(jdi :: JobDistributionInfo)
        println(format("overlap  = {:d}", jdi.overlap))
        println(format("nworkers = {:d}", jdi.nworkers))
        println(format("wranks   = {:s}", string(jdi.wranks)))
        println(format("wrank_to_idx = {:s}", string(jdi.wrank_to_idx)))

        for (i, y_split_info) in enumerate(jdi.y_split_infos)
            println(format("[{:d}] pull_fr_rng = {:s}", i, string(y_split_info.pull_fr_rng)))
            println(format("[{:d}] pull_to_rng = {:s}", i, string(y_split_info.pull_to_rng)))
            println(format("[{:d}] push_fr_rng = {:s}", i, string(y_split_info.push_fr_rng)))
            println(format("[{:d}] push_to_rng = {:s}", i, string(y_split_info.push_to_rng)))

            for j = 1:length(y_split_info.pull_fr_rng_bnd)
                println(format("[{:d}] pull_fr_rng_bnd[{:d}] = {:s}", i, j, string(y_split_info.pull_fr_rng_bnd[j])))
                println(format("[{:d}] pull_to_rng_bnd[{:d}] = {:s}", i, j, string(y_split_info.pull_to_rng_bnd[j])))
                println(format("[{:d}] push_fr_rng_bnd[{:d}] = {:s}", i, j, string(y_split_info.push_fr_rng_bnd[j])))
                println(format("[{:d}] push_to_rng_bnd[{:d}] = {:s}", i, j, string(y_split_info.push_to_rng_bnd[j])))
            end
        end
    end
 
end
