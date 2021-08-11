config = Dict{Any, Any}(

    :DRIVER => Dict(
        :casename           => "Sandbox",
        :caseroot           => joinpath(@__DIR__, "Sandbox", "caseroot"),
        :caserun            => joinpath(@__DIR__, "Sandbox", "caserun"),
        :archive_root       => joinpath(@__DIR__, "Sandbox", "archive"),
    ),

    :MODEL_MISC => Dict(
        :timetype               => "DateTimeNoLeap",
        :init_file              => "",#nothing,#joinpath(@__DIR__, "ocn_init.nc"),
        :rpointer_file          => "rpointer.hoom",
        :daily_record           => [:ALL,],
        :monthly_record         => [:ALL,],
        :enable_archive         => true,
    ),

    :MODEL_CORE => Dict(
        #:domain_file                  => joinpath(@__DIR__, "CESM_domains", "domain.ocn.gx1v6.090206.nc"),
        #:cdata_file                   => joinpath(@__DIR__, "forcing_gx1v6.nc"),
        :domain_file                  => joinpath(@__DIR__, "domain.ocn_aqua.fv4x5_gx3v7.091218.nc"),
        :cdata_file                   => joinpath(@__DIR__, "forcing.nc"),

        :cdata_beg_time               => DateTimeNoLeap(1, 1, 1, 0, 0, 0),
        :cdata_end_time               => DateTimeNoLeap(2, 1, 1, 0, 0, 0),
        :cdata_align_time             => DateTimeNoLeap(1, 1, 1, 0, 0, 0),

        :z_w                          => collect(Float64, 0:-10:-350),

        :substeps                     => 8,
        :MLD_scheme                   => :static,
        :Qflx                         => :on,
        :Qflx_finding                 => :off,
        :convective_adjustment        => :off,
        :advection_scheme             => :ekman_codron2012_partition,

        :weak_restoring               => :on,
        :τwk_TEMP                     => 86400.0 * 365,
        :τwk_SALT                     => 86400.0 * 365,


        :τ_frz                        => 3600.0,
        :Ekman_layers      => 5,
        :Returnflow_layers => 25,
    ),

)
