abstract type GridFile end 

mutable struct CurvilinearSphericalGridFile <: GridFile

    R    :: Float64
    Ω    :: Float64

    Nx    :: Integer
    Ny    :: Integer
    lsize :: Integer
 
    xc    :: Array{Float64, 2}
    yc    :: Array{Float64, 2}
 
    xv    :: Array{Float64, 3}
    yv    :: Array{Float64, 3}

   
    mask  :: Array{Float64, 2}
    area  :: Array{Float64, 2}
    frac  :: Array{Float64, 2}
    
    missing_value :: Float64

    function CurvilinearSphericalGridFile(
        filename::String;
        R       :: Float64,
        Ω       :: Float64,
        missing_value::Float64 = 1e20
    )
    
        ds = Dataset(filename, "r")
        _mask = ds["mask"][:, :]
        _area = ds["area"][:, :]
        _frac = ds["frac"][:, :]
        _xc  = ds["xc"][:, :]
        _yc  = ds["yc"][:, :]
        _xv  = ds["xv"][:]
        _yv  = ds["yv"][:]

        _Nx  = ds.dim["ni"]
        _Ny  = ds.dim["nj"]
        close(ds)

        return new(
            R, Ω,
            _Nx, _Ny, _Nx * _Ny,
            _xc, _yc, _xv, _yv,
            _mask, _area, _frac,
            missing_value,
        )

    end

end

mutable struct CylindricalGridFile <: GridFile

    R     :: Float64
    Ω     :: Float64

    Nx    :: Integer
    Ny    :: Integer

    Ly    :: Float64
    lat0  :: Float64
    β     :: Float64
 
    mask  :: Array{Float64, 2}

    function CylindricalGridFile(;
        R :: Float64,
        Ω :: Float64,
        Nx :: Integer,
        Ny :: Integer,
        Ly :: Float64,
        lat0 :: Float64,
        β    :: Float64,
        mask :: Union{AbstractArray{Float64, 2}, Nothing} = nothing,
    )

        if mask == nothing
            mask = ones(Float64, Nx, Ny)
        end

        if size(mask) != (Nx, Ny)
            throw(ErrorException("Size of mask does not match Nx and Ny"))
        end

    
        return new(
            R, Ω,
            Nx, Ny, Ly,
            lat0, β,
            mask,
        ) 

    end

end

