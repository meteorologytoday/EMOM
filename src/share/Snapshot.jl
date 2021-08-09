module Snapshot

using NCDatasets

float = Union{Float64, Float32}

mutable struct MapInfo{T <: float}
    nx :: Integer
    ny :: Integer
    nz :: Integer
 
    mask :: Array{T, 2}
    missing_value :: T

    function MapInfo{T}(;
        nx::Integer,
        ny::Integer,
        nz::Integer,
        mask::Array{T,2},
        missing_value::T = 1e20
    ) where T <: float
    
        
        return new{T}(
            nx, ny, nz,
            mask, missing_value,
        )

    end

end

function createNCFile(
    mi::MapInfo{T},
    filename::String;
) where T <: float

    Dataset(filename, "c") do ds

        defDim(ds, "ni", mi.nx)
        defDim(ds, "nj", mi.ny)
        defDim(ds, "nk", mi.nz)

    end

end

function createSnapshot(
    mi          :: MapInfo{T},
    filename    :: String;
    vars_2d     :: Dict,
    vars_3d     :: Dict,
) where T <: float

    for (varname, var) in vars
        #println("varname: ", varname)
        write2NCFile(
            mi, filename, varname, var;
            time=time,
            time_exists=time_exists,
            missing_value=missing_value
        )
    end
end



end
