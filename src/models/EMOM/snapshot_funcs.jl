"""
loadSnapshot
Usage: It loads a netcdf snapshot file and a config JSON file that is used in Env.
       If `timestamp` is provided, the function will check if it matches the 
       timestamp recorded in the netcdf file.
"""
function loadSnapshot(
    filename   :: AbstractString,   # Field
    timestamp  :: Union{AbstractCFDateTime, Nothing} = nothing,
)

    writeLog("Reading files: {:s}", filename)
    
    snapshot = JLD2.load(filename)
    if timestamp != nothing

        timestamp_str = Dates.format(timestamp, "yyyy-mm-dd HH:MM:SS")

        if timestamp_str != snapshot["timestamp"]
            throw(ErrorException(format(
                "The provided timestamp is {:s}, but the netcdf file timestamp is {:s}",
                timestamp_str,
                snapshot["timestamp"], 
            )))
        end
    end
    println(keys(snapshot))

    ev = Env(snapshot["ev_config"])
    mb = ModelBlock(ev; init_core = false) 
 
   
    loaded_fi = snapshot["fi"]
    for fieldname in fieldnames(Field)
        println("Loading field: " * string(fieldname))
        var = getfield(mb.fi, fieldname) 
        loaded_var = getfield(loaded_fi, fieldname)

        if typeof(var) <: Array
            var.= loaded_var
        else
            println("Skip variable that is not array: ", string(fieldname))
        end
    end
 
    mb.fi.sv = getSugarView(mb.ev, mb.fi)
 
    return mb
end

"""
takeSnapshot

Usage: It output netcdf file that is a copy of variables in the given DataTable
       It also converts a config Dict into JSON text file
"""
function takeSnapshot(
    timestamp     :: AbstractCFDateTime,
    mb            :: HOOM.ModelBlock,
    filename      :: AbstractString,   # Field
    missing_value :: Float64=1e20,
)

    JLD2.save(filename, "fi", mb.fi, "ev_config", mb.ev.config, "timestamp", timestamp)
    
end

#=
function takeSnapshot(
    timestamp     :: AbstractCFDateTime,
    mb            :: HOOM.ModelBlock,
    filename      :: AbstractString,   # Field
    filename_cfg  :: AbstractString;   # Configuration
    missing_value :: Float64=1e20,
)

    timestamp_str = Dates.format(timestamp, "yyyy-mm-dd HH:MM:SS")
    data_table = mb.dt

    Dataset(filename_nc, "c") do ds

        defDim(ds, "time",   Inf)
        for (dimname, dimvalue) in data_table.dims
            defDim(ds, dimname, dimvalue)
        end

        ds.attrib["_FillValue"] = missing_value
        ds.attrib["timestamp"] = timestamp_str

        varnames = keys(HOOM.getDynamicVariableList(mb; varsets = [:ALL,]))
        for (varname, data_unit) in data_table.data_units

            data_unit = data_table.data_units[varname]

            println("Writing ", varname, "... ")
            ds_var = defVar(ds, varname, eltype(data_unit.sdata2), (data_table.grid_dims2_str[data_unit.grid]..., "time"))
            ds_var.attrib["_FillValue"] = missing_value 
            ds_var = ds[varname]

            ds_var[:, :, :, 1] = data_unit.sdata2

        end

    end

    open(filename_cfg, "w") do io
        JSON.print(io, mb.ev.config, 2)
    end

    
end

=#
