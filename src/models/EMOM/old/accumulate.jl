function accumulate!(
    ocn :: Ocean,
)
   
    for f in fieldnames(AccumulativeVariables)
        v = getfield(ocn.acc_vars, f)
        v .+= getfield(ocn, f) 
    end

end


function avg_accumulate!(
    ocn :: Ocean;
    count :: Real,
)
    for f in fieldnames(AccumulativeVariables)

        ocn_field = getfield(ocn, f)
        acc_field = getfield(ocn.acc_vars, f)

        for i in eachindex(ocn_field)
            ocn_field[i] = acc_field[i] / count
        end

        # clear variable by default
        acc_field .= 0.0

    end

end
