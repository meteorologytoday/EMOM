mutable struct Topography

    topoz_sT :: Array{Float64, 3}
    Nz_bot_sT :: Array{Int64, 3}


    mask_T      :: AbstractArray{Float64, 3}
    sfcmask_sT  :: AbstractArray{Float64, 3}
    deepmask_T  :: AbstractArray{Float64, 3}

    function Topography(
        Nz_bot        :: Union{AbstractArray{Int64,2}, Nothing}, 
        Nx            :: Int64,
        Ny            :: Int64,
        z_w           :: AbstractArray{Float64, 1};
        deep_depth    :: Float64 = 500.0 
    )

        Nz = length(z_w) - 1

        sT_pts = Nx * Ny

        topoz_sT = zeros(Float64, 1, Nx, Ny)

        
        if Nz_bot == nothing
            Nz_bot_sT = zeros(Int64, 1, Nx, Ny)
            Nz_bot_sT .= length(z_w) - 1
        else
            if size(Nz_bot) != (Nx, Ny)
                throw(ErrorException(format("Size of `Nz_bot` variable is not the same as given (Nx, Ny) = ({:d}, {:d})", Nx, Ny)))
            end

            Nz_bot_sT = copy(reshape(Nz_bot, 1, Nx, Ny))

        end

        for j=1:Ny, i=1:Nx
            if Nz_bot_sT[1, i, j] > Nz
                Nz_bot_sT[1, i, j] = Nz
            end
            topoz_sT[1, i, j] = z_w[Nz_bot_sT[1, i, j]+1]
        end

        deep_Nz = lookupNz(- deep_depth, z_w)
        println(format("Water depth of {:f} m is considered as deep. The found deep_Nz = {:d}", deep_depth, deep_Nz))
        _lookupNz = (z) -> lookupNz(z, z_w)
        @. Nz_bot_sT = _lookupNz(topoz_sT)


        mask_T = ones(Float64, Nz, Nx, Ny)

        # turn the grids below topography to 0
        for j=1:Ny, i=1:Nx

            if Nz_bot_sT[1, i, j] < Nz
                mask_T[Nz_bot_sT[1, i, j]+1:end, i, j] .= 0.0
            end
        end

        sfcmask_sT = view(mask_T, 1:1, :, :)

        deepmask_T = copy(mask_T)
        # turn the entire column to 0 if it is too shallow
        for j=1:Ny, i=1:Nx
            if Nz_bot_sT[1, i, j] < deep_Nz
                deepmask_T[:, i, j] .= 0.0
            end
        end

        return new(
            topoz_sT,
            Nz_bot_sT,
            mask_T,
            sfcmask_sT,
            deepmask_T,
        ) 

    end

end

function lookupNz(z, z_w)

    max_Nz = length(z_w) - 1

    if z == 0.0
        return 0
    end

    for i=1:max_Nz-1
        if z_w[i] > z >= z_w[i+1]
            return i
        end
    end

    return max_Nz

end



