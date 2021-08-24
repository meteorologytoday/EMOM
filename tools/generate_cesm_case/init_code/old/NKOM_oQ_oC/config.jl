merge!(overwrite_configs, Dict(
    :MLD_scheme                   => :prognostic,
    :Qflux_scheme                 => :on,
    :diffusion_scheme             => :on,
    :relaxation_scheme            => :on,
    :convective_adjustment_scheme => :on,
    :radiation_scheme             => :exponential,
    :advection_scheme             => :static,
))
