using Distributed

@everywhere module CoordTrans

    using NCDatasets
    using SharedArrays
    using Formatting
    using Distributed

    mutable struct WeightInfo

        NNN_max    :: Int64

        s_N        :: Int64
        d_N        :: Int64

        NN_idx     :: AbstractArray{Int64, 2}
        s_gc_lat   :: AbstractArray{Float64, 1}
        s_gc_lon   :: AbstractArray{Float64, 1}
        d_gc_lat   :: AbstractArray{Float64, 1}
        d_gc_lon   :: AbstractArray{Float64, 1}

        s_dims     :: AbstractArray{Int64, 1}
        d_dims     :: AbstractArray{Int64, 1}
        
        s_wgt      :: AbstractArray{Float64, 1}

    end


    mutable struct GridInfo
        
        N      :: Int64

        gc_lon :: AbstractArray{Float64}
        gc_lat :: AbstractArray{Float64}

        area   :: AbstractArray{Float64}
        mask   :: AbstractArray{Float64}

        unit_of_angle :: Symbol

        dims   :: AbstractArray{Int64} 

        function GridInfo(;
            gc_lon :: AbstractArray{Float64,1},
            gc_lat :: AbstractArray{Float64,1},
            area   :: AbstractArray{Float64,1},
            mask   :: AbstractArray{Float64,1},
            unit_of_angle :: Symbol,
            dims   = nothing,
        ) 

            N = length(gc_lon)

            for var in [gc_lat, area, mask]
                if length(var) != N
                    throw(ErrorException("Not all input has the same length."))
                end
            end

            if unit_of_angle == :deg

                gc_lon .*= π / 180.0
                gc_lat .*= π / 180.0

            elseif unit_of_angle == :rad
                # do nothing

            else
                throw(ErrorException("`unit_of_angle` must be `:deg` or `:rad`."))
            end

            if dims == nothing
                dims = (N,)
            end

            dims = convert(Array{Int64}, dims)

            if reduce(*, dims) != N
                throw(ErrorException("Dims does not match the number of elements."))
            end

            return new(N, gc_lon, gc_lat, area, mask, unit_of_angle, dims)
        end


    end

    function genWeight_NearestNeighbors(
        filename :: AbstractString,
        gi_s     :: GridInfo,
        gi_d     :: GridInfo,
        NNN_max  :: Integer;
    )

        if length(gi_s.dims) != length(gi_d.dims)
            throw(ErrorException("Source and destination grid does not have same number dimensions"))
        end

        trans = SharedArray{Float64}((NNN_max, gi_d.N))

        # s_coord and d_coord are the coordinates of grid points
        # in 3-dimensional cartesian coordinate

        s_coord = SharedArray{Float64}(3, gi_s.N)
        d_coord = SharedArray{Float64}(3, gi_d.N)

        s_NaN_idx = (gi_s.mask .== 0)

        @sync @distributed for i = 1:gi_s.N

            s_coord[1, i] = cos(gi_s.gc_lat[i]) * cos(gi_s.gc_lon[i])
            s_coord[2, i] = cos(gi_s.gc_lat[i]) * sin(gi_s.gc_lon[i])
            s_coord[3, i] = sin(gi_s.gc_lat[i])

        end

        @sync @distributed for i = 1:gi_d.N

            d_coord[1, i] = cos(gi_d.gc_lat[i]) * cos(gi_d.gc_lon[i])
            d_coord[2, i] = cos(gi_d.gc_lat[i]) * sin(gi_d.gc_lon[i])
            d_coord[3, i] = sin(gi_d.gc_lat[i])

        end

        #s_NaN_idx = (s_mask .== 0)

        println("Start making transform matrix... ")

        @time @sync @distributed for i = 1:gi_d.N

            # For every point find its nearest-neighbors

            #print("\r", i, "/", d_N)

            if gi_d.mask[i] == 0
                trans[:, i] .= 0
                continue
            end

            dist2 = (  (s_coord[1, :] .- d_coord[1, i]).^2
                     + (s_coord[2, :] .- d_coord[2, i]).^2
                     + (s_coord[3, :] .- d_coord[3, i]).^2 )


            # Decided not to apply this condition because in 
            # extreme cases there might be a small area of water
            # that is surrounded by lands.

            dist2[s_NaN_idx] .= NaN
         
            idx_arr = collect(1:gi_s.N)
            sort!(idx_arr; by=(k)->dist2[k])
            trans[:, i] = idx_arr[1:NNN_max]

        end
        if any(isnan.(trans))
            throw(ErrorException("Weird!"))
        end
        trans = convert(Array{Int64}, trans)
        println(typeof(gi_s.dims))

        wi = WeightInfo(
            NNN_max,
            gi_s.N,
            gi_d.N,
            trans,
            gi_s.gc_lat,
            gi_s.gc_lon,
            gi_d.gc_lat,
            gi_d.gc_lon,
            gi_s.dims,
            gi_d.dims,
            gi_s.area,
        )

        writeWeightInfo(wi, filename)
    end

    function writeWeightInfo(
        wi::WeightInfo,
        filename :: AbstractString;
        missing_value = 1e20,
    )

        Dataset(filename, "c") do ds

            defDim(ds, "s_N", wi.s_N)
            defDim(ds, "d_N", wi.d_N)
            defDim(ds, "NNN_max", size(wi.NN_idx)[1])
            defDim(ds, "dims", length(wi.s_dims))

            for (varname, vardata, vardims) in (
                ("NN_idx",    wi.NN_idx, ("NNN_max", "d_N")),
                ("s_gc_lat",  wi.s_gc_lat, ("s_N",)),
                ("s_gc_lon",  wi.s_gc_lon, ("s_N",)),
                ("d_gc_lat",  wi.d_gc_lat, ("d_N",)),
                ("d_gc_lon",  wi.d_gc_lon, ("d_N",)),
                ("s_dims",    wi.s_dims, ("dims",)),
                ("d_dims",    wi.d_dims, ("dims",)),
                ("s_wgt",     wi.s_wgt, ("s_N",)),
            )

                print(format("Output data: {} ...", varname))

                dtype = eltype(vardata)

                v = defVar(ds, varname, eltype(vardata), vardims)

                if dtype <: AbstractFloat
                    v.attrib["_FillValue"] = missing_value
                end

                v[:] = vardata
                println("done.")
            end
            
            
        end

    end    

    function readWeightInfo(
        filename :: AbstractString
    )
        local wi

        Dataset(filename, "r") do ds

            wi = WeightInfo(
                ds.dim["NNN_max"],
                ds.dim["s_N"],
                ds.dim["d_N"],
                replace(ds["NN_idx"], missing=>0),
                replace(ds["s_gc_lat"][:], missing=>NaN),
                replace(ds["d_gc_lon"][:], missing=>NaN),
                replace(ds["s_gc_lat"][:], missing=>NaN),
                replace(ds["d_gc_lon"][:], missing=>NaN),
                replace(ds["s_dims"][:], missing=>0),
                replace(ds["d_dims"][:], missing=>0),
                replace(ds["s_wgt"][:], missing=>NaN),
            )

        end

        return wi

    end    



    function convertData!(
        wi      :: WeightInfo,
        s_data  :: AbstractArray{Float64, 1},
        d_data  :: AbstractArray{Float64, 1},
    )

        NN_idx = wi.NN_idx
        s_wgt  = wi.s_wgt

        NNN = size(NN_idx)[1]
        for i = 1 : length(d_data)

            if NN_idx[1, i] == 0
                d_data[i] = NaN
                continue
            end

            wgt_sum = 0.0
            d_data[i] = 0.0

            for j = 1:NNN

                idx = NN_idx[j, i]
                data = s_data[idx]
        
                if isfinite(data)
                    wgt_sum += s_wgt[idx]
                    d_data[i] += data * s_wgt[idx]
                else
                    break
                end
            end

            d_data[i] = (wgt_sum == 0) ? NaN : d_data[i] / wgt_sum


        end

    end


    function convertFile(
        in_filename   :: AbstractString,
        out_filename  :: AbstractString,
        wgt_filename  :: Union{AbstractString, WeightInfo};
        varnames      :: Union{Nothing, Array} = nothing,
        xydim         :: AbstractString = "grid",
        xdim          :: AbstractString = "lon",
        ydim          :: AbstractString = "lat",
        zdim          :: Union{AbstractString, Nothing} = "lev",
        tdim          :: AbstractString = "time",
        xydim_val     :: Union{AbstractArray{Float64, 1}, Nothing} = nothing,
        xdim_val      :: Union{AbstractArray{Float64, 1}, Nothing} = nothing,
        ydim_val      :: Union{AbstractArray{Float64, 1}, Nothing} = nothing,
        zdim_val      :: Union{AbstractArray{Float64, 1}, Nothing} = nothing,
    )

        if typeof(wgt_filename) <: AbstractString
            wi = readWeightInfo(wgt_filename)
        else
            wi = wgt_filename
        end

        dim_len = length(wi.d_dims)
        d_data_tmp = zeros(Float64, wi.d_N)

        ds_in  = Dataset(in_filename, "r")
        ds_out = Dataset(out_filename, "c")

        if ! (dim_len in (1, 2))
            throw(ErrorException("Weird"))
        end

        # Defining dimension
        if dim_len == 1
            defDim(ds_out, xydim, wi.d_dims[1])
        elseif dim_len == 2
            defDim(ds_out, xdim, wi.d_dims[1])
            defDim(ds_out, ydim, wi.d_dims[2])
        end

        defDim(ds_out, tdim, Inf)

        if zdim != nothing && zdim in ds_in.dim
            defDim(ds_out, zdim, ds_in.dim[zdim])
        end
      

        # Fill in dimension values

        if dim_len == 1

            if xydim_val != nothing
                defVar(ds_out, xydim, xydim_val, (xydim,))
            end

        elseif dim_len == 2

            if xdim_val != nothing
                defVar(ds_out, xdim, xdim_val, (xdim,))
            end

            if ydim_val != nothing
                defVar(ds_out, ydim, ydim_val, (ydim,))
            end
        end

        if zdim_val != nothing
            defVar(ds_out, zdim, zdim_val, (zdim,))
        elseif zdim in ds_in
            defVar(ds_out, zdim, replace(ds_in[zdim][:], missing=>0), (zdim,))
        end

        if varnames == nothing

            varnames = Array{Any}(undef, 0)

            for varname in keys(ds_in)
                println("varname:", varname, "; Dimnames: ", dimnames(ds_in[varname]))
                if dim_len == 1
                    if dimnames(ds_in[varname])[1] == xydim
                        push!(varnames, varname)
                    end
                elseif dim_len == 2
                    if dimnames(ds_in[varname])[1:2] == (xdim, ydim,)
                        push!(varnames, varname)
                    end
                end
            end
        end

        println("Defined dimensions: ", keys(ds_out.dim))

        # Converting variables
        for varname in varnames

            println("Dealing with varname: ", varname)

            if varname in ds_out
                println(format("Varname: {} already exists. Skip.", varname))
                continue
            end

            if ! (varname in ds_in)
                println(format("Cannot find var: {}. Skip.", varname))
                continue
            end


            cf_var = ds_in[varname]
            cf_var_dimnames = dimnames(cf_var)

            # Cannot read data yet. Some data are really large
            #s_data = replace(cf_var[:], missing=>NaN)

            s_data_dims = size(cf_var)
            s_data_dims_len = length(s_data_dims)

            d1 = reduce(*, s_data_dims[1:dim_len])
            d2 = (s_data_dims_len > dim_len) ? reduce(*, s_data_dims[dim_len+1:end]) : 1
           
            #s_data = reshape(s_data, d1, d2)

            attrib = Dict()
            for (k,v) in cf_var.attrib
                if typeof(v) <: AbstractFloat
                    attrib[k] = convert(Float64, v)
                else
                    attrib[k] = v
                end
            end

            println(attrib)
            println(cf_var_dimnames)
            v = defVar(ds_out, varname, Float64, cf_var_dimnames, attrib=attrib)
            
            for k = 1:d2

                # Construct reading / writing shape
                idx = Array{Any}(undef, 0)
                for i=1:dim_len
                    push!(idx, :)
                end

                if s_data_dims_len == dim_len + 1
                    push!(idx, k)
                elseif s_data_dims_len == dim_len + 2
                    zidx = mod(k-1, ds_in.dim[zdim]) + 1
                    tidx = floor(Integer, (k - 1) / ds_in.dim[zdim]) + 1
                    push!(idx, zidx)
                    push!(idx, tidx)
                end
                #println(idx)


                convertData!(wi, reshape( replace( cf_var[idx...], missing=>NaN ), d1 ), d_data_tmp)
                v[idx...] = reshape(d_data_tmp, wi.d_dims[1], wi.d_dims[2])
            end
        end

        close(ds_in)
        close(ds_out)
    end

end
