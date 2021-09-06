include("MapTransform/MapTransform.jl")

using JSON
using .MapTransform
using NCDatasets
using Formatting
using ArgParse
using LaTeXStrings

missing2nan  = (x,) -> nomissing(x, NaN)
missing2zero = (x,) -> nomissing(x, 0.0)

ρcp = 1026.0 * 3996.0

function parse_commandline()

    s = ArgParseSettings()

    @add_arg_table s begin

        "--input-file"
            help = "Ocean history file."
            arg_type = String
            required = true

        "--output-img"
            help = "Output image name."
            arg_type = String
            default = ""

        "--no-display"
            help = ""
            action = :store_true


    end

    return parse_args(s)
end

parsed = parse_commandline()

JSON.print(parsed, 4)

Dataset(parsed["input-file"], "r") do ds

    global Nx = ds.dim["Nx"]
    global Ny = ds.dim["Ny"]
    global Nz = ds.dim["Nz"]
    global Nt = ds.dim["time"]

    global dz_cT   = reshape(nomissing(ds["dz_cT"][:], 0), 1, 1, Nz)
    global dσ_sT   = reshape(nomissing(ds["area_sT"][:], 0), Nx, Ny)
    global ϕ_sT    = reshape(nomissing(ds["lat_sT"][:], 0), Nx, Ny)
    global mask_sT = reshape(nomissing(ds["mask_sT"][:], 0), Nx, Ny)

    global ADVT   = nomissing(ds["ADVT"][:], 0.0)
    global WKRSTT = nomissing(ds["WKRSTT"][:], 0.0)

end




lat_v = range(-90.0, 90.0, length=181) |> collect
lat_t = (lat_v[1:end-1] + lat_v[2:end]) / 2.0
r = MapTransform.Relation(;
    lat     = ϕ_sT,
    area    = dσ_sT,
    mask    = mask_sT,
    lat_bnd = lat_v,
)

using PyCall
import PyPlot as plt

if parsed["no-display"]
    pygui(false)
else
    pygui(true)
end


fig, ax = plt.subplots(2, 1, sharex=true, constrained_layout=true)

fig.suptitle(parsed["input-file"])

for t=1:Nt

    _ADVT   = view(ADVT, :, :, :, t)
    HFC_ADV = sum(_ADVT .* dz_cT, dims=3)[:, :, 1]  * ρcp # HFC = Heat Flux Convergence

    HFC_ADV_t =   MapTransform.transform(r, HFC_ADV)
    OHT_ADV_v = - MapTransform.∫∂a(r, HFC_ADV)

    
    _WKRSTT = view(WKRSTT, :, :, :, t)
    HFC_WKRST = sum(_WKRSTT .* dz_cT, dims=3)[:, :, 1]  * ρcp # HFC = Heat Flux Convergence
    
    HFC_WKRST_t =   MapTransform.transform(r, HFC_WKRST)
    OHT_WKRST_v = - MapTransform.∫∂a(r, HFC_WKRST)


#    ax[1].scatter(lat_t, HFC_ADV_t)
   
    HFC_ADV_t[isnan.(HFC_ADV_t)] .= 0

    ax[1].plot(lat_t, HFC_ADV_t,   "r--", label="ADV")
    ax[1].plot(lat_t, HFC_WKRST_t, "b--", label="WKRST")
    ax[1].plot(lat_t, HFC_ADV_t + HFC_WKRST_t, "k-", label="SUM")

    ax[2].plot(lat_v, OHT_ADV_v / 1e15, "r--")
    ax[2].plot(lat_v, OHT_WKRST_v / 1e15, "b--")
    ax[2].plot(lat_v, (OHT_ADV_v + OHT_WKRST_v) / 1e15, "k-")

end
ax[1].legend()
ax[1].grid(true)
ax[2].grid(true)
ax[2].set_ylim([-6, 8])

ax[1].set_ylabel(L"[$ \mathrm{W} / \mathrm{m}^2 $]")
ax[2].set_ylabel(L"[$ \mathrm{PW} $]")



if parsed["output-img"] != ""
    println("Output image: ", parsed["output-img"])
    fig.savefig(parsed["output-img"], dpi=150)
end

if ! parsed["no-display"]
    println("Showing image...")
    plt.show()
end



