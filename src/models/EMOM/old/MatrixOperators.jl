using SparseArrays

@inline function speye(dtype, n)
    return spdiagm(0=>ones(dtype, n))
end

struct SparseMatrixBuilder
    I :: AbstractArray{Int64, 1}
    J :: AbstractArray{Int64, 1}
    V :: AbstractArray{Float64, 1}
    idx :: Int64
    
    function SparseMatrixBuilder(elm_max)
        return new(
            zeros(Int64, elm_max),
            zeros(Int64, elm_max),
            zeros(Float64, elm_max),
            1
        )
    end
end

function getSparse!(
    smb::SparseMatrixBuilder,
    m::Int64,
    n::Int64,
)
    mtx = sparse(
        view(I, 1:smb.idx),
        view(J, 1:smb.idx),
        view(V, 1:smb.idx),
        m, n
    )
    smb.idx = 1
    return mtx 
end


function add!(
    smb::SparseMatrixBuilder,
    i::Int64,
    j::Int64,
    v::Float64,
)
    I[smb.idx] = i
    J[smb.idx] = j
    V[smb.idx] = v
    smb.idx += 1
end




# Assuming x-direction is periodic
struct MatrixOperators

    U_pts
    V_pts
    W_pts
    T_pts
    F_pts


    # Nomenclature:
    #
    # [new-grid][direction][old-grid]
    #
    # U_W_T : sending variable westward from T grid to U grid

    U_I_U
    V_I_V
    T_I_T
    F_I_F

    U_W_T
    U_E_T
    U_W_U
    U_E_U
    V_W_V
    V_E_V
    V_W_F
    V_E_F

    V_S_T
    V_N_T
    U_S_U
    U_N_U
    V_S_V
    V_N_V
    U_S_F
    U_N_F

    T_S_V
    T_N_V
    T_W_U
    T_E_U 
   
    F_E_V
    F_W_V
    F_N_U
    F_S_U
 
    U_SW_V
    U_SE_V
    U_NW_V
    U_NE_V
    V_SW_U
    V_SE_U
    V_NW_U
    V_NE_U

    T_SW_F
    T_SE_F
    T_NW_F
    T_NE_F

    F_SW_T
    F_SE_T
    F_NW_T
    F_NE_T

    T_N_T
    T_S_T
    T_E_T
    T_W_T

    T_UP_T
    T_DN_T
    U_UP_U
    U_DN_U
    V_UP_V
    V_DN_V
 
    T_UP_W
    T_DN_W

    W_UP_T
    W_DN_T

    function MatrixOperators(;
        Nx             :: Int64,
        Ny             :: Int64,
        Nz             :: Int64,
    )

       #println("Making MatrixOperators")
        # Making operator
        U_dim = (Nz, Nx, Ny)
        V_dim = (Nz, Nx, Ny+1)
        W_dim = (Nz+1, Nx, Ny)
        T_dim = (Nz, Nx, Ny)
        F_dim = (Nz, Nx, Ny+1)

        U_pts = reduce(*, U_dim)
        V_pts = reduce(*, V_dim)
        W_pts = reduce(*, W_dim)
        T_pts = reduce(*, T_dim)
        F_pts = reduce(*, F_dim)

        U_I_U = speye(Float64, U_pts)
        V_I_V = speye(Float64, V_pts)
        W_I_W = speye(Float64, W_pts)
        T_I_T = speye(Float64, T_pts)
        F_I_F = speye(Float64, F_pts)

        U_I_U_expand = vcat(U_I_U, zeros(Float64, 1, U_pts))
        V_I_V_expand = vcat(V_I_V, zeros(Float64, 1, V_pts))
        W_I_W_expand = vcat(W_I_W, zeros(Float64, 1, W_pts))
        T_I_T_expand = vcat(T_I_T, zeros(Float64, 1, T_pts))
        F_I_F_expand = vcat(F_I_F, zeros(Float64, 1, F_pts))


        num_U = zeros(Int64, U_dim...)
        num_V = zeros(Int64, V_dim...)
        num_W = zeros(Int64, W_dim...)
        num_T = zeros(Int64, T_dim...)
        num_F = zeros(Int64, F_dim...)

        num_U[:] = 1:length(num_U)
        num_V[:] = 1:length(num_V)
        num_W[:] = 1:length(num_W)
        num_T[:] = 1:length(num_T)
        num_F[:] = 1:length(num_F)
        
        U = num_U * 0
        V = num_V * 0
        W = num_W * 0
        T = num_T * 0
        F = num_T * 0

        #smb = SparseMatrixBuilder(Nx*(Ny+1)*(Nz+1)*4)
        function build!(id_mtx, idx; wipe=:none)
           #println("Build!")
            local result
            rows = size(id_mtx)[1]
            if wipe == :n
                idx[:, :, end] .= rows
            elseif wipe == :s
                idx[:, :,   1] .= rows
            elseif wipe == :t
                idx[1, :,   :] .= rows
            elseif wipe == :b
                idx[end, :, :] .= rows
            elseif wipe != :none
                throw(ErrorException("Wrong keyword"))
            end
           
            # using transpose speeds up by 100 times 
            tp = transpose(id_mtx) |> sparse
            result = transpose(tp[:, view(idx, :)]) |> sparse
            #result = id_mtx[view(idx, :), :]
            #dropzeros!(result)

            idx .= 0 # clean so that debug is easir when some girds are not assigned
            return result
        end

        
       #println("Making shifting operators")
        # east, west passing mtx
        U[:, :, :] = num_T;                             U_W_T = build!(T_I_T, U)
        U[:, :, :] = circshift(num_T, (0, 1, 0));       U_E_T = build!(T_I_T, U)

        U[:] = circshift(num_U, (0, -1, 0));            U_W_U = build!(U_I_U, U)
        U[:] = circshift(num_U, (0,  1, 0));            U_E_U = build!(U_I_U, U)

        V[:] = circshift(num_V, (0, -1, 0));            V_W_V = build!(V_I_V, V)
        V[:] = circshift(num_V, (0,  1, 0));            V_E_V = build!(V_I_V, V)
 
        V[:, :, :] = circshift(num_F, (0, -1, 0));      V_W_F = build!(F_I_F, V)
        V[:, :, :] = num_F;                             V_E_F = build!(F_I_F, V)
 
        # north, south passing mtx
        V[:, :, 1:Ny]   = num_T;                        V_S_T = build!(T_I_T_expand, V; wipe=:n)
        V[:, :, 2:Ny+1] = num_T;                        V_N_T = build!(T_I_T_expand, V; wipe=:s)

        U[:, :, 1:Ny-1] = view(num_U, :, :, 2:Ny  );    U_S_U = build!(U_I_U_expand, U; wipe=:n)
        U[:, :, 2:Ny]   = view(num_U, :, :, 1:Ny-1);    U_N_U = build!(U_I_U_expand, U; wipe=:s)
        
        V[:, :, 1:Ny]   = view(num_V, :, :, 2:Ny+1);    V_S_V = build!(V_I_V_expand, V; wipe=:n)
        V[:, :, 2:Ny+1] = view(num_V, :, :, 1:Ny  );    V_N_V = build!(V_I_V_expand, V; wipe=:s)

        U[:, :, :]      = view(num_F, :, :, 2:Ny+1);    U_S_F = build!(F_I_F, U)
        U[:, :, :]      = view(num_F, :, :, 1:Ny  );    U_N_F = build!(F_I_F, U)


        # inverse directions
        T_S_V = V_N_T' |> sparse
        T_N_V = V_S_T' |> sparse
        T_W_U = U_E_T' |> sparse
        T_E_U = U_W_T' |> sparse

        F_E_V = V_W_F' |> sparse
        F_W_V = V_E_F' |> sparse
        F_N_U = U_S_F' |> sparse
        F_S_U = U_N_F' |> sparse

        # diagonal passing mtx        
        U_SW_V = U_W_T * T_S_V
        U_SE_V = U_E_T * T_S_V
        U_NW_V = U_W_T * T_N_V
        U_NE_V = U_E_T * T_N_V

        V_SW_U = V_S_T * T_W_U
        V_SE_U = V_S_T * T_E_U
        V_NW_U = V_N_T * T_W_U
        V_NE_U = V_N_T * T_E_U

        T_SW_F = T_S_V * V_W_F
        T_SE_F = T_S_V * V_E_F
        T_NW_F = T_N_V * V_W_F
        T_NE_F = T_N_V * V_E_F

        F_SW_T = T_NE_F' |> sparse
        F_SE_T = T_NW_F' |> sparse
        F_NW_T = T_SE_F' |> sparse
        F_NE_T = T_SW_F' |> sparse



        # T to T operators
        T_N_T = T_N_V * V_N_T
        T_S_T = T_S_V * V_S_T
        T_E_T = T_E_U * U_E_T
        T_W_T = T_W_U * U_W_T


        # upward, downward passing mtx
        T[1:Nz-1, :, :] = view(num_T, 2:Nz, :, :);    T_UP_T = build!(T_I_T_expand, T; wipe=:b)
        T[2:Nz, :, :] = view(num_T, 1:Nz-1, :, :);    T_DN_T = build!(T_I_T_expand, T; wipe=:t)

        U[1:Nz-1, :, :] = view(num_U, 2:Nz, :, :);    U_UP_U = build!(U_I_U_expand, U; wipe=:b)
        U[2:Nz, :, :] = view(num_U, 1:Nz-1, :, :);    U_DN_U = build!(U_I_U_expand, U; wipe=:t)

        V[1:Nz-1, :, :] = view(num_V, 2:Nz, :, :);    V_UP_V = build!(V_I_V_expand, V; wipe=:b)
        V[2:Nz, :, :] = view(num_V, 1:Nz-1, :, :);    V_DN_V = build!(V_I_V_expand, V; wipe=:t)

        T[:, :, :] = view(num_W, 2:Nz+1, :, :);       T_UP_W = build!(W_I_W_expand, T)
        T[:, :, :] = view(num_W, 1:Nz, :, :);         T_DN_W = build!(W_I_W_expand, T)

        # inverse directions
        W_DN_T = T_UP_W' |> sparse
        W_UP_T = T_DN_W' |> sparse

        return new(
            U_pts, V_pts, W_pts, T_pts, F_pts,
            U_I_U, V_I_V, T_I_T, F_I_F,

            U_W_T, U_E_T,
            U_W_U, U_E_U,
            V_W_V, V_E_V,
            V_W_F, V_E_F,

            V_S_T, V_N_T,
            U_S_U, U_N_U,
            V_S_V, V_N_V,
            U_S_F, U_N_F,

            T_S_V, T_N_V,
            T_W_U, T_E_U,

            F_E_V, F_W_V,
            F_N_U, F_S_U,

            U_SW_V, U_SE_V,
            U_NW_V, U_NE_V,
            V_SW_U, V_SE_U,
            V_NW_U, V_NE_U,

            T_SW_F, T_SE_F,
            T_NW_F, T_NE_F,

            F_SW_T, F_SE_T,
            F_NW_T, F_NE_T,


            T_N_T, T_S_T,
            T_E_T, T_W_T,
            
            T_UP_T, T_DN_T,
            U_UP_U, U_DN_U,
            V_UP_V, V_DN_V,
            T_UP_W, T_DN_W,
            W_UP_T, W_DN_T,
        )

    end
end
