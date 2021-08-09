
mutable struct DataTable

    dims        :: Dict
    grid_dims   :: Dict
    grid_dims2_str  :: Dict
    data_units  :: Dict
    flags       :: Dict    # What are flags for? 

    function DataTable(;
        Nx, Ny, Nz
    )

        N1 = 1
        Nyp1 = Ny+1
        Nzp1 = Nz+1

        dims = Dict(
            "N1" => N1,
            "Nx" => Nx,
            "Ny" => Ny,
            "Nz" => Nz,
            "Nyp1" => Nyp1,
            "Nzp1" => Nzp1,
        )


        grid_dims = Dict(
            :T  => (Nz,   Nx  , Ny  ),
            :U  => (Nz,   Nx  , Ny  ),
            :V  => (Nz,   Nx  , Nyp1),
            :W  => (Nzp1, Nx  , Ny  ),
            :sT => (N1, Nx, Ny  ),
            :sU => (N1, Nx, Ny  ),
            :sV => (N1, Nx, Nyp1),
            :SCALAR => (N1, N1, N1),
        )

        # This is used for RecordTool output
        # Notice that this is oriented dimension so z is the last one
        grid_dims2_str = Dict(
            :T  => ("Nx", "Ny", "Nz"),
            :U  => ("Nx", "Ny", "Nz"),
            :V  => ("Nx", "Nyp1", "Nz"),
            :W  => ("Nx", "Ny", "Nzp1"),
            :sT => ("Nx", "Ny", "N1"),
            :sU => ("Nx", "Ny", "N1"),
            :sV => ("Nx", "Nyp1", "N1"),
            :SCALAR => ("N1", "N1", "N1"),
        )



        data_units = Dict()
        flags      = Dict()

        return new(
            dims,
            grid_dims,
            grid_dims2_str,
            data_units,
            flags,
        )

    end

end

function regVariable!(
    dt       :: DataTable,
    id       :: Union{Symbol, String},
    grid     :: Symbol,
    data     :: AbstractArray{T},
) where T

    N1 = dt.dims["N1"]
    Nx = dt.dims["Nx"]
    Ny = dt.dims["Ny"]
    Nz = dt.dims["Nz"]
    Nyp1 = dt.dims["Nyp1"]
    Nzp1 = dt.dims["Nzp1"]

    if haskey(dt.data_units, id)
        throw(ErrorException("Error: variable id " * String(id) *  " already exists."))
    end

    dim = Dict(
        :T  => [Nz,   Nx  , Ny  ],
        :U  => [Nz,   Nx  , Ny  ],
        :V  => [Nz,   Nx  , Nyp1],
        :W  => [Nzp1, Nx  , Ny  ],
        :sT => [N1, Nx, Ny  ],
        :sU => [N1, Nx, Ny  ],
        :sV => [N1, Nx, Nyp1],
        :SCALAR => [N1, N1, N1],
    )[grid]

    dtype = eltype(data)
    if ! (dtype in (Float64, Int64))
        throw(ErrorException("Invalid data type. Only Float64 and Int64 are accepted"))
    end

    if Tuple(dim) != size(data)
        println("Expect ", dim)
        println("Get ", size(data))
        throw(ErrorException("Provided data does not have correct dimension."))
    end

    if dtype != T
        throw(ErrorException("dtype and provided data does not match."))
    end

    dt.data_units[id] = DataUnit(
        dt,
        id,
        grid,
        data,
    )

    dt.flags[id] = 0
end
