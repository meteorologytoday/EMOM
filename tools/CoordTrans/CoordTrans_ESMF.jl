module CoordTrans_ESMF

    using NCDatasets
    using SharedArrays
    using Formatting


    # This is a toolbox for integrate general grid to gaussian grid using ESMF_RegridWeiGen
    # The transformation refers to
    # [Section 12.9.3] of http://www.earthsystemmodeling.org/esmf_releases/public/ESMF_8_0_0/ESMF_refdoc/node3.html

    mutable struct WeightInfo
        n_a            :: Integer
        n_b            :: Integer
        n_s            :: Integer
        nv_a           :: Integer
        nv_b           :: Integer
        num_wgts       :: Integer
        src_grid_rank  :: Integer
        dst_grid_rank  :: Integer
        src_grid_dims  :: Array{Integer, 1}
        dst_grid_dims  :: Array{Integer, 1}
        yc_a           :: Array{Float64, 1}
        yc_b           :: Array{Float64, 1}
        xc_a           :: Array{Float64, 1}
        xc_b           :: Array{Float64, 1}
        yv_a           :: Array{Float64, 2}
        yv_b           :: Array{Float64, 2}
        xv_a           :: Array{Float64, 2}
        xv_b           :: Array{Float64, 2}
        mask_a         :: Array{Integer, 1}
        mask_b         :: Array{Integer, 1}
        area_a         :: Array{Float64, 1}
        area_b         :: Array{Float64, 1}
        frac_a         :: Array{Float64, 1}
        frac_b         :: Array{Float64, 1}
        col            :: Array{Integer ,1} 
        row            :: Array{Integer ,1} 
        S              :: Array{Float64 ,1} 
    end


    function readWeightInfo(
        filename :: AbstractString
    )
        local wi

        Dataset(filename, "r") do ds

            wi = WeightInfo(
                ds.dim["n_a"],
                ds.dim["n_b"],
                ds.dim["n_s"],
                ds.dim["nv_a"],
                ds.dim["nv_b"],
                ds.dim["num_wgts"],
                ds.dim["src_grid_rank"],
                ds.dim["dst_grid_rank"],
                ds["src_grid_dims"][:] |> nomissing,
                ds["dst_grid_dims"][:] |> nomissing,
                ds["yc_a"][:] |> nomissing,
                ds["yc_b"][:] |> nomissing,
                ds["xc_a"][:] |> nomissing,
                ds["xc_b"][:] |> nomissing,
                ds["yv_a"][:] |> nomissing,
                ds["yv_b"][:] |> nomissing,
                ds["xv_a"][:] |> nomissing,
                ds["xv_b"][:] |> nomissing,
                ds["mask_a"][:] |> nomissing,
                ds["mask_b"][:] |> nomissing,
                ds["area_a"][:] |> nomissing,
                ds["area_b"][:] |> nomissing,
                ds["frac_a"][:] |> nomissing,
                ds["frac_b"][:] |> nomissing,
                ds["col"][:] |> nomissing,
                ds["row"][:] |> nomissing,
                ds["S"][:] |> nomissing,
            )

        end

        return wi

    end    



    function convertData!(
        wi      :: WeightInfo,
        s_data  :: AbstractArray{Float64, 1},
        d_data  :: AbstractArray{Float64, 1},
    )
        d_data .= 0.0
        for i=1:wi.n_s
            d_data[wi.row[i]] += wi.S[i] * s_data[wi.col[i]] 
        end

        for i=1:wi.n_b
            d_data[i] = ( wi.frac_b[i] != 0.0 ) ? d_data[i] / wi.frac_b[i] : NaN
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
        tlen          :: Integer = -1,
        xdim_val      :: Union{AbstractArray{Float64, 1}, Nothing} = nothing,
        ydim_val      :: Union{AbstractArray{Float64, 1}, Nothing} = nothing,
        zdim_val      :: Union{AbstractArray{Float64, 1}, Nothing} = nothing,
    )
        if typeof(wgt_filename) <: AbstractString
            wi = readWeightInfo(wgt_filename)
        else
            wi = wgt_filename
        end

#        sNx, sNy = wi.src_grid_dims    
        dNx, dNy = wi.dst_grid_dims    

        d_data_tmp = zeros(Float64, dNx * dNy)

        ds_in  = Dataset(in_filename, "r")
        ds_out = Dataset(out_filename, "c")

        defDim(ds_out, xdim, dNx)
        defDim(ds_out, ydim, dNy)
        defDim(ds_out, tdim, (tlen == -1) ? Inf : tlen)

        if zdim != nothing && zdim in ds_in.dim
            defDim(ds_out, zdim, ds_in.dim[zdim])
        end
      

        # Fill in dimension values

        if xdim_val != nothing
            defVar(ds_out, xdim, xdim_val, (xdim,))
        end

        if ydim_val != nothing
            defVar(ds_out, ydim, ydim_val, (ydim,))
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
                if dimnames(ds_in[varname])[1:2] == (xdim, ydim,)
                    push!(varnames, varname)
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

            d1 = reduce(*, s_data_dims[1:2])
            d2 = (s_data_dims_len > 2) ? reduce(*, s_data_dims[3:end]) : 1
           
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
                for i=1:2
                    push!(idx, :)
                end

                if s_data_dims_len == 3
                    push!(idx, k)
                elseif s_data_dims_len == 4
                    zidx = mod(k-1, ds_in.dim[zdim]) + 1
                    tidx = floor(Integer, (k - 1) / ds_in.dim[zdim]) + 1
                    push!(idx, zidx)
                    push!(idx, tidx)
                end

                convertData!(wi, reshape( replace( cf_var[idx...], missing=>NaN ), d1 ), d_data_tmp)
                v[idx...] = reshape(d_data_tmp, (dNx, dNy))
            end
        end

        close(ds_in)
        close(ds_out)
    end

end
