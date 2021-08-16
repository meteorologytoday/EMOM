mutable struct DataUnit
    id          :: Union{Symbol, String}
    grid        :: Symbol    # could be ('', s) x (T, U, V, W, UV)
    mask        :: Union{Symbol, Nothing}
    data        :: AbstractArray  # original data

    # if data is in spatial structure, then it will oriented as
    # sdata1 = z > x > y
    # sdata2 = x > y > z
    sdata1      :: AbstractArray
    sdata2      :: AbstractArray

    
    function DataUnit(
        data_table  :: Any,
        id          :: Union{Symbol, String},
        grid        :: Symbol,
        mask        :: Union{Symbol, Nothing}, 
        data        :: AbstractArray,
    )
   
        if mask == :mask
            mask = grid
        end

        if ! haskey(data_table.grid_dims, grid)
            throw(ErrorException("Unknown grid: " * string(grid)))
        end

        grid_dim = data_table.grid_dims[grid]
        if length(data) != reduce(*, grid_dim)
            throw(ErrorException("Grid type and data length mismatched: " * string(id)))
        end 

        s1data = reshape(data, grid_dim...)
        s2data = PermutedDimsArray(s1data, [2,3,1])

        return new(
            id,  
            grid,
            mask, 
            data,
            s1data,
            s2data,
        )
    end        
end
