mutable struct NonStatObj 

    varname  :: AbstractString
    varref   :: AbstractArray{Float64}
    
    dimnames :: Tuple

    function NonStatObj(varname, varref, dimnames)
        if length(size(varref)) != length(dimnames)
            ErrorException(format("Variable `{:s}` is {:d} dimensional while only {:d} dimension names are given.", varname, length(size(varref)), length(dimnames))) |> throw
        end

        return new(varname, varref, dimnames)
    end

end


mutable struct StatObj

    varname  :: AbstractString
    varref   :: AbstractArray{Float64}
    var      :: AbstractArray{Float64}

    dimnames :: Tuple

    weight    :: Float64

    function StatObj(varname, varref, dimnames)
        if length(size(varref)) != length(dimnames)
            ErrorException(format("Variable `{:s}` is {:d} dimensional while only {:d} dimension names are given.", varname, length(size(varref)), length(dimnames))) |> throw
        end

        var = zeros(Float64, size(varref)...)

        return new(varname, varref, var, dimnames, 0.0)
    end

end


mutable struct Recorder

    data_table :: DataTable
    sobjs    :: Dict
    nsobjs   :: Dict
    masks    :: Union{Dict, Nothing}
    desc     :: Dict
    filename :: Union{Nothing, AbstractString}
    time_ptr :: Integer  # The position of next record
 
    function Recorder(
        data_table :: DataTable,
        varnames   :: AbstractArray,
        desc       :: Dict;
        other_varnames = nothing,
        masks      :: Union{Nothing, Dict} = nothing,
    )

        sobjs  = Dict()
        nsobjs = Dict()

        for varname in varnames
            du = data_table.data_units[varname]
            sobjs[varname] = StatObj(varname, du.sdata2, data_table.grid_dims2_str[du.grid])
        end

        if other_varnames == nothing
            
        else

            for varname in other_varnames
                du = data_table.data_units[varname]
                sobjs[varname] = NonStatObj(varname, du.sdata2, data_table.grid_odims_str[du.grid])
            end
        end

        return new(
            data_table,
            sobjs,
            nsobjs,
            masks,
            desc,
            nothing,
            1,
        )
    end

end


function record_wrap!(
    rec             :: Recorder;
    create_new_file :: Bool,
    avg_and_output  :: Bool,
    new_file_name   :: AbstractString,
)

    if create_new_file
        setNewNCFile!(rec, new_file_name)
    end

    record!(rec; avg_and_output=avg_and_output)


end


function record!(
    rec::Recorder;
)

    varnames = keys(rec.sobjs)

    for varname in varnames
        sobj = rec.sobjs[varname]
        sobj.var .+= sobj.varref
        sobj.weight += 1.0
    end
    
end

function avgAndOutput!(
    rec :: Recorder
)

    if rec.filename == nothing
        ErrorException("Undefined record filename") |> throw
    end

    # Do average
    for (varname, sobj) in rec.sobjs
        if sobj.weight == 0
            ErrorException(format("StatObj for variable `{:s}` has weight 0 during normalization.", varname)) |> throw
        end
        sobj.var /= sobj.weight
    end
    
    # Output data
    Dataset(rec.filename, "a") do ds
        for (varname, sobj) in rec.sobjs
            ds_var = ds[varname]
            ds[varname][repeat([:,], length(sobj.dimnames))..., rec.time_ptr] = sobj.var
        end
    end


    # Reset StatObjs
    for (_, sobj) in rec.sobjs
        sobj.var .= 0.0
        sobj.weight = 0.0
    end
    
    # Increment of time
    rec.time_ptr += 1


end

function setNewNCFile!(rec::Recorder, filename::AbstractString)
    rec.filename = filename
    rec.time_ptr = 1
    
    Dataset(filename, "c") do ds

        for (dimname, dim) in rec.data_table.dims 
            defDim(ds, dimname, dim)
        end

        defDim(ds, "time",   Inf)
        ds.attrib["_FillValue"] = missing_value
        ds.attrib["timestamp"] = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS sss")

        for (varname, sobj) in rec.sobjs
            ds_var = defVar(ds, varname, Float64, (sobj.dimnames..., "time"))
            ds_var.attrib["_FillValue"] = missing_value

            if haskey(rec.desc, varname)
                for (k, v) in rec.desc[varname]
                    ds_var.attrib[k] = v
                end
            end
        end

        for (varname, nsobj) in rec.nsobjs
            ds_var = defVar(ds, varname, Float64, (nsobj.dimnames...,))
            ds_var.attrib["_FillValue"] = missing_value

            if haskey(rec.desc, varname)
                for (k, v) in rec.desc[varname]
                    ds_var.attrib[k] = v
                end
            end
            ds_var[:] = nsobj.varref
        end 


    end
    
end

