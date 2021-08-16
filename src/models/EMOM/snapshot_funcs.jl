"""
loadSnapshot
Usage: It loads a netcdf snapshot file and a config JSON file that is used in Env.
       If `timestamp` is provided, the function will check if it matches the 
       timestamp recorded in the netcdf file.
"""
function loadSnapshot(
    filename   :: AbstractString,   # Field
    timestamp  :: Union{AbstractCFDateTime, Nothing} = nothing;
    overwrite_config :: Union{Dict, Nothing} = nothing,
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



    cfg = snapshot["ev_config"]
        
    writeLog("### Loaded config ###")
    println(cfg)
    
    if overwrite_config != nothing
        writeLog("### Overwriting config ###")
        for (k, v) in overwrite_config
            if haskey(cfg, k)
                if cfg[k] != v
                    writeLog("{:s} is overwritten: {:s} => {:s}", k,  string(cfg[k]), string(v))
                end
            else
                writeLog("{:s} is added: {:s}", k,  string(v))
            end

            cfg[k] = v
        end
    end


    ev = Env(cfg; verbose=true)
    mb = ModelBlock(ev; init_core = false) 
 
   
    writeLog("### Loading field from snapshot to current model ###")
    loaded_fi = snapshot["fi"]
    for fieldname in fieldnames(Field)

        var = getfield(mb.fi, fieldname) 
        loaded_var = getfield(loaded_fi, fieldname)

        if typeof(var) <: Array
            var.= loaded_var
            writeLog("Field loaded: {:s}", string(fieldname))
        else
            writeLog("Field {:s} is not raw array. Skip it.", string(fieldname))
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
    mb            :: EMOM.ModelBlock,
    filename      :: AbstractString,   # Field
    missing_value :: Float64=1e20,
)

    JLD2.save(filename, "fi", mb.fi, "ev_config", mb.ev.config, "timestamp", timestamp)

end

