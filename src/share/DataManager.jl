module DataManager

    using NCDatasets
    using Formatting
    using Dates

    export DataUnit, DataTable, regVariable!
    export Recorder, setNewNCFile!, record!, avgAndOutput! 

    missing_value = 1e20

    
    
    include("DataUnit.jl")
    include("DataTable.jl")
    include("Recorder.jl")
end
