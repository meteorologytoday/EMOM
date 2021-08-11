mutable struct ModelBlock

    # TempField means the variable will not be in the 
    # snapshot. It can still be output in the hist file
    # but only for debugging usage.

    ev   :: Env
    fi   :: Field
    tmpfi :: TempField
    co   :: Union{Core, Nothing}
    dt   :: Union{DataTable, Nothing}


    function ModelBlock(
        ev :: Env;
        init_core :: Bool = false,
    ) 

        fi = Field(ev)
        tmpfi = TempField(ev)

        mb = new(
            ev,
            fi,
            tmpfi,
            nothing,
            nothing,
        )
        
        dt = DataTable(Nz = ev.Nz, Nx = ev.Nx, Ny = ev.Ny)
        co = (init_core) ? Core(ev, fi) : nothing
        mb.dt = dt
        mb.co = co

        for (k, (varref, grid_type)) in getDynamicVariableList(mb; varsets=[:ALL,])
            regVariable!(dt, k, grid_type, varref) 
        end


        return mb
    end
end


