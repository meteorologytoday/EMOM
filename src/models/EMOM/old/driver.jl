mutable struct SubOcean
    master_in_flds    :: InputFields
    master_ocn        :: Ocean
    worker_ocn        :: Ocean
    block_id          :: Integer

    pull_fr_rng      :: UnitRange
    push_fr_rng      :: UnitRange
    push_to_rng      :: UnitRange
    
    pull_fr_rng_bnd  :: AbstractArray{Union{UnitRange, Nothing}}
    pull_to_rng_bnd  :: AbstractArray{Union{UnitRange, Nothing}}
    push_fr_rng_bnd  :: AbstractArray{Union{UnitRange, Nothing}}
    push_to_rng_bnd  :: AbstractArray{Union{UnitRange, Nothing}}

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


    pull_fr_rngs = Array{Union{UnitRange, Nothing}}(undef, P)
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
    push_fr_rngs[1] = 1:length(push_fr_rngs[1])


    # Change range because to southmost boundary is trimmed
    if P > 1
        pull_to_rngs_bnd[1, 2] = pull_to_rngs_bnd[1, 2] .- L
        push_fr_rngs_bnd[1, 2] = push_fr_rngs_bnd[1, 2] .- L
    end

    return pull_fr_rngs, push_fr_rngs, push_to_rngs, pull_fr_rngs_bnd, pull_to_rngs_bnd, push_fr_rngs_bnd, push_to_rngs_bnd

end


function makeSubOcean(;
    master_ocn   :: Ocean,
    block_id     :: Integer,
    pull_fr_rng  :: UnitRange,
    push_fr_rng  :: UnitRange,
    push_to_rng  :: UnitRange,
    pull_fr_rng_bnd :: AbstractArray{Union{UnitRange, Nothing}},
    pull_to_rng_bnd :: AbstractArray{Union{UnitRange, Nothing}},
    push_fr_rng_bnd :: AbstractArray{Union{UnitRange, Nothing}},
    push_to_rng_bnd :: AbstractArray{Union{UnitRange, Nothing}},
 
#    nblocks      :: Integer,
)
#=
    overlap_grids = 2

    println(format("{:03d} Entering makeSubOcean.", block_id))

    touch_southpole = block_id == 1
    touch_northpole = block_id == nblocks

    sub_Ny_wo_ghost = ceil(Integer, master_ocn.Ny / nblocks)

    if block_id != nblocks
        sub_Ny = sub_Ny_wo_ghost
    else
        sub_Ny = master_ocn.Ny - (nblocks-1) * sub_Ny_wo_ghost
    end

    if sub_Ny <= 0
        throw(ErrorException("sub_Ny <= 0. Please check your resolution and nblocks"))            
    end

    pull_fr_beg_y = push_to_beg_y = sub_Ny_wo_ghost * (block_id - 1) + 1
    pull_fr_end_y = push_to_end_y = pull_fr_beg_y + sub_Ny - 1
    
    push_fr_beg_y = 1
    push_fr_end_y = sub_Ny

    if ! touch_southpole
        # expand south boundary
        pull_fr_beg_y -= 1
        sub_Ny += 1
    
        # fix push from range.
        # We want to skip the expanded latitude
        push_fr_beg_y += 1
        push_fr_end_y += 1
    end

    if ! touch_northpole
        # expand north boundary
        pull_fr_end_y += 1
        sub_Ny += 1
        
        # No need to fix push from range.
        # It is not affected.
    end

=#

    sub_Ny = length(pull_fr_rng)

    println("pull_fr_rng: ", pull_fr_rng)
    println("push_to_rng: ", push_to_rng)
    println("push_fr_rng: ", push_fr_rng)
    println("pull_fr_rng_bnd: ", pull_fr_rng_bnd)
    println("pull_to_rng_bnd: ", pull_to_rng_bnd)
    println("push_fr_rng_bnd: ", push_fr_rng_bnd)
    println("push_to_rng_bnd: ", push_to_rng_bnd)

    #=
    println("### rng3: ")
    println("pull_fr_rng3: ", pull_fr_rng3)
    println("push_to_rng3: ", push_to_rng3)
    println("push_fr_rng3: ", push_fr_rng3)
    =#

#=
    if length(pull_fr_rng2[2]) != sub_Ny
        throw(ErrorException("Pull from dimension does not match sub_Ny"))
    end

    if length(push_fr_rng2[2]) != length(push_to_rng2[2])
        throw(ErrorException("Push from and push to dimensions do not match."))
    end
=#

    return SubOcean(
        SubInputFields(master_ocn.in_flds, :, pull_fr_rng), 
        master_ocn,
        Ocean(
            id             = block_id,
            gridinfo_file  = master_ocn.gi_file,
            sub_yrng       = pull_fr_rng,
            Nx             = master_ocn.Nx,
            Ny             = sub_Ny,
            zs_bone        = master_ocn.zs_bone,
            Ts             = master_ocn.Ts[:, :, pull_fr_rng],
            Ss             = master_ocn.Ss[:, :, pull_fr_rng],
            K_v            = master_ocn.K_v,
            Dh_T           = master_ocn.Dh_T,
            Dv_T           = master_ocn.Dv_T,
            Dh_S           = master_ocn.Dh_S,
            Dv_S           = master_ocn.Dv_S,
            T_ML           = master_ocn.T_ML[:, pull_fr_rng],
            S_ML           = master_ocn.S_ML[:, pull_fr_rng],
            h_ML           = master_ocn.h_ML[:, pull_fr_rng],
            h_ML_min       = master_ocn.h_ML_min[:, pull_fr_rng],
            h_ML_max       = master_ocn.h_ML_max[:, pull_fr_rng],
            we_max         = master_ocn.we_max,
            R              = master_ocn.R,
            ζ              = master_ocn.ζ,
            Ts_clim_relax_time = master_ocn.Ts_clim_relax_time,
            Ss_clim_relax_time = master_ocn.Ss_clim_relax_time,
            Ts_clim        = ( master_ocn.Ts_clim != nothing ) ? master_ocn.Ts_clim[:, :, pull_fr_rng] : nothing,
            Ss_clim        = ( master_ocn.Ss_clim != nothing ) ? master_ocn.Ss_clim[:, :, pull_fr_rng] : nothing,
            topo           = master_ocn.topo[:, pull_fr_rng],
            fs             = master_ocn.fs[:, pull_fr_rng],
            ϵs             = master_ocn.ϵs[:, pull_fr_rng],
            in_flds        = InputFields(:local, master_ocn.Nx, sub_Ny),
            arrange        = :zxy,
        ),
        block_id,
        pull_fr_rng,
        push_fr_rng,
        push_to_rng,
        pull_fr_rng_bnd,
        pull_to_rng_bnd,
        push_fr_rng_bnd,
        push_to_rng_bnd,
    )

end

function syncToMaster!(subocn::SubOcean;
        vars2 :: Any,
        vars3 :: Any,
)

    (subocn.worker_ocn.id == 0) && throw(ErrorException("`id` should not be 0 (master)."))

    master_ocn = subocn.master_ocn
    worker_ocn = subocn.worker_ocn
   
    w_rng = subocn.push_fr_rng
    m_rng = subocn.push_to_rng
 
    for var in vars2
        getfield(master_ocn, var)[:, m_rng] = view(getfield(worker_ocn, var), :, w_rng)
    end

    for var in vars3
        getfield(master_ocn, var)[:, :, m_rng] = view(getfield(worker_ocn, var), :, :, w_rng)
    end

end

function syncFromMaster!(
        subocn::SubOcean;
        vars2 :: Any,
        vars3 :: Any,
)

    (subocn.worker_ocn.id == 0) && throw(ErrorException("`id` should not be 0 (master)."))

    master_ocn = subocn.master_ocn
    worker_ocn = subocn.worker_ocn
   
    m_rng = subocn.pull_fr_rng
    w_rng = Colon()
 
    for var in vars2
        getfield(worker_ocn, var)[:, w_rng] = view(getfield(master_ocn, var), :, m_rng)
    end

    for var in vars3
        getfield(worker_ocn, var)[:, :, w_rng] = view(getfield(master_ocn, var), :, :, m_rng)
    end

end

function syncForcingFromMaster!(
    subocn::SubOcean
)

    (subocn.worker_ocn.id == 0) && throw(ErrorException("`id` should not be 0 (master)."))

    master_ocn = subocn.master_ocn
    worker_ocn = subocn.worker_ocn
 
    copyfrom!(worker_ocn.in_flds, subocn.master_in_flds)
end



function syncBoundaryToMaster!(subocn::SubOcean;
        vars2 :: Tuple = (),
        vars3 :: Tuple = (),
)

    (subocn.worker_ocn.id == 0) && throw(ErrorException("`id` should not be 0 (master)."))

    master_ocn = subocn.master_ocn
    worker_ocn = subocn.worker_ocn
  
    w_rng = subocn.push_fr_rng_bnd
    m_rng = subocn.push_to_rng_bnd
 

    for r=1:2
        if m_rng[r] != nothing

            for var in vars2
                getfield(master_ocn, var)[:, m_rng[r]]    = view(getfield(worker_ocn, var), :, w_rng[r])
            end

            for var in vars3
                getfield(master_ocn, var)[:, :, m_rng[r]] = view(getfield(worker_ocn, var), :, :, w_rng[r])
            end

        end
    end
end

function syncBoundaryFromMaster!(subocn::SubOcean;
        vars2 :: Tuple = (),
        vars3 :: Tuple = (),
)

    (subocn.worker_ocn.id == 0) && throw(ErrorException("`id` should not be 0 (master)."))

    master_ocn = subocn.master_ocn
    worker_ocn = subocn.worker_ocn
  
    m_rng = subocn.pull_fr_rng_bnd
    w_rng = subocn.pull_to_rng_bnd
 
    for r=1:2
        if m_rng[r] != nothing

            for var in vars2
                getfield(worker_ocn, var)[:, w_rng[r]]    = view(getfield(master_ocn, var), :, m_rng[r])
            end

            for var in vars3
                getfield(worker_ocn, var)[:, :, w_rng[r]] = view(getfield(master_ocn, var), :, :, m_rng[r])
            end

        end
    end

end

function init(ocn::Ocean)

    global  wkrs  =  workers()
    nwkrs = length(wkrs) 

    println("Number of all workers: ", length(wkrs))

    (ocn.id == 0) || throw(ErrorException("`id` is not 0 (master). Id received: " * string(ocn.id)))


    # Assign `nothing` to prevent from sending large array of `View` objects.
    tmp_cols = ocn.cols
    tmp_lays = ocn.lays

    ocn.cols = nothing
    ocn.lays = nothing

    pull_fr_rngs, push_fr_rngs, push_to_rngs, pull_fr_rngs_bnd, pull_to_rngs_bnd, push_fr_rngs_bnd, push_to_rngs_bnd = calParallizationRange(N=ocn.Ny, P=nwkrs, L=2)

    @sync for (i, p) in enumerate(wkrs)
            # We have P processors, N workers, N blocks
            # Block ids are numbered from 1 to N
            @spawnat p let
                global subocn = makeSubOcean(
                    master_ocn  = ocn,
                    block_id    = i,
                    pull_fr_rng      = pull_fr_rngs[i],
                    push_fr_rng      = push_fr_rngs[i],
                    push_to_rng      = push_to_rngs[i],
                    pull_fr_rng_bnd  = pull_fr_rngs_bnd[i, :],
                    pull_to_rng_bnd  = pull_to_rngs_bnd[i, :],
                    push_fr_rng_bnd  = push_fr_rngs_bnd[i, :],
                    push_to_rng_bnd  = push_to_rngs_bnd[i, :],
                )
            end

    end

    # Restore `View` objects
    ocn.cols = ocn.cols
    ocn.lays = ocn.lays

end

function run!(
    ocn :: Ocean;
    Δt  :: Float64,
    substeps :: Integer,
    cfgs...
)

    (ocn.id == 0) || throw(ErrorException("`id` is not 0 (master). Id received: " * string(ocn.id)))

    dt = Δt / substeps

    cost_prep = @elapsed @sync for (i, p) in enumerate(wkrs)
        @spawnat p let
            syncForcingFromMaster!(subocn)
            cleanQflx2atm!(subocn.worker_ocn)
            stepOcean_prepare!(subocn.worker_ocn; cfgs...)
        end
    end


    sync_bnd_vars2 = (:T_ML, :S_ML, :h_ML, :FLDO)
    sync_bnd_vars3 = (:Ts,   :Ss)

    sync_to_master_vars2 = (:T_ML, :S_ML, :b_ML, :h_ML, :FLDO, :h_MO, :fric_u, :qflx2atm, :qflx2atm_pos, :qflx2atm_neg, :τx, :τy, :TSAS_clim, :SSAS_clim, :TFLUX_DIV_implied, :SFLUX_DIV_implied, :TEMP, :dTEMPdt, :SALT, :dSALTdt, :dTdt_ent, :dSdt_ent, :TFLUX_bot, :SFLUX_bot, :SFLUX_top, :seaice_nudge_energy)
    sync_to_master_vars3 = (:Ts, :Ss, :bs, :u, :v, :w_bnd, :TFLUX_CONV, :SFLUX_CONV, :TFLUX_DEN_z, :SFLUX_DEN_z, :div, :Ts_mixed, :Ss_mixed, :qflx_T_correction, :qflx_S_correction)

    #accumulative_vars2 = (:dTdt_ent, :dSdt_ent)
    #accumulative_vars3 = (:TFLUX_CONV, :T_vflux_ML, :SFLUX_CONV, :S_vflux_ML)

    cost_main = @elapsed for substep = 1:substeps
        #println("substep: ", substep)

        @sync for (i, p) in enumerate(wkrs)
            @spawnat p let
                syncBoundaryFromMaster!(subocn; vars3 = sync_bnd_vars3, vars2 = sync_bnd_vars2)
                calFLDOPartition!(subocn.worker_ocn)
                stepOcean_Flow!(subocn.worker_ocn; Δt = dt, cfgs...)
                stepOcean_MLDynamics!(subocn.worker_ocn; Δt = dt, cfgs...)
            end
        end
        
        @sync for (i, p) in enumerate(wkrs)
            @spawnat p let
                syncBoundaryToMaster!(subocn; vars3 = sync_bnd_vars3, vars2 = sync_bnd_vars2)
                accumulate!(subocn.worker_ocn)
            end
        end

    end
    
    cost_final = @elapsed @sync for (i, p) in enumerate(wkrs)
        @spawnat p let

            stepOcean_slowprocesses!(subocn.worker_ocn; Δt = Δt, cfgs...)

            if cfgs[:do_qflx_finding]
                calFlxCorrection!(subocn.worker_ocn; Δt = Δt, τ=10*86400.0, cfgs...)
            end

            if cfgs[:do_seaice_nudging]
                nudgeSeaice!(subocn.worker_ocn; Δt = Δt, τ=5*86400.0, cfgs...)
            end


            calLatentHeatReleaseOfFreezing!(subocn.worker_ocn; Δt=Δt, do_convadjust=cfgs[:do_convadjust])

            avg_accumulate!(subocn.worker_ocn; count=substeps)

            calDirect∂TEMP∂t!(subocn.worker_ocn; Δt=Δt)
            calDirect∂SALT∂t!(subocn.worker_ocn; Δt=Δt)
            calImplied∂TEMP∂t!(subocn.worker_ocn; cfgs...)
            calImplied∂SALT∂t!(subocn.worker_ocn; cfgs...)
  

            # Special: calculate Ts_mixed and Ss_mixed
            calTsSsMixed!(subocn.worker_ocn)
 
            syncToMaster!(
                subocn;
                vars2 = sync_to_master_vars2,
                vars3 = sync_to_master_vars3,
            )
        end
    end

    calDiagnostics!(ocn)

    println(format("### Cost: prep={:.1f}s , main={:.1f}s, final={:.1f}s. ###", cost_prep, cost_main, cost_final))

end

