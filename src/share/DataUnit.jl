mutable struct DataUnit
    id          :: Union{Symbol, String}
    grid        :: Symbol    # could be ('', s) x (T, U, V, W, UV)
    data        :: AbstractArray  # original data
    sdata1      :: AbstractArray  # oriented shaped data with shape (z, x, y)
    sdata2      :: AbstractArray  # oriented shaped data with shape (x, y, z)
    
    function DataUnit(
        data_table  :: Any,
        id          :: Union{Symbol, String},
        grid        :: Symbol,   
        data        :: AbstractArray,
    )
   
        if ! haskey(data_table.grid_dims, grid)
            throw(ErrorException("Unknown grid: " * string(grid)))
        end

        grid_dim = data_table.grid_dims[grid]
        if length(data) != reduce(*, grid_dim)
#            println(length(data), "; ", size(data))
#            println(map(*, grid_dim))
            throw(ErrorException("Grid type and data length mismatched: " * string(id)))
        end 

        s1data = reshape(data, grid_dim...)
        s2data = PermutedDimsArray(reshape(data, grid_dim...) , [2,3,1])

        return new(
            id,  
            grid, 
            data,
            s1data,
            s2data,
        )
    end        
end
