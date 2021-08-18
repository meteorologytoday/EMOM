include(normpath(joinpath(@__DIR__, "IOM", "src", "models", "EMOM", "EMOM.jl")))
using NCDatasets
using MPI

MPI.Init()

println("Processing data...")

include("config.jl")

init_POP_file = config[:MODEL_CORE][:cdata_file]
domain_file = config[:MODEL_CORE][:domain_file]

zdomain_file = init_POP_file
output_file = config[:MODEL_MISC][:init_file]

N_layers = length(config[:MODEL_CORE][:z_w]) - 1 # Layers used. Thickness ≈ 503m

Dataset(domain_file, "r") do ds
    global Nx = ds.dim["ni"]
    global Ny = ds.dim["nj"]
    global mask = ds["mask"][:]
end

Dataset(init_POP_file, "r") do ds
    global TEMP  = permutedims(nomissing(ds["TEMP"][:, :, 1:N_layers, 1],  NaN), [3, 1, 2])
    global SALT  = permutedims(nomissing(ds["SALT"][:, :, 1:N_layers, 1],  NaN), [3, 1, 2])
end

Dataset(zdomain_file, "r") do ds
    global z_w  = - ds["z_w"][:] / 100.0
    global Nz = length(z_w) - 1
end

Nz_bot = zeros(Int64, Nx, Ny)
mask_T = zeros(Float64, Nz, Nx, Ny)
mask_T[isfinite.(TEMP)] .= 1.0
valid_idx = mask_T .== 1.0

Nz_bot .= sum(mask_T, dims=1)[1, :, :]


ev = EMOM.Env(config[:MODEL_CORE])
mb = EMOM.ModelBlock(ev; init_core=false)

mb.fi.sv[:TEMP][valid_idx] .= TEMP[valid_idx]
mb.fi.sv[:SALT][valid_idx] .= SALT[valid_idx]

mb.fi.sv[:TEMP][valid_idx] .= 30
mb.fi.sv[:SALT][valid_idx] .= 35





Dataset("z_w.nc", "c") do ds

    defDim(ds, "Nzp1", Nz+1)

    defVar(ds, "z_w", z_w, ("Nzp1", ), ; attrib = Dict(
        "long_name" => "Vertical coordinate on W-grid",
        "units"     => "m",
    ))

end


Dataset("Nz_bot.nc", "c") do ds

    defDim(ds, "Nx", Nx)
    defDim(ds, "Ny", Ny)
    defVar(ds, "Nz_bot", Nz_bot, ("Nx", "Ny", ), ; attrib = Dict(
        "long_name" => "z-grid idx of the deepest cell",
        "units"     => "none",
    ))

end



EMOM.takeSnapshot(DateTimeNoLeap(1,1,1), mb, output_file)
