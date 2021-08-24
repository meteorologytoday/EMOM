merge!(overwrite_configs, Dict(
    :MLD_scheme                   => :datastream,
    :Qflux_scheme                 => :on,
    :diffusion_scheme             => :off,
    :relaxation_scheme            => :off,
    :convective_adjustment_scheme => :off,
    :radiation_scheme             => :step,
    :advection_scheme             => :static,
))
