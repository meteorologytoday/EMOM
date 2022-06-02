using Pkg

pkg_names = []
open(joinpath(@__DIR__, "package_list"), "r") do io

    while ! eof(io)
        pkg_name = readline(io) |> chomp |> lstrip |> rstrip
        
        if pkg_name != ""
            push!(pkg_names, pkg_name)
        end
        println("Package detected: ", pkg_name)
    end

end

for pkg_name in pkg_names
    println("I am adding the package: $pkg_name")
    Pkg.add(pkg_name)
    Pkg.build(pkg_name)
end


