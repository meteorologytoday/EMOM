
function rearrangePOP2Grid(
    data     :: Array{T},
    grid     :: Symbol;
    has_time :: Bool = true,
) where T 

    dim = size(data)
    dim_len = length(dim)

    if has_time
        sdim_len = dim_len - 1
    else
        sdim_len = dim_len
    end

    if ! (sdim_len in (2, 3) )
        throw(ErrorException("I can only handle 2D and 3D data"))
    end


    Nx = dim[1]
    Ny = dim[2]
    
    # new horizontal / vertical spatial dimensions
    new_hsdim = Array{Any}(undef,0)
    new_vsdim = Array{Any}(undef,0)
    vsdim_colon = Array{Any}(undef,0)
    
    push!(new_hsdim, Nx)
    
    if grid == :V || grid == :UV
        push!(new_hsdim, Ny+1)
    else
        push!(new_hsdim, Ny)
    end

    if sdim_len == 3
        Nz = dim[3]
        push!(vsdim_colon, Colon())
        if grid == :W
            push!(new_vsdim, Nz+1)
        else
            push!(new_vsdim, Nz)
        end
    end

    dummy_dim = Array{Any}(undef,0)
    dummy_colon = Array{Any}(undef,0)

    if has_time
        Nt = dim[end]
        push!(dummy_dim, Nt)
        push!(dummy_colon, Colon())
    end

    vsdim_zero_circ = [0 for i=1:sdim_len-2]
    dummy_zero_circ = [0 for i=1:length(dummy_dim)]
        
    new_data = zeros(Float64, new_hsdim..., new_vsdim..., dummy_dim...)

    if grid == :T
        new_data[1:Nx, 1:Ny, vsdim_colon..., dummy_colon...] = data
    elseif grid == :UV
        new_data[1:Nx, 2:Ny+1, vsdim_colon..., dummy_colon...] = circshift(data, (1, 0, vsdim_zero_circ..., dummy_zero_circ...))
    elseif grid == :U
        new_data[1:Nx, 1:Ny, vsdim_colon..., dummy_colon...] = circshift(data, (1, 0, vsdim_zero_circ..., dummy_zero_circ...))
    elseif grid == :V
        new_data[1:Nx, 2:Ny+1, vsdim_colon..., dummy_colon...] = data
    elseif grid == :W
        new_data[1:Nx, 1:Ny, 1:Nz] = data
    else
        throw(ErrorException("Unknown grid: ", string(grid)))
    end

    permute_dims = [1, 2]
    if sdim_len == 3
        pushfirst!(permute_dims, 3)
    end

    if has_time
        push!(permute_dims, maximum(permute_dims)+1)  # it can be 3 or 4
    end
 
    return permutedims(new_data, permute_dims)
end
