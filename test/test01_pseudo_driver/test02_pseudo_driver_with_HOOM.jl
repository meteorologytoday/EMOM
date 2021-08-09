include("HOOM/src/driver/pseudo_driver.jl")
include("HOOM/src/models/HOOM/CESMCORE_HOOM.jl")

using CFTime
using Dates

t_start = DateTimeNoLeap(1, 1, 1)
Δt = Second(86400)
steps = 31
t_end = t_start + Δt * steps


configs = Dict(
    :substeps    => 8, # This controls how many steps will occur for each CESM coupling. Example: ocean couple to atmosphere every 24 hours but itself steps every 3 hours. This means we would expect `Δt` = 86400, and we set `substeps` = 8.
    :daily_record       => [],
    :monthly_record     => :ESSENTIAL,
    :enable_archive     => true,
    :archive_list       => "archive_list.txt",
    :rpointer_file      => "rpointer.hoom",

    :casename                     => "Sandbox",
    :caseroot                     => joinpath(@__DIR__, "Sandbox", "caseroot"),
    :caserun                      => joinpath(@__DIR__, "Sandbox", "caserun"),
    :domain_file                  => "domain.ocn_aqua.fv4x5_gx3v7.091218.nc",
    :archive_root                 => joinpath(@__DIR__, "Sandbox", "hist"),
    :enable_archive               => true,
    :daily_record                 => :ESSENTIAL,
    :monthly_record               => :ESSENTIAL,
    :yearly_snapshot              => true,
    :substeps                     => 8,
    :init_file                    => joinpath(@__DIR__, "ocn_init.nc"),
    
    :MLD_scheme                   => :datastream,
    :Qflux_scheme                 => :off,
    :Qflux_finding                => :off,
    :seaice_nudging               => :off,
    :vertical_diffusion_scheme    => :off,
    :horizontal_diffusion_scheme  => :off,
    :relaxation_scheme            => :off,
    :convective_adjustment_scheme => :off,
    :radiation_scheme             => :exponential,
    :advection_scheme             => :static,#ekman_codron2012_partition,
)

read_restart = false

coupler_funcs = (
    before_model_init! = function()
        println("[Coupler] before model init")
        return t_start, read_restart
    end,
    after_model_init! = function(OMMODULE, OMDATA)
        println("[Coupler] After model init")
    end,
    before_model_run! = function(OMMODULE, OMDATA)
        println("[Coupler] Before model run")
        t_end_reached = OMDATA.clock.time >= t_end
       
        if t_end_reached
            return :END, Δt, t_end_reached
        else

            # compute flux
            lat = OMDATA.ocn.mi.yc
            lon = OMDATA.ocn.mi.xc

            OMDATA.x2o["SWFLX"] .= - 1000.0
            OMDATA.x2o["TAUX"]  .= 1e-2 * cos.(deg2rad.(lat))

            return :RUN, Δt, t_end_reached
        end
    end,
    after_model_run! = function(OMMODULE, OMDATA)
        println("[Coupler] After model run")
    end,
    finalize! = function(OMMODULE, OMDATA)
        println("[Coupler] Finalize")
    end 
)



runModel(
    CESMCORE_HOOM, 
    configs,
    coupler_funcs,
)
