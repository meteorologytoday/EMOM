mutable struct AccumulativeVariables

    TFLUX_CONV :: AbstractArray
    SFLUX_CONV :: AbstractArray
    
    TFLUX_DEN_x :: AbstractArray
    TFLUX_DEN_y :: AbstractArray
    TFLUX_DEN_z :: AbstractArray
 
    SFLUX_DEN_x :: AbstractArray
    SFLUX_DEN_y :: AbstractArray
    SFLUX_DEN_z :: AbstractArray
    

    ∇∇T      :: AbstractArray
    ∇∇S      :: AbstractArray

    dTdt_ent :: AbstractArray
    dSdt_ent :: AbstractArray
    
    TFLUX_bot       :: AbstractArray
    SFLUX_bot       :: AbstractArray
    SFLUX_top       :: AbstractArray


    function AccumulativeVariables(Nx, Ny, Nz)
        return new(
            zeros(Nz, Nx, Ny),
            zeros(Nz, Nx, Ny),
            zeros(Nz, Nx, Ny),
            zeros(Nz, Nx, Ny+1),
            zeros(Nz+1, Nx, Ny),
            zeros(Nz, Nx, Ny),
            zeros(Nz, Nx, Ny+1),
            zeros(Nz+1, Nx, Ny),
            zeros(Nz, Nx, Ny),
            zeros(Nz, Nx, Ny),
            zeros(Nx, Ny),
            zeros(Nx, Ny),
            zeros(Nx, Ny),
            zeros(Nx, Ny),
            zeros(Nx, Ny),
        )
    end

end


