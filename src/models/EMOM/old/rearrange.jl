function toZXY(a::AbstractArray{T, 3}, old_arrange::Symbol) where T
    if old_arrange == :zxy
        return a
    elseif old_arrange == :xyz
        return PermutedDimsArray(a, (3, 1, 2))
    else
        throw(ErrorException("Unknown arrangement: " * old_arrange))
    end
end

function toXYZ(a::AbstractArray{T, 3}, old_arrange::Symbol) where T
    if old_arrange == :xyz
        return a
    elseif old_arrange == :zxy
        return PermutedDimsArray(a, (2, 3, 1))
    else
        throw(ErrorException("Unknown arrangement: " * old_arrange))
    end
end

