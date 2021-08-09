module CyclicData

    using Dates
    using NCDatasets
    using CFTime
    using Formatting

    export CyclicDataManager, interpData!, makeDataContainer
 
    mutable struct CyclicDataManager

        timetype  :: DataType

        filename  :: String

        beg_time    :: AbstractCFDateTime
        end_time    :: AbstractCFDateTime
        align_time  :: AbstractCFDateTime
        period      :: Float64  # end_time - beg_time in seconds
        # The first and last index with in beg_time and end_time
        time_idx_beg   :: Integer
        time_idx_end   :: Integer

        t_vec_raw       :: AbstractArray{AbstractCFDateTime, 1}  # Contains the untrimmed time vector from input file
        t_vec           :: AbstractArray{Float64, 1}  # Actual time axis in seconds, has length
                                                      # (time_idx_end - time_idx_beg + 1).

        # Same as t_vec but appended 0 and period at
        # the beginning and end for interpolating usage.
        phantom_t_vec  :: AbstractArray{Float64, 1}
       
        # Precomputed arrays for time bound detection
        # - If t lies within [0, t_vec[1]] then interpolation
        #   will use data of idx_l_arr[1] and idx_r_arr[2].
        # - If t lies within [t_vec[i], t_vec[i+1]] then interpolation
        #   will use data of idx_l_arr[i+1] and idx_r_arr[i+1].
        # - If t lies within [t_vec[N], period] then interpolation
        #   will use data of idx_l_arr[N+1] and idx_r_arr[N+1]
        #   where N=length(t_vec)
        # 
        # I use phantom_t_vec to simplify the algorithm above
        # - If t lies within [phantom_t_vec[i], phantom_t_vec[i+1]]
        #   then use data of idx_l_arr[i] and idx_r_arr[i] for interpolation.
        idx_l_arr      :: AbstractArray{Integer, 1}   
        idx_r_arr      :: AbstractArray{Integer, 1}   

        # Time pointer. Indicating the last data read. If it is zero then no previous data is read
        t_ptr_l   :: Integer
        t_ptr_r   :: Integer

        sub_yrng  :: Union{Colon, UnitRange}
        varnames  :: Array{String, 1}

        data_l   :: Union{Dict, Nothing}     # Data on the lower point. Used for interpolation
        data_r   :: Union{Dict, Nothing}     # Data on the upper point. Used for interpolation


        function CyclicDataManager(;
            timetype        :: DataType,
            filename        :: String,
            varnames        :: Array,
            beg_time        :: AbstractCFDateTime,
            end_time        :: AbstractCFDateTime,
            align_time      :: AbstractCFDateTime,
            sub_yrng        :: Union{UnitRange, Colon} = Colon(),
            varname_time    :: String = "time",
        )

            data = Dict()
            t_vec = nothing

            if typeof(beg_time) != timetype
                throw(ErrorException("User specifies time type of {:s}, but beg_time has time type of {:s}", string(timetype), string(typeof(beg_time))))
            end

            if typeof(end_time) != timetype
                throw(ErrorException("User specifies time type of {:s}, but end_time has time type of {:s}", string(timetype), string(typeof(end_time))))
            end

            if typeof(align_time) != timetype
                throw(ErrorException("User specifies time type of {:s}, but align_time has time type of {:s}", string(timetype), string(typeof(align_time))))
            end

            period = Dates.Second(end_time - beg_time).value

            if period <= 0
                throw(ErrorException("End time cannot be earlier than beg time"))
            end

            local t_vec_raw
            Dataset(filename, "r") do ds
                    
                t_vec_raw = nomissing(ds[varname_time][:])
                t_attrib = ds[varname_time].attrib
                
                if typeof(t_vec_raw[1]) != timetype
                    throw(ErrorException("User specifies time type of {:s}, but data file has time type of {:s}", string(timetype), string(typeof(t_vec_raw[1]))))
                end

                #t_vec = [ timeencode(t_vec[i], t_attrib["units"], t_attrib["calendar"]) for i = 1:length(t_vec) ]
                #t_vec = [ timeencode(t_vec[i], "seconds since 0001-01-01 00:00:00", timetype) for i = 1:length(t_vec) ]
                
            end

            if any(t_vec_raw[2:end] .<= t_vec_raw[1:end-1])
                throw(ErrorException("Time dimension has to be monotonically increasing."))
            end

            # Search for time_idx_beg and time_idx_end
            
            test = ( beg_time .<= t_vec_raw .<= end_time)
            time_idx_beg = findfirst(test)
            time_idx_end = findlast(test)

            if time_idx_end == nothing || time_idx_beg == nothing
                #println(beg_time)
                #println(end_time)
                #println(t_vec_raw)
                throw(ErrorException("Time range is wrong that no time is within scope."))
            end

            unit_fmt = format(
                "seconds since {:s}",
                Dates.format(align_time, "yyyy-mm-dd HH:MM:SS")
            )
            #=
                "seconds since {:04d}-{:02d}-{:02d} {:02d}:{:02d}:{:02d}",
                year(align_time),
                month(align_time),
                day(align_time),
                hour(align_time),
                minute(align_time),
                second(align_time),
            )
            =#
            #println(timeencode(t_vec_raw[1], unit_fmt, timetype))

            t_vec = [ timeencode(t_vec_raw[i], unit_fmt, timetype) for i=time_idx_beg:time_idx_end ]

            phantom_t_vec = zeros(Float64, length(t_vec)+2)
            phantom_t_vec[1]       = 0.0
            phantom_t_vec[2:end-1] = t_vec
            phantom_t_vec[end]     = period

            idx_r_arr = collect(1:length(phantom_t_vec)-1)
            idx_l_arr = circshift(collect(1:length(phantom_t_vec)-1), (1,))

            idx_r_arr[end] = 1
            idx_l_arr[1]   = length(idx_l_arr) - 1
            

            obj = new(
                timetype,
                filename,
                beg_time,
                end_time,
                align_time,
                period,
                time_idx_beg,
                time_idx_end,
                t_vec_raw,
                t_vec,
                phantom_t_vec,
                idx_l_arr,
                idx_r_arr,
                0,
                0,
                sub_yrng,
                varnames,
                nothing,
                nothing,
            )

            obj.data_l = makeDataContainer(obj)
            obj.data_r = makeDataContainer(obj)

            return obj
        end
        
    end


    function detectTimeBoundary(
        cdm :: CyclicDataManager,
        t   :: AbstractCFDateTime,
    )

        # lcr = left, center, right
        # Determine interpolation position
        local t_l, t_r, t_c, idx_l, idx_r

        t_c = mod( Second(t - cdm.align_time).value, cdm.period)
        for i = 1:length(cdm.phantom_t_vec)-1
            #println(format("t_c={}, left={}, right={} ", t_c,  cdm.phantom_t_vec[i], cdm.phantom_t_vec[i+1]))

            if cdm.phantom_t_vec[i] <= t_c <= cdm.phantom_t_vec[i+1]
                idx_l = cdm.idx_l_arr[i]
                idx_r = cdm.idx_r_arr[i]
                t_l = cdm.t_vec[idx_l]
                t_r = cdm.t_vec[idx_r]
           
                if i == 1
                    t_l -= cdm.period
                elseif i == length(cdm.phantom_t_vec)-1
                    t_r += cdm.period 
                end 

                break
            end
        end

        return idx_l, idx_r, t_l, t_c, t_r 

    end

    function makeDataContainer(
        cdm      :: CyclicDataManager,
    )

        local data = Dict()

        Dataset(cdm.filename, "r") do ds

            for varname in cdm.varnames
                s = size(ds[varname])

                #println(s)

                if length(s) == 4  # 3D case
                    data[varname] = zeros(Float64, s[3], s[1], length(cdm.sub_yrng))
                elseif length(s) == 3  # 2D case
                    data[varname] = zeros(Float64, 1, s[1], length(cdm.sub_yrng))
                else
                    throw(ErrorException("Unknown dimension: " * string(s)))
                end

            end

        end
        
        return data
    end


    function loadData!(
        cdm      :: CyclicDataManager,
        t_idx    :: Int64,
        data     :: Dict 
    )

        Dataset(cdm.filename, "r") do ds

            for varname in cdm.varnames
                var = ds[varname]
                s = size(var)

                if length(s) == 4  # 3D case
                    data[varname][:, :, :] = permutedims(nomissing(ds[varname][:, cdm.sub_yrng, :, t_idx], NaN), [3,1,2]) 
                elseif length(s) == 3  # 2D case
                    #println(varname, "; cdm.sub_yrng: ", cdm.sub_yrng)
                    #println("size: ", size(ds[varname][cdm.sub_yrng, :, t_idx]))
                    data[varname][:, :, :] = reshape(nomissing(ds[varname][:, cdm.sub_yrng, t_idx], NaN), 1, s[1:2]...)
                else
                    throw(ErrorException("Unknown dimension: " * string(s)))
                end

            end

        end
        
    end


    function interpData!(
        cdm      :: CyclicDataManager,
        t        :: AbstractCFDateTime,
        data     :: Dict;
        create   :: Bool = false,
    )

        idx_l, idx_r, t_l, t_c, t_r = detectTimeBoundary(cdm, t)

        #println(format("{:d}, {:d}, {:.1f}", idx_l, idx_r, t_c))

        if cdm.t_ptr_l == 0 && cdm.t_ptr_r == 0 # Initialization

            # load idx_l into data_l
            # load idx_r into data_r

            cdm.t_ptr_l, cdm.t_ptr_r = idx_l, idx_r

            loadData!(cdm, cdm.t_ptr_l, cdm.data_l)
            loadData!(cdm, cdm.t_ptr_r, cdm.data_r)

        elseif cdm.t_ptr_r == idx_l

            # move data_r to data_l
            cdm.t_ptr_l, cdm.t_ptr_r = cdm.t_ptr_r, idx_r
            
            # swap data_l and data_r 
            cdm.data_l, cdm.data_r = cdm.data_r, cdm.data_l
    
            # load idx_r into data_r
            loadData!(cdm, cdm.t_ptr_r, cdm.data_r)

        elseif cdm.t_ptr_l == idx_l && cdm.t_ptr_r == idx_r

            # do nothing. 

        else
            throw(ErrorException(format("Unknown situation. cdm.t_ptr_l = {:d}, cdm.t_ptr_r = {:d}", cdm.t_ptr_l, cdm.t_ptr_r)))
        end


        Δt_lr = t_r - t_l
        Δt_lc = t_c - t_l 
        Δt_cr = t_r - t_c

        coe_r = Δt_lc / Δt_lr
        coe_l = Δt_cr / Δt_lr
 
        if any([Δt_lr, Δt_lc, Δt_cr] .< 0)
            println("[Δt_lr, Δt_lc, Δt_cr] = ", [Δt_lr, Δt_lc, Δt_cr]) 
            throw(ErrorException("Δt sign error."))
        end

        for varname in cdm.varnames
    
            tmp = view(data[varname], :)

            # interpolation happens here
            data_l = view(cdm.data_l[varname], :)
            data_r = view(cdm.data_r[varname], :)
            @. tmp = data_l * coe_l + data_r * coe_r

        end
    end 
end
