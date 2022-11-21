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



    cfgs = snapshot["ev_cfgs"]
 
    writeLog("### Loaded config domain (cannot overwrite) ###")
    JSON.print(cfgs["DOMAIN"], 4)
        
    writeLog("### Loaded config core (overwritable) ###")
    JSON.print(cfgs["MODEL_CORE"], 4)
   
    cfg_core = cfgs["MODEL_CORE"]
    if overwrite_config != nothing
        writeLog("### Overwriting core config ###")
        for (k, v) in overwrite_config
            if haskey(cfg_core, k)
                if cfg_core[k] != v
                    writeLog("{:s} is overwritten: {:s} => {:s}", k,  string(cfg_core[k]), string(v))
                end
            else
                writeLog("{:s} is added: {:s}", k,  string(v))
            end

            cfg_core[k] = v
        end
    end


    ev = Env(cfgs; verbose=true)
    mb = ModelBlock(ev; init_core = false) 
 
   
    writeLog("### Loading field from snapshot to current model ###")
    loaded_fi = snapshot["fi"]
    for fieldname in fieldnames(Field)

        var = getfield(mb.fi, fieldname) 
        
        if hasfield(typeof(loaded_fi), fieldname)
            loaded_var = getfield(loaded_fi, fieldname)

            if typeof(var) <: Array
                var.= loaded_var
                writeLog("Field loaded: {:s}", string(fieldname))
            else
                writeLog("Field {:s} is not raw array. Skip it.", string(fieldname))
            end
        else        
            writeLog("Field {:s} does not exist in snapshot. Skip it.", string(fieldname))
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

    JLD2.save(filename, "fi", mb.fi, "ev_cfgs", mb.ev.cfgs, "timestamp", timestamp)

end

