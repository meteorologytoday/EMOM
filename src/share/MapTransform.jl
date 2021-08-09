module MapTransform
    
    mutable struct Relation

        lat      :: AbstractArray{Float64, 2}
        area     :: AbstractArray{Float64, 2}
        mask     :: AbstractArray{Float64, 2}
        
        lat_bnd  :: AbstractArray{Float64, 1}
        ∂a       :: AbstractArray{Float64, 1}
        A        :: Float64 
        indices  :: Any     

        function Relation(;
            lat     :: AbstractArray{Float64, 2},
            area    :: AbstractArray{Float64, 2},
            mask    :: AbstractArray{Float64, 2},
            lat_bnd :: AbstractArray{Float64, 1},
        )
            Δlat = lat_bnd[2:end] - lat_bnd[1:end-1]

            if any(Δlat .<= 0)
                throw(ErrorException("lat_bnd not monotonically increasing."))
            end

            indices = []
            mask_is_one = mask .== 1.0
            push!(indices, (lat_bnd[1] .<= lat .<= lat_bnd[2]) .& mask_is_one)
            for i = 2:length(lat_bnd)-1
                push!(indices, (lat_bnd[i] .< lat .<= lat_bnd[i+1]) .& mask_is_one )
            end

            ∂a = zeros(Float64, length(lat_bnd)-1)
            for i = 1:length(∂a)
                ∂a[i] = sum(area[indices[i]])
            end

            area_chk = sum(area[mask.==1.0])
            if abs((sum(∂a) - area_chk) / area_chk) > 1e-10
                print(abs((sum(∂a))), "; area_chk=", area_chk)
                throw(ErrorException("Sum area not equal."))
            end

            return new(
                lat,
                area,
                mask,
                lat_bnd,
                ∂a,
                sum(∂a),
                indices,            
            )

        end

    end

    function f∂a(
        r :: Relation,
        f :: AbstractArray{Float64, 2},
    )
        f∂a = zeros(Float64, length(r.lat_bnd)-1)
        for i = 1:length(r.∂a)
            index = r.indices[i]
            f∂a[i] = sum(r.area[index] .* f[index])
        end

        return f∂a
    end

    function ∫∂a(
        r :: Relation,
        f :: AbstractArray{Float64, 2};
        zero_point :: Symbol = :beg,
    )
        _∫f∂a = zeros(Float64, length(r.lat_bnd))
        _f∂a = f∂a(r, f)

        if zero_point == :beg
            for i = 1:length(_f∂a)
                _∫f∂a[i+1] = _∫f∂a[i] + _f∂a[i]
            end
        elseif zero_point == :end
            for i = length(_f∂a):-1:2
                _∫f∂a[i-1] = _∫f∂a[i] - _f∂a[i-1]
            end
        else
            throw(ErrorException("Unrecognized symbol: " * string(zero_point)))
        end

        return _∫f∂a

    end

    # Only transform the function f
    # onto lat_bnd coordinate.
    function transform(
        r :: Relation,
        f :: AbstractArray{Float64, 2},
    )
        _f∂a = f∂a(r, f)

        return _f∂a ./ r.∂a

    end

    function mean(
        r :: Relation,
        f :: AbstractArray{Float64, 2},
    )
        return ∫∂a(r, f)[end] / r.A
    end
end
