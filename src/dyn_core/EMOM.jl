if !(:ModelClockSystem in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "share", "ModelClockSystem.jl")))
end

if !(:Config in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "share", "Config.jl")))
end

if !(:CyclicData in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "share", "CyclicData.jl")))
end

if !(:LogSystem in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "share", "LogSystem.jl")))
end

if ! ( :DataManager in names(Main) )
    include(joinpath(@__DIR__, "..", "share", "DataManager.jl"))
end


macro hinclude(path)
    return :(include(normpath(joinpath(@__DIR__, $path))))
end

module EMOM

    using LinearAlgebra
    using MPI
    using Dates
    using Printf
    using Formatting
    using SharedArrays
    using Distributed
    using SparseArrays
    using NCDatasets
    using JLD2
    using DataStructures

    using ..ModelClockSystem
    using ..Config
    using ..CyclicData
    using ..LogSystem
    using ..DataManager
    using JSON

    macro hinclude(path)
        return :(include(normpath(joinpath(@__DIR__, $path))))
    end
 
    @hinclude("../share/constants.jl")
    @hinclude("../share/ocean_state_function.jl")

    # classes
    @hinclude("../share/GridFile.jl")
    @hinclude("../share/PolelikeCoordinate.jl")
    @hinclude("../share/BasicMatrixOperators.jl")
    @hinclude("../share/AdvancedMatrixOperators.jl")



    @hinclude("../configs/EMOM_configs.jl")
    @hinclude("../configs/domain_configs.jl")

    @hinclude("VerticalDiffusion.jl")

    @hinclude("Topography.jl")
    @hinclude("Workspace.jl")
    @hinclude("Env.jl")
    @hinclude("TempField.jl")
    @hinclude("Field.jl")
    @hinclude("Core.jl")
    
    @hinclude("ModelBlock.jl")

    @hinclude("Leonard1979.jl")
    @hinclude("setupForcing.jl")
    @hinclude("stepAdvection.jl")
    @hinclude("stepColumn.jl")
    @hinclude("checkBudget.jl")
    
    @hinclude("var_list.jl")
    @hinclude("var_desc.jl")
    
    @hinclude("snapshot_funcs.jl")
    
    @hinclude("updateDatastream.jl")
    @hinclude("updateUVSFC.jl")
    @hinclude("updateBuoyancy.jl")
    @hinclude("updateSfcFlx.jl")

end



