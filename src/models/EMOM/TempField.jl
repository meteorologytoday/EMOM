mutable struct TempField 

    _NEWX_    :: AbstractArray{Float64, 2}
    _INTMX_    :: AbstractArray{Float64, 2}
    _ΔX_       :: AbstractArray{Float64, 2}
    _WKRSTΔX_   :: AbstractArray{Float64, 2}

    _CHKX_   :: AbstractArray{Float64, 2}
    _CHKX    :: AbstractArray{Float64, 1}

    _TMP_CHKX_   :: AbstractArray{Float64, 2} # Used to store the ∫ X dz before steping
    _TMP_CHKX    :: AbstractArray{Float64, 1}

    _TMP_SUBSTEP_BUDGET_   :: AbstractArray{Float64, 2} # Used to store substep tracer budget

    op_vdiff :: Union{AbstractArray, Nothing}
    sv       :: Union{Dict, Nothing}
    
    datastream   :: Union{Dict, Nothing}
    
    check_usage :: Dict

    function TempField(
        ev :: Env,
    )

        Nz, Nx, Ny = ev.Nz, ev.Nx, ev.Ny
        
        
        sT_pts = Nx * Ny * 1
        T_pts = Nx * Ny * Nz
        U_pts = Nx * Ny * Nz
        V_pts = Nx * (Ny+1) * Nz
        W_pts = Nx * Ny * (Nz+1)

        _NEWX_  = zeros(Float64, T_pts, 2)
        _INTMX_ = zeros(Float64, T_pts, 2)
        _ΔX_    = zeros(Float64, T_pts, 2)
        _WKRSTΔX_    = zeros(Float64, T_pts, 2)
        
        _CHKX_ = zeros(Float64, sT_pts, 2)
        _CHKX  = view(_CHKX_, :)
 
        _TMP_CHKX_ = zeros(Float64, sT_pts, 2)
        _TMP_CHKX  = view(_TMP_CHKX_, :)
    
        _TMP_SUBSTEP_BUDGET_ = zeros(Float64, sT_pts, 2)

        check_usage = Dict(
            :Ks_H_U => zeros(Nz, Nx, Ny),
            :Ks_H_V => zeros(Nz, Nx, Ny+1),
        )
        
        tmpfi = new(

            _NEWX_,
            _INTMX_,
            _ΔX_,
            _WKRSTΔX_,

            _CHKX_,
            _CHKX,

            _TMP_CHKX_,
            _TMP_CHKX,

            _TMP_SUBSTEP_BUDGET_,

            nothing,
            nothing,
            nothing,

            check_usage,
        )

        tmpfi.sv = getSugarView(ev, tmpfi)

        return tmpfi

    end

end

function getSugarView(
    ev :: Env,
    tmpfi :: TempField,
)

    Nx, Ny, Nz = ev.Nx, ev.Ny, ev.Nz

    return sv = Dict(
        :CHKTEMP  => reshape(view(tmpfi._CHKX_, :, 1), 1, Nx, Ny),
        :CHKSALT  => reshape(view(tmpfi._CHKX_, :, 2), 1, Nx, Ny),
        :NEWTEMP  => reshape(view(tmpfi._NEWX_, :, 1), Nz, Nx, Ny),
        :NEWSALT  => reshape(view(tmpfi._NEWX_, :, 2), Nz, Nx, Ny),
        :INTMTEMP => reshape(view(tmpfi._INTMX_, :, 1), Nz, Nx, Ny),
        :INTMSALT => reshape(view(tmpfi._INTMX_, :, 2), Nz, Nx, Ny),
    )


end
