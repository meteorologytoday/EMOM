module CyclicData

    using Dates
    using NCDatasets
    using CFTime
    using Formatting

    export CyclicDataManager, interpData!, makeDataContainer

    function toSec(dt)
        return Dates.Millisecond(dt).value / 1000.0
    end

 
    mutable struct CyclicDataManager

        timetype  :: DataType

        var_file_map:: Dict

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

        t_l_arr      :: AbstractArray{Float64, 1}   
        t_r_arr      :: AbstractArray{Float64, 1}   

        # Time pointer. Indicating the last data read. If it is zero then no previous data is read
        t_ptr_l   :: Integer
        t_ptr_r   :: Integer

        sub_yrng  :: Union{Colon, UnitRange}

        data_l   :: Union{Dict, Nothing}     # Data on the lower point. Used for interpolation
        data_r   :: Union{Dict, Nothing}     # Data on the upper point. Used for interpolation


        function CyclicDataManager(;
            timetype         :: DataType,
            var_file_map :: Dict,
            beg_time         :: AbstractCFDateTime,
            end_time         :: AbstractCFDateTime,
            align_time       :: AbstractCFDateTime,
            sub_yrng         :: Union{UnitRange, Colon} = Colon(),
            varname_time     :: String = "time",
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

            period = toSec(end_time - beg_time)
            if period <= 0
                throw(ErrorException("End time cannot be earlier than beg time"))
            end

            local t_vec_raw

            local _compare_filename = nothing
            local _compare_t_vec = nothing
            local t_vec_raw

            for (varname, filename) in var_file_map

                Dataset(filename, "r") do ds
                    t_vec_raw = nomissing(ds[varname_time][:])
                    t_attrib = ds[varname_time].attrib
                    
                    if typeof(t_vec_raw[1]) != timetype
                        throw(ErrorException("User specifies time type of $(string(timetype)), but data file has time type of $(string(typeof(t_vec_raw[1])))."))
                    end

                    if ! haskey(ds, varname)
                        throw(ErrorException("File $(filename) does not have variable $(varname)."))
                    end

                    if _compare_t_vec == nothing
                        _compare_filename = "$(filename)"
                        _compare_t_vec = copy(t_vec_raw)
                    end
                    
                    if length(t_vec_raw) != length(_compare_t_vec)
                        throw(ErrorException("File $(filename) does not agree with other time dimension length in $(_compare_filename)."))
                    end

                    for i=1:length(t_vec_raw)
                        if t_vec_raw[i] != _compare_t_vec[i]
                            throw(ErrorException("`time` variable in file $(filename) is not the same as $(_compare_filename) at index $(i)"))
                        end
                    end
                end                
            
            end

            if any(t_vec_raw[2:end] .<= t_vec_raw[1:end-1])
                throw(ErrorException("Time dimension has to be monotonically increasing."))
            end

            # Search for time_idx_beg and time_idx_end
            
            test = ( beg_time .<= t_vec_raw .<= end_time)
            time_idx_beg = findfirst(test)
            time_idx_end = findlast(test)

            #println("$(time_idx_beg) : $(time_idx_end)")

            if time_idx_end == nothing || time_idx_beg == nothing
                println(beg_time)
                println(end_time)
                println(t_vec_raw)
                throw(ErrorException("Time range is wrong that no time is within scope."))
            end

#            println("($(time_idx_beg), $time_idx_end)")




            t_vec = [ 
                mod(toSec(t_vec_raw[i] - beg_time), period) for i=time_idx_beg:time_idx_end
            ]

            if t_vec[1] == t_vec[end]
                throw(ErrorException("The first and last data of the obtained time series overlap. Please check."))
            end
            

#            for i in 1:length(t_vec)
#                println("$(t_vec_raw[i]) - $(align_time) = $(t_vec_raw[i] - align_time)")
#                println("t_vec[$(i)] = $(t_vec[i]/86400)")
#            end
#            println("Period = $(period / 86400)")


            #
            # - General idea of interpolation
            # 
            # phantom 
            #     1       2        3                N        N+1      N+2 
            #     0 --- t[1] --- t[2] --- ... --- t[N-1] --- t[N] --- p(=0) --- t[1]   (time)
            #           d[1]     d[2]             d[N-1]     d[N]               d[1]   (data)
            # box    1        2       3       N-1        N        N+1
            # idx_l  N        1       2       N-2       N-1        N
            # idx_r  1        2       3       N-1        N         1
            #
            # t_l   t[N]-p   t[1]    t[2]                        t[N]
            # t_r   t[1]     t[2]    t[3]                        t[1]+p

            N = length(t_vec)

            phantom_t_vec = zeros(Float64, N+2)
            phantom_t_vec[1]       = 0.0
            phantom_t_vec[2:end-1] = t_vec
            phantom_t_vec[end]     = period

#            for (i, phantom_t) in enumerate(phantom_t_vec)
#                println("[$(i)] = $(phantom_t/86400)")
#            end

            # idx_r_arr[i] stores the index of right-point of box i
            idx_r_arr = collect(1:N+1)
            idx_r_arr[end] = 1
 
            # idx_l_arr[i] stores the index of left-point of box i
            idx_l_arr = circshift(idx_r_arr, (1, ))
            idx_l_arr[1] = N

            # Important: Need to offset the idx because we select the data
            # range according to beg_time and end_time
            idx_r_arr .+= time_idx_beg - 1
            idx_l_arr .+= time_idx_beg - 1


            # t_l_arr[i] stores the time used for left-point of box i
            t_l_arr = zeros(Float64, N+1)
            t_l_arr[1] = t_vec[end] - period
            t_l_arr[2:end] = t_vec
            
            # t_r_arr[i] stores the time used for right-point of box i
            t_r_arr = zeros(Float64, N+1)
            t_r_arr[1:end-1] = t_vec
            t_r_arr[end] = t_vec[1] + period

            obj = new(
                timetype,
                var_file_map,
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
                t_l_arr,
                t_r_arr,
                0,
                0,
                sub_yrng,
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
#            println(format("t_c={}, left={}, right={} ", t_c,  cdm.phantom_t_vec[i], cdm.phantom_t_vec[i+1]))

            if cdm.phantom_t_vec[i] <= t_c <= cdm.phantom_t_vec[i+1]
                idx_l = cdm.idx_l_arr[i]
                idx_r = cdm.idx_r_arr[i]
                t_l = cdm.t_l_arr[i]
                t_r = cdm.t_r_arr[i]
            
#                println(format("Found $(i): t_c={}, left={}, right={} ", t_c,  t_l, t_r))
                break
            end
        end

        return idx_l, idx_r, t_l, t_c, t_r 

    end

    function makeDataContainer(
        cdm      :: CyclicDataManager,
    )

        local data = Dict()

        for (varname, filename) in cdm.var_file_map
            Dataset(filename, "r") do ds

                s = size(ds[varname])

                Ny = s[2]

                if cdm.sub_yrng != Colon()
                    Ny = length(cdm.sub_yrng)
                end

                if length(s) == 4  # 3D case
                    data[varname] = zeros(Float64, s[3], s[1], Ny)
                elseif length(s) == 3  # 2D case
                    data[varname] = zeros(Float64, 1, s[1], Ny)
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

        missing_data = 0.0

        for (varname, filename) in cdm.var_file_map
            Dataset(filename, "r") do ds
                var = ds[varname]
                s = size(var)

                if length(s) == 4  # 3D case
                        
                    data[varname][:, :, :] = permutedims(nomissing(ds[varname][:, cdm.sub_yrng, :, t_idx], missing_data), [3,1,2]) 
                elseif length(s) == 3  # 2D case
                    #println(varname, "; cdm.sub_yrng: ", cdm.sub_yrng)
                    #println("size of data container: ", size(data[varname]))
                    #println("size of ds : ", size(ds[varname][:, cdm.sub_yrng, t_idx]))
                    _tmp = nomissing(ds[varname][:, cdm.sub_yrng, t_idx], missing_data)
                    data[varname][:, :, :] = reshape(_tmp, 1, size(_tmp)...)
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

        for varname in keys(cdm.var_file_map)
    
            tmp = view(data[varname], :)

            # interpolation happens here
            data_l = view(cdm.data_l[varname], :)
            data_r = view(cdm.data_r[varname], :)
            @. tmp = data_l * coe_l + data_r * coe_r

        end
    end 
end
