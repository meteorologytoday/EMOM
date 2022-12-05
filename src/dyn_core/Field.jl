mutable struct Field 

    _X_      :: AbstractArray{Float64, 2}
    _X       :: AbstractArray{Float64, 1}

    _b       :: AbstractArray{Float64, 1}
    
    _vel      :: AbstractArray{Float64, 1}
    _u        :: AbstractArray{Float64, 1}
    _v        :: AbstractArray{Float64, 1}
    _w        :: AbstractArray{Float64, 1}

    _Xflx_U_  :: AbstractArray{Float64, 2}
    _Xflx_V_  :: AbstractArray{Float64, 2}
    _Xflx_W_  :: AbstractArray{Float64, 2}

    _ADVX_    :: AbstractArray{Float64, 2}
    
    _WKRSTX_   :: AbstractArray{Float64, 2}
    _VDIFFX_   :: AbstractArray{Float64, 2}
    _QFLXX_    :: AbstractArray{Float64, 2}


    HMXL    :: AbstractArray{Float64, 3}
    USFC    :: AbstractArray{Float64, 3}
    VSFC    :: AbstractArray{Float64, 3}

    SWFLX   :: AbstractArray{Float64, 3}
    NSWFLX  :: AbstractArray{Float64, 3}
    VSFLX   :: AbstractArray{Float64, 3}
 
    LWUP    :: AbstractArray{Float64, 3}
    LWDN    :: AbstractArray{Float64, 3}
    SEN     :: AbstractArray{Float64, 3}
    LAT     :: AbstractArray{Float64, 3}
    MELTH   :: AbstractArray{Float64, 3}

    MELTW   :: AbstractArray{Float64, 3}
    SNOW    :: AbstractArray{Float64, 3}
    IOFF    :: AbstractArray{Float64, 3}
    ROFF    :: AbstractArray{Float64, 3}
    EVAP    :: AbstractArray{Float64, 3}
    PREC    :: AbstractArray{Float64, 3}
    
    SALTFLX :: AbstractArray{Float64, 3}


    TAUX         :: AbstractArray{Float64, 3}
    TAUY         :: AbstractArray{Float64, 3}
   
    TAUX_east    :: AbstractArray{Float64, 3}
    TAUY_north   :: AbstractArray{Float64, 3}

    Q_FRZHEAT       :: AbstractArray{Float64, 3}
    Q_FRZMLTPOT_NEG :: AbstractArray{Float64, 3}
    Q_FRZMLTPOT     :: AbstractArray{Float64, 3}
    Q_FRZHEAT_OVERFLOW  :: AbstractArray{Float64, 3}


    # sugar view
    sv       :: Union{Nothing, Dict} 


    function Field(
        ev :: Env,
    )

        Nz, Nx, Ny = ev.Nz, ev.Nx, ev.Ny
        
        T_pts = Nx * Ny * Nz
        U_pts = Nx * Ny * Nz
        V_pts = Nx * (Ny+1) * Nz
        W_pts = Nx * Ny * (Nz+1)

        _X_ = zeros(Float64, T_pts, 2)
        _X  = view(_X_, :)
        
        _b  = zeros(Float64, T_pts)

        sT_pts = Nx * Ny * 1

 
        _vel = zeros(Float64, U_pts + V_pts + W_pts)

        idx = 0;
        _u = view(_vel, (idx+1):(idx+U_pts)) ; idx+=U_pts
        _v = view(_vel, (idx+1):(idx+V_pts)) ; idx+=V_pts
        _w = view(_vel, (idx+1):(idx+W_pts)) ; idx+=W_pts

        _Xflx_U_ = zeros(Float64, U_pts, 2)
        _Xflx_V_ = zeros(Float64, V_pts, 2)
        _Xflx_W_ = zeros(Float64, W_pts, 2)
        
        _ADVX_ = zeros(Float64, T_pts, 2)

        _WKRSTX_ = zeros(Float64, T_pts, 2)
 
        _VDIFFX_ = zeros(Float64, T_pts, 2)
        _QFLXX_  = zeros(Float64, T_pts, 2)

        HMXL = zeros(Float64, 1, Nx, Ny)
        USFC = zeros(Float64, 1, Nx, Ny)   # Notice that USFC is on T grid
        VSFC = zeros(Float64, 1, Nx, Ny)   # Notice that VSFC is on T grid
        SWFLX = zeros(Float64, 1, Nx, Ny)
        NSWFLX = zeros(Float64, 1, Nx, Ny)
        VSFLX = zeros(Float64, 1, Nx, Ny)
        
        LWUP = zeros(Float64, 1, Nx, Ny)
        LWDN = zeros(Float64, 1, Nx, Ny)
        SEN = zeros(Float64, 1, Nx, Ny)
        LAT = zeros(Float64, 1, Nx, Ny)
        MELTH = zeros(Float64, 1, Nx, Ny)
        MELTW = zeros(Float64, 1, Nx, Ny)
        SNOW  = zeros(Float64, 1, Nx, Ny)
        IOFF  = zeros(Float64, 1, Nx, Ny)
        ROFF  = zeros(Float64, 1, Nx, Ny)
        EVAP  = zeros(Float64, 1, Nx, Ny)
        PREC  = zeros(Float64, 1, Nx, Ny)
        SALTFLX = zeros(Float64, 1, Nx, Ny)

        TAUX_east = zeros(Float64, 1, Nx, Ny)
        TAUY_north = zeros(Float64, 1, Nx, Ny)
 
        TAUX = zeros(Float64, 1, Nx, Ny)
        TAUY = zeros(Float64, 1, Nx, Ny)
        
        Q_FRZHEAT       = zeros(Float64, 1, Nx, Ny)
        Q_FRZMLTPOT_NEG = zeros(Float64, 1, Nx, Ny)
        Q_FRZMLTPOT     = zeros(Float64, 1, Nx, Ny)
        Q_FRZHEAT_OVERFLOW  = zeros(Float64, 1, Nx, Ny)
 
         
        fi = new(

            _X_,
            _X,

            _b,

            _vel,
            _u,
            _v,
            _w,

            _Xflx_U_,
            _Xflx_V_,
            _Xflx_W_,

            _ADVX_,
            _WKRSTX_,
            _VDIFFX_,
            _QFLXX_,

            HMXL,
            USFC,
            VSFC,

            SWFLX,
            NSWFLX,
            VSFLX,

            LWUP,
            LWDN,
            SEN,
            LAT,
            MELTH,

            MELTW,
            SNOW,
            IOFF,
            ROFF,
            EVAP,
            PREC,
            SALTFLX,

            TAUX,
            TAUY,

            TAUX_east,
            TAUY_north,

            Q_FRZHEAT,
            Q_FRZMLTPOT_NEG,
            Q_FRZMLTPOT,
            Q_FRZHEAT_OVERFLOW,

            nothing,
        )

        fi.sv = getSugarView(ev, fi)

        return fi

    end

end

function getSugarView(
    ev :: Env,
    fi :: Field,
)

    Nx, Ny, Nz = ev.Nx, ev.Ny, ev.Nz

    sv = Dict(
        :TEMP   => reshape(view(fi._X_, :, 1), Nz, Nx, Ny),
        :SALT   => reshape(view(fi._X_, :, 2), Nz, Nx, Ny),
        :_TEMP  => view(fi._X_, :, 1),
        :_SALT  => view(fi._X_, :, 2), 
        :UVEL   => reshape(fi._u, Nz, Nx, Ny),
        :VVEL   => reshape(fi._v, Nz, Nx, Ny+1),
        :WVEL   => reshape(fi._w, Nz+1, Nx, Ny),
        :ADVT   => reshape(view(fi._ADVX_, :, 1), Nz, Nx, Ny),
        :ADVS   => reshape(view(fi._ADVX_, :, 2), Nz, Nx, Ny),
        :VDIFFT => reshape(view(fi._VDIFFX_, :, 1), Nz, Nx, Ny),
        :VDIFFS => reshape(view(fi._VDIFFX_, :, 2), Nz, Nx, Ny),
        :WKRSTT => reshape(view(fi._WKRSTX_, :, 1), Nz, Nx, Ny),
        :WKRSTS => reshape(view(fi._WKRSTX_, :, 2), Nz, Nx, Ny),
        :QFLXT  => reshape(view(fi._QFLXX_, :, 1), Nz, Nx, Ny),
        :QFLXS  => reshape(view(fi._QFLXX_, :, 2), Nz, Nx, Ny),
    )
        
    sv[:SST] = view(sv[:TEMP], 1:1, :, :)
    sv[:SSS] = view(sv[:SALT], 1:1, :, :)
    #sv[:USFC] = view(sv[:UVEL], 1:1, :, :)
    #sv[:VSFC] = view(sv[:VVEL], 1:1, :, :)
    
    return sv
end
