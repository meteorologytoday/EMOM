using NCDatasets



config = Dict{Any, Any}(

    :DRIVER => Dict(
        :casename           => "Sandbox",
        :caseroot           => joinpath(@__DIR__, "Sandbox", "caseroot"),
        :caserun            => joinpath(@__DIR__, "Sandbox", "caserun"),
        :archive_root       => joinpath(@__DIR__, "Sandbox", "archive"),
    ),

    :MODEL_MISC => Dict(
        :timetype               => "DateTimeNoLeap",
        :init_file              => "/billevans/projects/IOM/test/test02_Qflx_finding_driver/init_ocn.jld2",
        :rpointer_file          => "rpointer.hoom",
        :daily_record           => [],
        :monthly_record         => [:ESSENTIAL,],
        :enable_archive         => true,
    ),

    :MODEL_CORE => Dict(

#        :domain_file                  => joinpath(@__DIR__, "CESM_domains", "domain.ocn.gx3v7.120323.nc"),
#        :topo_file                    => joinpath(@__DIR__, "Nz_bot.nc"),
#        :cdata_file                   => joinpath(@__DIR__, "POP2PROFILE.g37.nc"),

        :domain_file                  => joinpath(@__DIR__, "CESM_domains", "domain.ocn.gx1v6.090206.nc"),
        :topo_file                    => joinpath(@__DIR__, "Nz_bot.nc"),
        :cdata_file                   => joinpath(@__DIR__, "POP2PROFILE.g16.nc"),


        :cdata_beg_time               => DateTimeNoLeap(1, 1, 1, 0, 0, 0),
        :cdata_end_time               => DateTimeNoLeap(2, 1, 1, 0, 0, 0),
        :cdata_align_time             => DateTimeNoLeap(1, 1, 1, 0, 0, 0),

        :z_w                          => nothing,

        :substeps                     => 8,
        :MLD_scheme                   => :datastream,
        :Qflx                         => :off,
        :Qflx_finding                 => :off,
        :convective_adjustment        => :on,
        #:advection_scheme             => :ekman_codron2012_partition,
        :advection_scheme             => :ekman_AGA2020,

        :weak_restoring               => :off,
        :τwk_TEMP                     => 86400.0 * 365,
        :τwk_SALT                     => 86400.0 * 365,


        :τ_frz                        => 3600.0,
        :Ekman_layers                 => 5,
        :Returnflow_layers            => 25,
    
        :transform_vector_field       => false,
    ),

)

Dataset(config[:MODEL_CORE][:cdata_file], "r") do ds

    z_w_top = nomissing(ds["z_w_top"][:], NaN)
    z_w_bot = nomissing(ds["z_w_bot"][:], NaN)

    z_w      = zeros(Float64, length(z_w_top)+1)
    z_w[1:end-1]   = z_w_top
    z_w[end] = z_w_bot[end]

    global config[:MODEL_CORE][:z_w]  = z_w
end

