include("../julia/TBIO.jl")

using .TBIO
using Formatting
using JSON

arrs = [ [1.0, 2.0, 3.0], [4.0, 5.0] ]

println(TBIO.calChecksum(arrs))
