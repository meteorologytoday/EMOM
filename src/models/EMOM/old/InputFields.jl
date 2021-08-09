mutable struct InputFields
    taux   :: AbstractArray{Float64, 2}
    tauy   :: AbstractArray{Float64, 2}
    nswflx :: AbstractArray{Float64, 2}
    swflx  :: AbstractArray{Float64, 2}
    sumflx :: AbstractArray{Float64, 2}
    ifrac  :: AbstractArray{Float64, 2}
    frwflx :: AbstractArray{Float64, 2}
    vsflx  :: AbstractArray{Float64, 2}
    qflx_T :: AbstractArray{Float64, 2}
    qflx_S :: AbstractArray{Float64, 2}
    Tclim  :: AbstractArray{Float64, 2}
    Sclim  :: AbstractArray{Float64, 2}
    IFRACclim  :: AbstractArray{Float64, 2}
    h_ML   :: AbstractArray{Float64, 2}
end

function InputFields(datakind::Symbol, Nx::Integer, Ny::Integer)

    return InputFields(
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
        allocate(datakind, Float64, Nx, Ny),
    )
end

function SubInputFields(
    in_flds :: InputFields,
    rngs...
)
    return InputFields(
        view( in_flds.taux,            rngs...), 
        view( in_flds.tauy,            rngs...), 
        view( in_flds.nswflx,          rngs...), 
        view( in_flds.swflx,           rngs...), 
        view( in_flds.sumflx,          rngs...), 
        view( in_flds.ifrac,           rngs...), 
        view( in_flds.frwflx,          rngs...), 
        view( in_flds.vsflx,           rngs...), 
        view( in_flds.qflx_T,          rngs...), 
        view( in_flds.qflx_S,          rngs...), 
        view( in_flds.Tclim,           rngs...), 
        view( in_flds.Sclim,           rngs...), 
        view( in_flds.IFRACclim,       rngs...), 
        view( in_flds.h_ML,            rngs...), 
    )
end

function copyfrom!(
    dst::InputFields,
    src::InputFields,
)

    for fld in (:taux, :tauy, :nswflx, :swflx, :sumflx, :ifrac, :frwflx, :vsflx, :qflx_T, :qflx_S, :Tclim, :Sclim, :IFRACclim, :h_ML)
        getfield(dst, fld)[:] = getfield(src, fld)
    end

    #=
    dst.taux[:] = src.taux
    dst.tauy[:] = src.tauy
    dst.nswflx[:] = src.nswflx
    dst.swflx[:] = src.swflx
    dst.sumflx[:] = src.sumflx
    dst.ifrac[:] = src.ifrac
    dst.frwflx[:] = src.frwflx
    dst.qflx[:] = src.qflx
    dst.h_ML[:] = src.h_ML
    =#
end

