
function takeSnapshot(
    ocn::Ocean,
    filename::AbstractString;
    missing_value::Float64=1e20
)

    println("Outputting file: ", filename)

    _createNCFile(ocn, filename, missing_value)

    Dataset(filename, "a") do ds
        
        ds.attrib["timestamp"] = Dates.format(now(), "yyyy-mm-dd HH:MM:SS sss")
        ds.attrib["gridinfo_file"] = ocn.gi_file

        for (varname, (var, dim) ) in getVariableList(ocn, :RECORD, :BACKGROUND, :COORDINATE)
            
            print("Taking snapshot of variable: ", varname, "... ")
            
            if var == nothing
                println("not exist, skip this one.")
            else

                if dim == :SCALAR
                    ds.attrib[varname] = getfield(ocn, var)
                else 
                    _write2NCFile(ds, varname, dim, var, missing_value)
                end
                println("done.")

            end

        end

    end

end




function loadSnapshot(
    filename::AbstractString;
    gridinfo_file::AbstractString
)
    local ocn

    Dataset(filename, "r") do ds

        Ts_clim_relax_time = nothing
        Ss_clim_relax_time = nothing

        Ts_clim = nothing
        Ss_clim = nothing

        if haskey(ds, "Ts_clim")
            Ts_clim_relax_time = ds.attrib["Ts_clim_relax_time"]
            Ts_clim = toZXY(nomissing(ds["Ts_clim"][:], NaN), :xyz)
        end

        if haskey(ds, "Ss_clim")
            Ss_clim_relax_time = ds.attrib["Ss_clim_relax_time"]
            Ss_clim = toZXY(nomissing(ds["Ss_clim"][:], NaN), :xyz)
        end

        ocn = Ocean(
            id            = 0,
            gridinfo_file = gridinfo_file,
            Nx            = ds.dim["Nx"],
            Ny            = ds.dim["Ny"],
            zs_bone       = nomissing(ds["zs_bone"][:], NaN);
            Ts            = toZXY( nomissing(ds["Ts"][:], NaN), :xyz),
            Ss            = toZXY( nomissing(ds["Ss"][:], NaN), :xyz),
            K_v           = ds.attrib["K_v"],
            Dh_T          = ds.attrib["Dh_T"],
            Dv_T          = ds.attrib["Dv_T"],
            Dh_S          = ds.attrib["Dh_S"],
            Dv_S          = ds.attrib["Dv_S"],
            fs            = nomissing(ds["fs"][:], NaN),
            ϵs            = nomissing(ds["epsilons"][:], NaN),
            T_ML          = nomissing(ds["T_ML"][:], NaN),
            S_ML          = nomissing(ds["S_ML"][:], NaN),
            h_ML          = nomissing(ds["h_ML"][:], NaN),
            h_ML_min      = nomissing(ds["h_ML_min"][:], NaN),
            h_ML_max      = nomissing(ds["h_ML_max"][:], NaN),
            we_max        = ds.attrib["we_max"],
            R             = ds.attrib["R"],
            ζ             = ds.attrib["zeta"],
            Ts_clim_relax_time = Ts_clim_relax_time,
            Ss_clim_relax_time = Ss_clim_relax_time,
            Ts_clim       = Ts_clim,
            Ss_clim       = Ss_clim,
            topo          = nomissing(ds["topo"][:], NaN),
            in_flds       = nothing,
        )

        for (varname, (var, dim) ) in getVariableList(ocn, :RECORD)

            println("Restoring :RECORD variable: ", varname)

            if typeof(var) <: AbstractArray
                var .= nomissing(ds[varname][:])
            else
                throw(ErrorException("Non vector variable cannot be part of :RECORD variables"))
            end
        end

    end



    return ocn 
end

function _createNCFile(
    ocn::Ocean,
    filename::AbstractString,
    missing_value::Float64,
)

    Dataset(filename, "c") do ds

        defDim(ds, "N_ocs", ocn.N_ocs)
        defDim(ds, "Nx", ocn.Nx)
        defDim(ds, "Ny", ocn.Ny)
        defDim(ds, "Nz_bone", ocn.Nz_bone)
        defDim(ds, "NP_zs_bone",   length(ocn.zs_bone))
        defDim(ds, "time",   Inf)
        
        ds.attrib["_FillValue"] = missing_value
       
        
    end

end


function _write2NCFile(
    ds            :: Dataset,
    varname       :: AbstractString,
    dim           :: Tuple,
    var_data      :: AbstractArray{T},
    missing_value :: G) where T where G

    #println("Write : ", varname)

    ds_var = defVar(ds, varname, eltype(var_data), dim)

    ds_var.attrib["_FillValue"] = missing_value
    for (k, v) in getVarDesc(varname)
        ds_var.attrib[k] = v
    end


    ds_var[:] = var_data


end

"""
    This function is meant to append field into an NC file
    along the time dimension
"""
function _write2NCFile_time(
    ds            :: Dataset,
    varname       :: String,
    dim           :: Tuple,
    time          :: Integer,
    var_data      :: AbstractArray{T};
    missing_value :: Union{T, Nothing} = nothing,
) where T where G

#    time        :: Union{Nothing, UnitRange, Integer} = nothing,
#    time_exists :: Bool = true,
#    missing_value :: Union{T, Nothing} = nothing,
#) where T <: float

    local ds_var

    # Create variable if it is not in the file yet
    if ! ( varname in keys(ds) )

        ds_var = defVar(ds, varname, T, (dim..., "time"))
        
        if missing_value != nothing
            ds_var.attrib["_FillValue"] = missing_value 
        end
    else
        ds_var = ds[varname]
    end

    
    ds_var[repeat([:,], length(dim))..., time] = var_data

end

