function allocate(datakind::Symbol, dtype::DataType, dims...)
    if datakind == :local
        return zeros(dtype, dims...)
    elseif datakind == :shared
        return SharedArray{dtype}(dims...)
    else
        ErrorException("Unknown kind: " * string(datakind)) |> throw
    end
end


