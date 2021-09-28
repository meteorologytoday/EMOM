function data2SOM!(
    data   :: AbstractArray,
    Nz_bot :: AbstractArray{Int64, 3},
)

    _, Nx, Ny = size(Nz_bot)

    for i=1:Nx, j=1:Ny

        _Nz_bot = Nz_bot[1, i, j]

        if _Nz_bot != 0
            data[1:_Nz_bot, i, j] .= data[1, i, j]
        end

    end

end
