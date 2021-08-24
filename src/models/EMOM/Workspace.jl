mutable struct Workspace

    Nx :: Int64
    Ny :: Int64
    Nz :: Int64

    T :: Array
    U :: Array
    V :: Array
    W :: Array

    sT :: Array
    sU :: Array
    sV :: Array

    ptr :: Dict
    dim_dict :: Dict

    warning_cnt :: Integer

    function Workspace(;
        Nx :: Int64,
        Ny :: Int64,
        Nz :: Int64,
        warning_cnt = 20,
    )


        _T = []
        _U = []
        _V = []
        _W = []

        _sT = []
        _sU = []
        _sV = []

        ptr = Dict(
            :T => 1,
            :U => 1,
            :V => 1,
            :W => 1,
            :sT => 1,
            :sU => 1,
            :sV => 1,
        )

        dim_dict = Dict(
            :T =>  [Nz, Nx, Ny],
            :U =>  [Nz, Nx, Ny],
            :V =>  [Nz, Nx, Ny+1],
            :W =>  [Nz+1, Nx, Ny],
            :sT => [1, Nx, Ny  ],
            :sU => [1, Nx, Ny  ],
            :sV => [1, Nx, Ny+1],
        )

        return new(
            Nx, Ny, Nz,
            _T, _U, _V, _W,
            _sT, _sU, _sV,
            ptr,
            dim_dict,
            warning_cnt,
        )

    end
    

end

function getSpace!(
    wksp :: Workspace,
    grid :: Symbol,
    flat :: Bool = false;
    o :: Union{Float64, Nothing} = nothing  # overwritten value
)
    i = wksp.ptr[grid]
    list = getfield(wksp, grid)

    if i > length(list)
        #println("Running out of workspace of " * string(grid) * ", create new...")
        push!(list, genEmptyGrid(wksp, Float64, grid))
        if length(list) > wksp.warning_cnt
            println(format("Warning: Now we have {:d} workspace arrays.", length(list)))
        end 
    end
    
    wksp.ptr[grid] += 1

    arr = ( flat ) ? view(list[i], :) : list[i]

    if o != nothing
        arr .= o
    end

    return arr
end

function reset!(
    wksp :: Workspace,
    grid :: Symbol=:ALL,
)
    if grid == :ALL
        for k in keys(wksp.ptr)
            wksp.ptr[k] = 1
        end
    else
        wksp.ptr[grid] = 1
    end

end

function genEmptyGrid(
    wksp  :: Workspace,
    dtype :: DataType,
    grid  :: Symbol,
)
    Nx, Ny, Nz = wksp.Nx, wksp.Ny, wksp.Nz
    dim = wksp.dim_dict[grid]

    return zeros(dtype, dim...)

end

#=
function releaseMemory!(
    wksp :: Workspace,
)

    if grid == :ALL
        for k in keys(wksp.ptr)
            wksp.ptr[k] = 1
        end
    else
        wksp.ptr[grid] = 1
    end

end
=#
