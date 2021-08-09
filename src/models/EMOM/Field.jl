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
    
    _WKRST_   :: AbstractArray{Float64, 2}
    _VDIFF_   :: AbstractArray{Float64, 2}


    HMXL     :: AbstractArray{Float64, 3}

    SWFLX    :: AbstractArray{Float64, 3}
    NSWFLX   :: AbstractArray{Float64, 3}
    VSFLX    :: AbstractArray{Float64, 3}
 
    TAUX         :: AbstractArray{Float64, 3}
    TAUY         :: AbstractArray{Float64, 3}
   
    TAUX_east    :: AbstractArray{Float64, 3}
    TAUY_north   :: AbstractArray{Float64, 3}

    Q_FRZHEAT       :: AbstractArray{Float64, 3}
    Q_FRZMLTPOT_NEG :: AbstractArray{Float64, 3}
    Q_FRZMLTPOT     :: AbstractArray{Float64, 3}

    datastream   :: Union{Dict, Nothing}

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

        _WKRST_ = zeros(Float64, T_pts, 2)
 
        _VDIFF_ = zeros(Float64, T_pts, 2)

        HMXL = zeros(Float64, 1, Nx, Ny)
        SWFLX = zeros(Float64, 1, Nx, Ny)
        NSWFLX = zeros(Float64, 1, Nx, Ny)
        VSFLX = zeros(Float64, 1, Nx, Ny)
        TAUX_east = zeros(Float64, 1, Nx, Ny)
        TAUY_north = zeros(Float64, 1, Nx, Ny)
 
        TAUX = zeros(Float64, 1, Nx, Ny)
        TAUY = zeros(Float64, 1, Nx, Ny)
        
        Q_FRZHEAT       = zeros(Float64, 1, Nx, Ny)
        Q_FRZMLTPOT_NEG = zeros(Float64, 1, Nx, Ny)
        Q_FRZMLTPOT     = zeros(Float64, 1, Nx, Ny)
 
         
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
            _WKRST_,
            _VDIFF_,

            HMXL,

            SWFLX,
            NSWFLX,
            VSFLX,

            TAUX,
            TAUY,

            TAUX_east,
            TAUY_north,

            Q_FRZHEAT,
            Q_FRZMLTPOT_NEG,
            Q_FRZMLTPOT,

            nothing,
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
        :TEMP => reshape(view(fi._X_, :, 1), Nz, Nx, Ny),
        :SALT => reshape(view(fi._X_, :, 2), Nz, Nx, Ny),
        :_TEMP => view(fi._X_, :, 1),
        :_SALT => view(fi._X_, :, 2), 
        :UVEL => reshape(fi._u, Nz, Nx, Ny),
        :VVEL => reshape(fi._v, Nz, Nx, Ny+1),
        :WVEL => reshape(fi._w, Nz+1, Nx, Ny),
        :ADVT => reshape(view(fi._ADVX_, :, 1), Nz, Nx, Ny),
    )
        
    sv[:SST] = view(sv[:TEMP], 1:1, :, :)
    
    return sv
end
