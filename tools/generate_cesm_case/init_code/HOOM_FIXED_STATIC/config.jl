merge!(overwrite_configs, Dict(
    :MLD_scheme                   => :datastream,
    :Qflux_scheme                 => :on,
    :Qflux_finding                => :off,
    :seaice_nudging               => :off,
    :vertical_diffusion_scheme    => :off,
    :horizontal_diffusion_scheme  => :off,
    :relaxation_scheme            => :off,
    :convective_adjustment_scheme => :off,
    :radiation_scheme             => :step,
    :advection_scheme             => :static,
))
