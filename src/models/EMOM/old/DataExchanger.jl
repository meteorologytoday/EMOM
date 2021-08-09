struct DataBinding
   
    id    :: Symbol
 
    here  :: DataUnit
    there :: DataUnit
   
    # views 
    here_pull_view   :: Any
    there_pull_view  :: Any

    here_push_view   :: Any
    there_push_view  :: Any

    # pull from there
    # push from here

    function DataBinding(

        id          :: Symbol,

        here        :: DataUnit,
        there       :: DataUnit,

        here_pull_yrng        :: Any,
        there_pull_yrng       :: Any,

        here_push_yrng        :: Any,
        there_push_yrng       :: Any,
    )

        here_pull_view  = view( here.data, :, :,  here_pull_yrng)
        there_pull_view = view(there.data, :, :, there_pull_yrng)

        here_push_view  = view( here.data, :, :,  here_push_yrng)
        here_push_view  = view(there.data, :, :, there_push_yrng)


        if length(here_pull_view) != length(there_pull_view)
            println(size(here_pull_view), "; " , size(there_pull_view))
            throw(ErrorException("Range mismatch in pull view. Key: " * string(id)))
        end
 
        if length(here_push_view) != length(there_push_view)
            println(size(here_push_view), "; " , size(there_push_view))
            throw(ErrorException("Range mismatch in push view. Key: " * string(id)))
        end
        
        
        return new(
            id,
            here,
            there,
            here_pull_view,
            there_pull_view,
            here_push_view,
            there_push_view,
        )

    end

end


struct DataExchanger
    
    groups   :: Dict
    bindings :: Dict


    function DataExchanger(
        group_labels :: AbstractArray{Symbol} = Array{Symbol}(undef, 0),
    )

        if ! (:ALL in group_labels)
            push!(group_labels, :ALL)
        end


        groups = Dict() 
        for label in group_labels
            groups[label] = Array{Symbol}(undef, 0)
        end

        bindings = Dict()

        return new(
            groups,
            bindings,
        )
    end

end

function createBinding!(
    data_exchanger   :: DataExchanger,
    id               :: Symbol,
    here             :: DataUnit,
    there            :: DataUnit,
    here_pull_yrng        :: Any,
    there_pull_yrng       :: Any,
    here_push_yrng        :: Any,
    there_push_yrng       :: Any;
)

    db = DataBinding(
        id,
        here,
        there,
        here_pull_yrng,
        there_pull_yrng,
        here_push_yrng,
        there_push_yrng,
    )

    if ! haskey(data_exchanger.bindings, id)
        data_exchanger.bindings[id] = db
    else
        throw(ErrorException("Binding id `" * string(id) * "` already existed."))
    end

end

function addToGroup!(
    data_exchanger :: DataExchanger,
    id    :: Symbol,
    label :: Symbol, 
)

    if ! haskey(data_exchanger.groups, label)
        println("Group `" * string(label) * "` does not exist. Create one.")
        data_exchanger.groups[label] = Array{Symbol}(undef, 0)
    end

    if id in data_exchanger.groups[label]
        throw(ErrorException("Binding id `" * string(id) * "` already in group `" * string(label) * "`."))
    end

    push!(data_exchanger.groups[label], id)

end

function syncData!(
    data_exchanger :: DataExchanger,
    group_label    :: Symbol,
    direction      :: Symbol,
)

    dbs = data_exchanger.groups[group_label]
   

     
    if direction == :PUSH
        for db_label in dbs
            db = data_exchanger.bindings[db_label]

            #= 
            if db_label == :Φ
                db.here_push_view .= rand(size(db.here_push_view)...)
                println("Before SYNC: ")
                println("SUM here : ",  SUM(db.here_push_view))
                println("SUM there: ", SUM(db.there_push_view))
            end
            =#


            db.there_push_view .= db.here_push_view

            #=
            if db_label == :Φ

                for i=1:144, j=1:90
                    db.there_push_view[i, j] = db.here_push_view[i, j]
                end

                println("db: id: ", db.here.id, "; ", db.there.id, "; size: ", size(db.there_push_view), "; sizehere: ", size(db.here_push_view))
                println("SUM here : ",  SUM(db.here_push_view))
                println("SUM there: ", SUM(db.there_push_view))
            end
            =#
        end 
    elseif direction == :PULL
        for db_label in dbs

            db = data_exchanger.bindings[db_label]
            db.here_pull_view .= db.there_pull_view

#            if db.here.id == :SWFLX
#                println("db: id: ", db.here.id, "; ", db.there.id, "; size: ", size(db.there_push_view), "; sizehere: ", size(db.here_push_view))
#                println("sum: ", sum(db.there.odata))
#            end
        end 
    else
        throw(ErrorException("Unknown direction keyword: " * string(direction)))
    end
end

