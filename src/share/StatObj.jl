mutable struct StatObj

    vars   :: Dict
    ws     :: Dict

    function StatObj(
        vars :: Union{Nothing, Dict},
    )
        _vars = Dict()

        ws = Dict()

        for (k, v) in vars
            if typeof(v) <: Float64
                _vars[k] = 0.0
            elseif typeof(v) <: AbstractArray{Float64}
                _vars[k] = zeros(Float64, size(v)...)
            else
                throw(ErrorException("Not a subtype of Number or AbstractArray{Number}"))
            end
            
            ws[k] = 0.0
        end

        return new(_vars, ws)
    end

end

function addStatObj!(sobj::StatObj, vars::Dict; w::Float64=1.0)
    for (k, v) in vars
        if typeof(v) <: Number
            sobj.vars[k] += w * v
        else
            sobj.vars[k] .+= w .* v
        end
        sobj.ws[k] += w
    end
end

function normStatObj!(sobj::StatObj)
    for (k, v) in sobj.vars
        if typeof(v) <: Number
            sobj.vars[k] /= sobj.ws[k]
        else
            sobj.vars[k] ./= sobj.ws[k]
        end
        sobj.ws[k] = 1.0
    end

end

function zeroStatObj!(sobj::StatObj)
    for (k, v) in sobj.vars
        if typeof(v) <: Number
            sobj.vars[k] = 0.0
        else
            sobj.vars[k] .= 0.0
        end
        sobj.ws[k] = 0.0
    end

end


