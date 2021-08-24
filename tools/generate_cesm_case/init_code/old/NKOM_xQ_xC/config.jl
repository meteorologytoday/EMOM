merge!(overwrite_configs, Dict(
    :MLD_scheme                   => :prognostic,
    :Qflux_scheme                 => :off,
    :diffusion_scheme             => :on,
    :relaxation_scheme            => :off,
    :convective_adjustment_scheme => :on,
    :radiation_scheme             => :exponential,
    :advection_scheme             => :static,
))
