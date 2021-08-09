module PeriodicDataToolbox
    using NCDatasets
    using SparseArrays
    mutable struct Bundle
        interpolate_mtx :: AbstractArray{Float64, 2}

        fine_time       :: AbstractArray{Float64, 1}
        coarse_time     :: AbstractArray{Float64, 1}
        
        var_names       :: AbstractArray

        fine_data       :: Dict
        coarse_data     :: Dict
    end


    function readCoarseNCFile(filename, varnames, fine_time, )
        ds = Dataset(filename, "r")

        coarse_data = Dict()
        fine_data   = Dict()
 
        for varname in varnames
            coarse_data[varname] = nomissing(ds[varname][:], NaN)
            coarse_data[varname] 
        end

        
        close(ds)
    end


    function interpolate!(
        fine_data       :: AbstractArray{Float64, 1},
        coarse_data     :: AbstractArray{Float64, 1},
        interpolate_mtx :: AbstractArray{Float64, 2},
    )

        for i = 1:length(fine_data)
            fine_data[i] = interpolate_mtx[i, 1] * coarse_data[1]
            for j = 2:length(coarse_data)
                fine_data[i] += interpolate_mtx[i, j] * coarse_data[j]
            end
        end

    end

    function genInterpolateMatrix(
        time1 :: AbstractArray{Float64, 1},  # coarse
        time2 :: AbstractArray{Float64, 1},  # fine
        period :: Float64,
    )

        N_ext = length(time1)+2
        time1_ext = zeros(Float64, N_ext)

        time1_ext[1]       = time1[end] - period

        if length(time1) > 1
            time1_ext[2:end-1] = time1[1:end]
        end

        time1_ext[end]     = time1[1] + period

        mtx = spzeros(Float64, length(time2), length(time1))
       
        if length(time1) == 1
            mtx .= 1.0
            return mtx
        end
        
        # The algorithm below assume length(time1) > 1
        i_2 = 1
        done = false
        for i = 1:N_ext-1

            ta = time1_ext[i]
            tb = time1_ext[i+1]
            while ta <= time2[i_2] && time2[i_2] < tb
                Δt = tb - ta
                ia = (i   ==     1  ) ? length(time1) : i-1
                ib = (i   == N_ext-1) ? 1             : i
                
                mtx[i_2, ia] = (tb - time2[i_2]) / Δt
                mtx[i_2, ib] = (time2[i_2] - ta) / Δt

                #println(tb - time2[i_2], "; ", time2[i_2] - ta, "; ", Δt, "; ", ia, " , ", ib)

                if i_2 < length(time2)
                    i_2 += 1
                else
                    done = true
                    break
                end
            end
        
            if done
                break
            end
        end

        if !done 
            throw(ErrorException("Not all element of time2 is within [0, period]"))
        end

        return mtx

    end


end

