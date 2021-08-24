include("lib/PolelikeCoordinate.jl")
include("lib/BasicMatrixOperators.jl")
include("lib/AdvancedMatrixOperators.jl")
include("lib/Pop2Coord.jl")
include("lib/MapTransform.jl")

using ArgParse, JSON
using NCDatasets
using Formatting
using .PolelikeCoordinate
using SparseArrays: spdiagm

missing2nan  = (x,) -> nomissing(x, NaN)
missing2zero = (x,) -> nomissing(x, 0.0)

function parse_commandline()

    s = ArgParseSettings()
    @add_arg_table s begin
 
        "--input-dir"
            help = "Input directory"

        "--input-files"
            help = "Input files delimited by comma."
            arg_type = String
            required = true
 
        "--output-dir"
            help = "Output directory."
            arg_type = String
            required = true

        "--domain-file"
            help = "Domain file."
            arg_type = String
            required = true
 
        "--Ekman-layers"
            help = "Number of layers that is Ekman velocity."
            arg_type = Int64
            required = true
 
        "--total-layers"
            help = "Number of layers summing Ekman layers and return flow layers."
            arg_type = Int64
            required = true
 
        "--ref-file"
            help = "File containing coordinate."
            arg_type = String
            default = ""
 
    end

    return parse_args(ARGS, s)
end

if ! isdefined(Main, :parsed)
    parsed = parse_commandline()
end

print(json(parsed, 4))

input_files = split(parsed["input-files"], ",")
sub_zrng = 1:40

if parsed["ref-file"] == ""
    ref_file = joinpath(parsed["input-dir"], input_files[1])
else
    ref_file = parsed["ref-file"] 
end

Dataset(ref_file, "r") do ds

    TEMP   = rearrangePOP2Grid(ds["TEMP"][:, :, sub_zrng, :]  |> missing2nan,  :T; has_time=true)
    H_T    = rearrangePOP2Grid(ds["HT"][:] |> missing2zero, :T; has_time=false) / 100.0

    
    z_w_top = - ds["z_w_top"][sub_zrng] / 100.0 |> missing2nan
    z_w_bot = - ds["z_w_bot"][sub_zrng] / 100.0 |> missing2nan

    global Nz, Nx, Ny, _ = size(TEMP)
    global z_w = zeros(Float64, Nz+1)
    z_w[1:end-1] = z_w_top
    z_w[end] = z_w_bot[end]

    global mask_T    = zeros(Float64, Nz, Nx, Ny)
    mask_T[isfinite.(view(TEMP, :, :, :, 1))] .= 1.0

    global mask_T_inactive_idx = (mask_T .== 0.0)

    invH_T = H_T.^(-1.0)
    invH_T[isinf.(invH_T) .| isnan.(invH_T)] .= 0.0
    global T_invH_T = spdiagm( 0 => invH_T[:] )


    # Integration in different ocean
    REGION_MASK = rearrangePOP2Grid((ds["REGION_MASK"][:]*1.0) |> missing2nan, :T; has_time=false)

    global mask_ATL_sT = REGION_MASK * 0.0
    global mask_ATL_sT[REGION_MASK .>= 6] .= 1    

    global mask_INDPAC_sT = REGION_MASK * 0.0
    global mask_INDPAC_sT[(REGION_MASK .<= 4) .& (REGION_MASK .>= 2)] .= 1


end

println("Loading MapInfo")
grid_file = PolelikeCoordinate.CurvilinearSphericalGridFile(
    parsed["domain-file"];
    R  = 6371229.0,
    Ω  = 2π / (86400 / (1 + 365/365)),
)

println("Making slab grid")
gd_slab = PolelikeCoordinate.genGrid(
    grid_file,
    [0, -1.0];  # fake z_w grid
)

println("Making 3D sub_zrng grid")
gd = PolelikeCoordinate.genGrid(
    grid_file,
    z_w, #, -2.0];  # fake z_w grid
)


println("Test if slab AMO is there")
if ! isdefined(Main, :amo_slab)
    println("Construct slab AMO")
    @time amo_slab = AdvancedMatrixOperators(;
        gd = gd_slab,
        mask_T = mask_T[1:1, :, :],
    )
end
println("Slab AMO and BMO constructed")


println("Test if 3D AMO sub_zrng is there")
if ! isdefined(Main, :amo)
    println("Construct AMO")
    @time amo = AdvancedMatrixOperators(;
        gd = gd,
        mask_T = mask_T,
    )
end
println("3D AMO and BMO constructed")

println("Setup Ekman transport configuration")
# Ekman transport setup
ϵ_uv = ones(Float64, Nx, Ny+1) * 1e-5
f_uv = 2 * gd.Ω * sin.(gd.ϕ_UV[1, :, :])
β_uv = 2 * gd.Ω * cos.(gd.ϕ_UV[1, :, :]) / gd.R

ρ0 = 1026.0
cp = 3996.0
ρ0s2 = ρ0 * (ϵ_uv.^2.0 + f_uv.^2.0) 

#Nlayers_Ek = 5
Nlayers_Ek = parsed["Ekman-layers"]
Nlayers_Rt = parsed["total-layers"] - Nlayers_Ek  # 1000m


H_Ek = z_w[1] - z_w[Nlayers_Ek+1]
H_Rt = z_w[Nlayers_Ek+1] - z_w[Nlayers_Ek+Nlayers_Rt+1]
H = H_Ek + H_Rt
println(format("H_Ek = {:.1f} m", H_Ek))
println(format("H_Rt = {:.1f} m", H_Rt))
println(format("H = H_Ek + H_Rt =  {:.1f} m", H))

# Setup masks of U and V to forbid flow if the ocean is not deep enough
noflowmask_T = sum(mask_T, dims=1)
noflowmask_T[noflowmask_T .< (Nlayers_Rt+Nlayers_Ek)] .= 0.0
noflowmask_T[noflowmask_T .!= 0.0] .= 1.0
noflowmask_T = repeat(noflowmask_T, outer=(Nz, 1, 1))
noflowmask_T = noflowmask_T .* mask_T

V_noflowmask_V = spdiagm( 0 => (amo.bmo.V_N_T * noflowmask_T[:]) .* (amo.bmo.V_S_T * noflowmask_T[:]) )
U_noflowmask_U = spdiagm( 0 => (amo.bmo.U_E_T * noflowmask_T[:]) .* (amo.bmo.U_W_T * noflowmask_T[:]) )

rshp_T = (arr,) -> reshape(arr , Nz, Nx, Ny)
rshpt_T = (arr,) -> reshape(arr , Nz, Nx, Ny, 1)

println("Setup additional operator for streamfunction")

m = mask_T[1, :, :][:]
ψmo = (
    UV_clean_UV = spdiagm( 0 => 
           (amo_slab.bmo.UV_SW_T * m) 
        .* (amo_slab.bmo.UV_SE_T * m) 
        .* (amo_slab.bmo.UV_NW_T * m)
        .* (amo_slab.bmo.UV_NE_T * m) 
    ),
    U_δy_UV = amo_slab.U_mask_U * (amo_slab.bmo.U_S_UV  - amo_slab.bmo.U_N_UV),
    V_δx_UV = amo_slab.V_mask_V * (amo_slab.bmo.V_W_UV  - amo_slab.bmo.V_E_UV),
    T_δx_U = amo_slab.T_mask_T * (amo_slab.bmo.T_W_U  - amo_slab.bmo.T_E_U  ) ,
    T_δy_V = amo_slab.T_mask_T * (amo_slab.bmo.T_S_V  - amo_slab.bmo.T_N_V  ) ,
)



# Setup tools to compute heat transport
lat_v = range(-90.0, 90.0, length=181) |> collect
lat_t = (lat_v[1:end-1] + lat_v[2:end]) / 2.0
σ_sT  = gd.Δx_T[1, :, :] .* gd.Δy_T[1, :, :]
r = MapTransform.Relation(;
    lat     = rad2deg.(gd.ϕ_T[1, :, :]),
    area    = σ_sT,
    mask    = grid_file.mask,
    lat_bnd = lat_v,
)

r_ATL = MapTransform.Relation(;
    lat     = rad2deg.(gd.ϕ_T[1, :, :]),
    area    = σ_sT,
    mask    = mask_ATL_sT,
    lat_bnd = lat_v,
)

r_INDPAC = MapTransform.Relation(;
    lat     = rad2deg.(gd.ϕ_T[1, :, :]),
    area    = σ_sT,
    mask    = mask_INDPAC_sT,
    lat_bnd = lat_v,
)




function main(
    input_file :: String,
    output_file :: String,
)

    local SHF, ADVT, TEMP, Kh, τx_uv, τy_uv, HOR_DIFF, VVEL, UVEL, BSF
    global sub_zrng

    # Load Domain, T, S, wind stress
    Dataset(input_file, "r") do ds
        TEMP   = rearrangePOP2Grid(ds["TEMP"][:, :, sub_zrng, :]  |> missing2zero,  :T;  has_time=true)
        BSF    = rearrangePOP2Grid(ds["BSF"][:]  |> missing2zero,  :UV; has_time=true) * 1e6
        SHF    = rearrangePOP2Grid(ds["SHF"][:]   |> missing2zero,  :T;  has_time=true) * 1.0
        ADVT   = rearrangePOP2Grid(ds["ADVT"][:]  |> missing2zero,  :T;  has_time=true) * 0.01
        τx_uv  = rearrangePOP2Grid(ds["TAUX"][:]  |> missing2zero,  :UV; has_time=true) * (-1.0 / 10.0)
        τy_uv  = rearrangePOP2Grid(ds["TAUY"][:]  |> missing2zero,  :UV; has_time=true) * (-1.0 / 10.0)
        view(TEMP, :, :, :, 1)[mask_T_inactive_idx] .= 0.0

        τx_uv = τx_uv[:, :, 1]
        τy_uv = τy_uv[:, :, 1]
        
        HOR_DIFF   = rearrangePOP2Grid(ds["HOR_DIFF"][:, :, sub_zrng, :] |> missing2zero,  :T; has_time=true) / 1e4
    end

    TEMP_T = view(TEMP, :)

    # Compute Ekman flow
    # ∇×τ
   
    curlτ_uv = reshape(amo_slab.UV_interp_V * amo_slab.V_∂x_UV * view(τy_uv,:) - amo_slab.UV_interp_U * amo_slab.U_∂y_UV * view(τx_uv,:), Nx, Ny+1)

    τeast_uv, τnorth_uv = PolelikeCoordinate.project(gd, τx_uv, τy_uv; direction=:Backward, grid=:UV)
    volflx_east_uv  = τeast_uv * 0.0 
    volflx_north_uv = (- f_uv .* τeast_uv + (ϵ_uv.^2) .* curlτ_uv ./ β_uv) ./ ρ0s2 
    
    volflx_x, volflx_y = PolelikeCoordinate.project(gd, volflx_east_uv, volflx_north_uv; direction=:Forward, grid=:UV)
    
    τeast_t  = reshape(amo_slab.T_interp_UV * τeast_uv[:], Nx, Ny)
    τnorth_t = reshape(amo_slab.T_interp_UV * τnorth_uv[:], Nx, Ny)
    
    # Codron
    #volflx_x = (ϵ_uv .* τx_uv + f_uv .* τy_uv) ./ ρ0s2 
    #volflx_y = (ϵ_uv .* τy_uv - f_uv .* τx_uv) ./ ρ0s2

    u_UV = zeros(Float64, Nz, Nx, Ny+1)
    v_UV = zeros(Float64, Nz, Nx, Ny+1)

    for k=1:Nlayers_Ek
        u_UV[k, :, :] = volflx_x / H_Ek
        v_UV[k, :, :] = volflx_y / H_Ek
    end

    for k=(Nlayers_Ek+1):(Nlayers_Ek+Nlayers_Rt)
        u_UV[k, :, :] = - volflx_x / H_Rt
        v_UV[k, :, :] = - volflx_x / H_Rt
    end

    u_U = U_noflowmask_U * amo.U_interp_UV * u_UV[:] 
    v_V = V_noflowmask_V * amo.V_interp_UV * v_UV[:]
     
    TEMP_U = amo.U_interp_T * TEMP_T
    TEMP_V = amo.V_interp_T * TEMP_T

    uT_U = u_U .* TEMP_U
    vT_V = v_V .* TEMP_V

    # Compute Ekman heat convergence
    TEMPconvx_T = amo.T_DIVx_U * uT_U
    TEMPconvy_T = amo.T_DIVy_V * vT_V
    TEMPconvh_T = TEMPconvx_T + TEMPconvy_T

    # Check if we have convergence in masked
    if any(rshp_T(TEMPconvx_T)[noflowmask_T .== 0] .!= 0)
        throw(ErrorException("Please check mask TEMPconvx_T"))
    end

    if any(rshp_T(TEMPconvy_T)[noflowmask_T .== 0] .!= 0)
        throw(ErrorException("Please check mask TEMPconvy_T"))
    end

    ∫_TEMPconvh_dz_sT = sum(rshpt_T( amo.T_Δz_T * TEMPconvh_T ), dims=1)[1, :, :, :] 

    # Compute Ekman divergence for testing
    Conv_Vol_t = permutedims(rshpt_T(amo.T_DIVx_U * u_U + amo.T_DIVy_V * v_V), [2,3,1,4])

    Conv_Ek_t    = reshape(  MapTransform.transform(r, view(∫_TEMPconvh_dz_sT, :, :, 1)) * ρ0 * cp, :, 1)
    OHT_Ek_v     = reshape(- MapTransform.∫∂a(r, view(∫_TEMPconvh_dz_sT, :, :, 1)) * ρ0 * cp,       :, 1)
    OHT_ADVT_v  = reshape(- MapTransform.∫∂a(r, view(ADVT, :, :, 1)) * ρ0 * cp,                    :, 1)
    SHF_t  = reshape(  MapTransform.transform(r, view(SHF, :, :, 1)),                         :, 1)
    OHT_SHF_v   = reshape(- MapTransform.∫∂a(r, view(SHF, :, :, 1)),                               :, 1)

    # External Mode (Barotropic gyre)
    # first, compute vertical mean temperature
    TEMPm_sT = T_invH_T * sum(reshape( amo.T_Δz_T * TEMP_T, Nz, Nx, Ny), dims=1)[:]
    TEMPm_sU = amo_slab.U_interp_T * TEMPm_sT
    TEMPm_sV = amo_slab.V_interp_T * TEMPm_sT

    # in m^3/s
    BSF = ψmo.UV_clean_UV * BSF[:]
    uBTFlux_sU = - ψmo.U_δy_UV * BSF
    vBTFlux_sV =   ψmo.V_δx_UV * BSF
     
    # special, due to the definition of BSF, we use δ instead of DIV
    BTConv_sT = - ( amo_slab.T_invΔx_T * amo_slab.T_invΔy_T * 
                      ( ψmo.T_δy_V * (vBTFlux_sV .* TEMPm_sV)
                      + ψmo.T_δx_U * (uBTFlux_sU .* TEMPm_sU) )) * ρ0 * cp
  
    BTConv_sT = reshape(BTConv_sT, Nx, Ny) 

    Conv_BT_t = reshape(   MapTransform.transform(r, BTConv_sT), :, 1)
    OHT_BT_v  = reshape( - MapTransform.∫∂a(r, BTConv_sT), :, 1)

    # Horizontal diffusion
    U_Kh_U = spdiagm(0 => amo.U_mask_U * amo.U_interp_T * view(HOR_DIFF, :))
    V_Kh_V = spdiagm(0 => amo.V_mask_V * amo.V_interp_T * view(HOR_DIFF, :))

    TEMP_HDIFF_conv_T =  ( amo.T_DIVx_U * U_Kh_U * amo.U_∂x_T 
                         + amo.T_DIVy_V * V_Kh_V * amo.V_∂y_T ) * TEMP_T

    ∫_TEMP_HDIFF_conv_dz_sT = sum(rshpt_T( amo.T_Δz_T * TEMP_HDIFF_conv_T ), dims=1)[1, :, :, :]
    Conv_DIFF_t = reshape(   MapTransform.transform(r, view(∫_TEMP_HDIFF_conv_dz_sT, :, :, 1)) * ρ0 * cp, :, 1) 
    OHT_DIFF_v  = reshape( - MapTransform.∫∂a(r, view(∫_TEMP_HDIFF_conv_dz_sT, :, :, 1)) * ρ0 * cp,       :, 1)

    # convert wind field
    τeast_latT  = reshape( MapTransform.transform(r, τeast_t), :, 1)
    τnorth_latT = reshape( MapTransform.transform(r, τnorth_t), :, 1)
    
    # Regional integration

    ATL_OHT_Ek_v       = reshape(- MapTransform.∫∂a(r_ATL, view(∫_TEMPconvh_dz_sT, :, :, 1); zero_point=:end) * ρ0 * cp,       :, 1)
    ATL_OHT_ADVT_v     = reshape(- MapTransform.∫∂a(r_ATL, view(ADVT, :, :, 1); zero_point=:end) * ρ0 * cp,                    :, 1)
    ATL_OHT_BT_v       = reshape(- MapTransform.∫∂a(r_ATL, BTConv_sT; zero_point=:end), :, 1)
 
    INDPAC_OHT_Ek_v    = reshape(- MapTransform.∫∂a(r_INDPAC, view(∫_TEMPconvh_dz_sT, :, :, 1); zero_point=:end) * ρ0 * cp,       :, 1)
    INDPAC_OHT_ADVT_v  = reshape(- MapTransform.∫∂a(r_INDPAC, view(ADVT, :, :, 1); zero_point=:end) * ρ0 * cp,                    :, 1)
    INDPAC_OHT_BT_v    = reshape(- MapTransform.∫∂a(r_INDPAC, BTConv_sT; zero_point=:end), :, 1)
 

    Dataset(output_file, "c") do ds

        defDim(ds, "nlon", Nx)
        defDim(ds, "nlat", Ny)
        defDim(ds, "nlatp1", Ny+1)
        defDim(ds, "z_t", Nz)
        defDim(ds, "lat_t", length(lat_t))
        defDim(ds, "lat_v", length(lat_v))
        defDim(ds, "time", Inf)

        for (varname, vardata, vardim, attrib) in [
            ("lat_v", lat_v,  ("lat_v", ), Dict()),
            ("lat_t", lat_t,  ("lat_t", ), Dict()),
            ("int_TEMPconvh_dz_sT", ∫_TEMPconvh_dz_sT, ("nlon", "nlat", "time"), Dict()),
            ("int_TEMP_HDIFF_conv_dz_sT", ∫_TEMP_HDIFF_conv_dz_sT, ("nlon", "nlat", "time"), Dict()),
            ("Conv_Vol_t",    Conv_Vol_t,  ("nlon", "nlat", "z_t", "time"), Dict()),
            ("Conv_Ek_t",     Conv_Ek_t,   ("lat_t", "time",), Dict()),
            ("Conv_DIFF_t",   Conv_DIFF_t, ("lat_t", "time",), Dict()),
            ("Conv_BT_t",     Conv_BT_t,   ("lat_t", "time",), Dict()),
            ("SHF_t",         SHF_t,       ("lat_t", "time",), Dict()),
            ("OHT_Ek_v",      OHT_Ek_v,    ("lat_v", "time",), Dict()),
            ("OHT_DIFF_v",    OHT_DIFF_v,  ("lat_v", "time",), Dict()),
            ("OHT_BT_v",      OHT_BT_v,    ("lat_v", "time",), Dict()),
            ("OHT_ADVT_v",    OHT_ADVT_v,  ("lat_v", "time",), Dict()),
            ("OHT_SHF_v",     OHT_SHF_v,   ("lat_v", "time",), Dict()),

            ("ATL_OHT_Ek_v",      ATL_OHT_Ek_v,    ("lat_v", "time",), Dict()),
            ("ATL_OHT_BT_v",      ATL_OHT_BT_v,    ("lat_v", "time",), Dict()),
            ("ATL_OHT_ADVT_v",    ATL_OHT_ADVT_v,  ("lat_v", "time",), Dict()),
 
            ("INDPAC_OHT_Ek_v",   INDPAC_OHT_Ek_v,    ("lat_v", "time",), Dict()),
            ("INDPAC_OHT_BT_v",   INDPAC_OHT_BT_v,    ("lat_v", "time",), Dict()),
            ("INDPAC_OHT_ADVT_v", INDPAC_OHT_ADVT_v,  ("lat_v", "time",), Dict()),
 
            ("taueast_t",  τeast_latT,  ("lat_t", "time",), Dict()),
            ("taunorth_t", τnorth_latT, ("lat_t", "time",), Dict()),
        ]
            println("Doing varname:", varname)
            var = defVar(ds, varname, Float64, vardim)
            var.attrib["_FillValue"] = 1e20
            
            for (k, v) in attrib
                var.attrib[k] = v
            end

            rng = []
            for i in 1:length(vardim)
                push!(rng, UnitRange(1, size(vardata)[i]))
            end

            var[rng...] = vardata[rng...]

        end

    end
end


for (i, input_file) in enumerate(input_files)

    local output_file

    println("Doing file: ", input_file)
    output_file = format("processed_{:s}", input_file)
    main(
        joinpath(parsed["input-dir"], input_file),
        joinpath(parsed["output-dir"], output_file),
    )

    println("Generate: ", joinpath(parsed["output-dir"], output_file))


end
