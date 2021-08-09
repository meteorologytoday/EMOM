
module ConfigCheck

    using Formatting

    export ConfigEntry, validateConfigEntries, validateByConfigGroup

    mutable struct ConfigEntry
        name      :: Symbol
        required  :: Symbol
        valid_vts :: AbstractArray
        default   :: Any
        desc      :: String
        function ConfigEntry(
            name      :: Symbol,
            required  :: Symbol,
            valid_vts :: AbstractArray,
            default   :: Any = nothing;
            desc      :: String = "",
        )

            return new(
                name,
                required,
                valid_vts,
                default,
                desc,
            )
        end

    end

    function validateByConfigGroup(
        cfg                :: Dict,
        cfg_desc           :: Dict{Symbol, AbstractArray{ConfigEntry, 1}},
        target_group_names :: Union{AbstractArray{Symbol}, Nothing} = nothing,
    )

        # cfg_desc is a Dict whose key is the name of a config group and 
        # value is an Array of ConfigEntry

        all_group_names = keys(cfg_desc.groups)
        if target_group_names == nothing
            target_group_names = all_group_names
        end

        new_cfg = Dict{Symbol,Any}()
        for group_name in all_group_names
            if group_name in target_group_names
                new_cfg[group_name] = validateConfig(cfg[group_name], cfg_desc[group_name])
            else
                # simply transfer it
                new_cfg[group_name] = cfg[group_name]
            end 
        end

        return new_cfg
    end


    function validateConfigEntries(
        cfg         :: Dict,
        cfg_entries :: AbstractArray{ConfigEntry, 1},
    )

        new_cfg = Dict{Symbol, Any}()
        
        for entry in cfg_entries

            name      = entry.name
            required  = entry.required
            valid_vts = entry.valid_vts
            default   = entry.default

            if ! ( required in [:optional, :required] )
                throw(ErrorException("The `required` only takes :optional or :required"))
            end

            if haskey(cfg, name)
                pass = false
                for valid_vt in valid_vts

                    if typeof(valid_vt) <: Union{DataType, UnionAll}
                        if typeof(cfg[name]) <: valid_vt
                            pass = true
                        end
                    else
                        if cfg[name] == valid_vt
                            pass = true
                        end
                    end

                    if pass 
                        break
                    end

                end
                
                if pass
                    
                    new_cfg[name] = cfg[name]
                    println(format("[Validation] Config `{:s}` : {:s}", string(name), string(new_cfg[name])))
                else
                    throw(ErrorException(format(
                        "[Error] Invalid value of key `{:s}`: {:s}. Valid values/types: `{:s}`.",
                        string(name),
                        string(cfg[name]),
                        join(string.(valid_vts), "` ,`")
                    )))
                end


            else

                msg = format(
                    "Missing config: `{:s}`. Valid values/types: `{:s}`.",
                    string(name),
                    join(string.(valid_vts), "` ,`")
                )
                
                if required == :required
                    throw(ErrorException(format("[Required] {:s}", msg)))
                else
                    new_cfg[name] = default
                    println(format("[Optional] {:s} is set to default: {:s}", string(name), string(new_cfg[name])))

                end
            end
        end

        #dropped_names = filter(x -> !( haskey(new_cfg, x) ), keys(cfg))
        #for dropped_name in dropped_names
        #    println(format("The config `{:s}` is not used.", string(dropped_name)))
        #end

        return new_cfg

    end

end
