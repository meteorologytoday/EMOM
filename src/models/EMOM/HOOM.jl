if !(:ModelClockSystem in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "..", "share", "ModelClockSystem.jl")))
end

if !(:ConfigCheck in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "..", "share", "ConfigCheck.jl")))
end

if !(:CyclicData in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "..", "share", "CyclicData.jl")))
end

if !(:LogSystem in names(Main))
    include(normpath(joinpath(dirname(@__FILE__), "..", "..", "share", "LogSystem.jl")))
end

if ! ( :DataManager in names(Main) )
    include(joinpath(@__DIR__, "..", "..", "share", "DataManager.jl"))
end


macro hinclude(path)
    return :(include(normpath(joinpath(@__DIR__, $path))))
end

module HOOM

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

    using ..ModelClockSystem
    using ..ConfigCheck
    using ..CyclicData
    using ..LogSystem
    using ..DataManager

    macro hinclude(path)
        return :(include(normpath(joinpath(@__DIR__, $path))))
    end
 
    @hinclude("../../share/constants.jl")
    @hinclude("../../share/ocean_state_function.jl")

    # classes
    @hinclude("../../share/GridFile.jl")
    @hinclude("../../share/MapInfo.jl")
    @hinclude("../../share/PolelikeCoordinate.jl")
    @hinclude("../../share/BasicMatrixOperators.jl")
    @hinclude("../../share/AdvancedMatrixOperators.jl")



    @hinclude("entry_list.jl")

    @hinclude("Leonard1979.jl")
    @hinclude("VerticalDiffusion.jl")

    @hinclude("Env.jl")
    @hinclude("TempField.jl")
    @hinclude("Field.jl")
    @hinclude("Core.jl")
    
    @hinclude("ModelBlock.jl")


    @hinclude("setupForcing.jl")
    @hinclude("stepAdvection.jl")
    @hinclude("stepColumn.jl")
    @hinclude("checkBudget.jl")
    
    @hinclude("var_list.jl")
    @hinclude("var_desc.jl")
    
    @hinclude("snapshot_funcs.jl")
    
    @hinclude("updateDatastream.jl")
    @hinclude("updateBuoyancy.jl")

end



