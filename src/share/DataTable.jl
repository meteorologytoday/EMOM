
mutable struct DataTable

    dims        :: Dict
    grid_dims   :: Dict
    grid_dims2_str  :: Dict
    data_units  :: Dict
    missing_idx1 :: Dict   # with shape (z, x, y)
    missing_idx2 :: Dict   # with shape (x, y, z)
    flags       :: Dict    # What are flags for? 

    function DataTable(;
        Nx,
        Ny,
        Nz,
        mask_sT    :: Union{Nothing, AbstractArray{Float64, 3}} = nothing,
        mask_T     :: Union{Nothing, AbstractArray{Float64, 3}} = nothing,
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
            :cW => (Nzp1, N1, N1),
            :cT => (Nz, N1, N1),
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
            :cW => ("N1", "N1", "Nzp1",),
            :cT => ("N1", "N1", "Nz",),
        )



        data_units = Dict()
        flags      = Dict()


        missing_idx1 = Dict(
            :sT => (mask_sT == nothing) ? nothing : mask_sT .== 0,
            :T  => (mask_T == nothing) ? nothing : mask_T .== 0,
            :U => nothing,
            :V => nothing,
            :W => nothing,
            :UV => nothing,
            nothing => nothing,
        )
    
        missing_idx2 = Dict()
        for (k,v) in missing_idx1
            missing_idx2[k] = (v != nothing) ? permutedims(v, [2, 3, 1]) : nothing
        end


        return new(
            dims,
            grid_dims,
            grid_dims2_str,
            data_units,
            missing_idx1,
            missing_idx2,
            flags,
        )

    end

end

function regVariable!(
    dt       :: DataTable,
    id       :: Union{Symbol, String},
    grid     :: Symbol,
    mask     :: Union{Symbol, Nothing},
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

    dim = dt.grid_dims[grid]

    dtype = eltype(data)
    if ! (dtype in (Float64, Int64))
        throw(ErrorException("Invalid data type. Only Float64 and Int64 are accepted"))
    end

    if Tuple(dim) != size(data)
        println("Expect ", dim)
        println("Get ", size(data))
        throw(ErrorException("Provided data does not have correct dimension: " * string(id)))
    end

    if dtype != T
        throw(ErrorException("dtype and provided data does not match."))
    end

    dt.data_units[id] = DataUnit(
        dt,
        id,
        grid,
        mask,
        data,
    )

    dt.flags[id] = 0
end
