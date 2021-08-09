function loadSnapshot(
    filename::AbstractString;
    gridinfo_file::Union{AbstractString, Nothing} = nothing,
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
            id       = 0,
            gridinfo_file = (gridinfo_file == nothing) ? ds.attrib["gridinfo_file"] : gridinfo_file,
            Nx       = ds.dim["Nx"],
            Ny       = ds.dim["Ny"],
            zs_bone  = nomissing(ds["zs_bone"][:], NaN);
            Ts       = toZXY( nomissing(ds["Ts"][:], NaN), :xyz),
            Ss       = toZXY( nomissing(ds["Ss"][:], NaN), :xyz),
            K_v      = ds.attrib["K_v"],
            Dh_T      = ds.attrib["Dh_T"],
            Dv_T      = ds.attrib["Dv_T"],
            Dh_S      = ds.attrib["Dh_S"],
            Dv_S      = ds.attrib["Dv_S"],
            fs       = nomissing(ds["fs"][:], NaN),
            ϵs       = nomissing(ds["epsilons"][:], NaN),
            T_ML     = nomissing(ds["T_ML"][:], NaN),
            S_ML     = nomissing(ds["S_ML"][:], NaN),
            h_ML     = nomissing(ds["h_ML"][:], NaN),
            h_ML_min = nomissing(ds["h_ML_min"][:], NaN),
            h_ML_max = nomissing(ds["h_ML_max"][:], NaN),
            we_max   = ds.attrib["we_max"],
            R        = ds.attrib["R"],
            ζ        = ds.attrib["zeta"],
            Ts_clim_relax_time = Ts_clim_relax_time,
            Ss_clim_relax_time = Ss_clim_relax_time,
            Ts_clim  = Ts_clim,
            Ss_clim  = Ss_clim,
            mask     = nomissing(ds["mask"][:], NaN),
            topo     = nomissing(ds["topo"][:], NaN),
            in_flds  = nothing,
        )

    end

    return ocn 
end


function takeSnapshot(
    ocn::Ocean,
    filename::AbstractString;
    missing_value::Float64=1e20
)
    _createNCFile(ocn, filename, missing_value)

    Dataset(filename, "a") do ds
 
        ds.attrib["gridinfo_file"] = ocn.gi_file
        ds.attrib["K_v"] = ocn.K_v
        ds.attrib["Dh_T"] = ocn.Dh_T
        ds.attrib["Dv_T"] = ocn.Dv_T
        ds.attrib["Dh_S"] = ocn.Dh_S
        ds.attrib["Dv_S"] = ocn.Dv_S


        ds.attrib["we_max"] = ocn.we_max
        ds.attrib["R"]    = ocn.R
        ds.attrib["zeta"] = ocn.ζ

        if ocn.Ts_clim_relax_time != nothing
            ds.attrib["Ts_clim_relax_time"] = ocn.Ts_clim_relax_time
        end
 
        if ocn.Ss_clim_relax_time != nothing
            ds.attrib["Ss_clim_relax_time"] = ocn.Ss_clim_relax_time
        end
       
        _write2NCFile(ds, "zs_bone", ("NP_zs_bone",), ocn.zs_bone, missing_value)

        _write2NCFile(ds, "Ts", ("Nx", "Ny", "Nz_bone"), toXYZ(ocn.Ts, :zxy), missing_value)
        _write2NCFile(ds, "Ss", ("Nx", "Ny", "Nz_bone"), toXYZ(ocn.Ss, :zxy), missing_value)
        _write2NCFile(ds, "bs", ("Nx", "Ny", "Nz_bone"), toXYZ(ocn.bs, :zxy), missing_value)
        _write2NCFile(ds, "T_ML", ("Nx", "Ny",), ocn.T_ML, missing_value)
        _write2NCFile(ds, "S_ML", ("Nx", "Ny",), ocn.S_ML, missing_value)
        _write2NCFile(ds, "h_ML", ("Nx", "Ny",), ocn.h_ML, missing_value)
        
        _write2NCFile(ds, "h_ML_min", ("Nx", "Ny",), ocn.h_ML_min, missing_value)
        _write2NCFile(ds, "h_ML_max", ("Nx", "Ny",), ocn.h_ML_max, missing_value)

        if ocn.Ts_clim != nothing
            _write2NCFile(ds, "Ts_clim", ("Nx", "Ny", "Nz_bone"), toXYZ(ocn.Ts_clim, :zxy), missing_value)
        end

        if ocn.Ss_clim != nothing
            _write2NCFile(ds, "Ss_clim", ("Nx", "Ny", "Nz_bone"), toXYZ(ocn.Ss_clim, :zxy), missing_value)
        end

        _write2NCFile(ds, "mask", ("Nx", "Ny",), ocn.mask, missing_value)
        _write2NCFile(ds, "topo", ("Nx", "Ny",), ocn.topo, missing_value)

        _write2NCFile(ds, "fs", ("Nx", "Ny"), ocn.fs, missing_value)
        _write2NCFile(ds, "epsilons", ("Nx", "Ny"), ocn.ϵs, missing_value)
        
        # Additional 
        _write2NCFile(ds, "area", ("Nx", "Ny",), ocn.mi.area, missing_value)
        _write2NCFile(ds, "xc",   ("Nx", "Ny",), ocn.mi.xc,   missing_value)
        _write2NCFile(ds, "yc",   ("Nx", "Ny",), ocn.mi.yc,   missing_value)

    end

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

