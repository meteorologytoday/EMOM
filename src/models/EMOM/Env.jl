mutable struct Env

    config :: Dict
    
    sub_yrng :: Union{UnitRange, Colon, Nothing}
    Nx :: Integer
    Ny :: Integer
    Nz :: Integer

    function Env(
        config;
        sub_yrng = nothing,
    )
       
        writeLog("Validating config: :MODEL_CORE") 
        validated_config = validateConfigEntries(config, getConfigDescriptor()[:MODEL_CORE]) 
           
        # mask =>   lnd = 0, ocn = 1
        gf = PolelikeCoordinate.CurvilinearSphericalGridFile(
            validated_config[:domain_file];
            R  = 6371229.0,
            Ω  = 2π / (86400 / (1 + 365/365)),
        )

        Nx = gf.Nx
        Ny = (sub_yrng == nothing) ? gf.Ny : length(sub_yrng)
        Nz = length(validated_config[:z_w]) - 1

        return new(
            
            validated_config,
 
            sub_yrng,        
            Nx,
            Ny,
            Nz,

        )
    end

end


