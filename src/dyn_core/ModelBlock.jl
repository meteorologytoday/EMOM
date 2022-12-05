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
        
        co = (init_core) ? Core(ev, tmpfi) : nothing
        dt = DataTable(
            Nz = ev.Nz,
            Nx = ev.Nx,
            Ny = ev.Ny,
            mask_sT=ev.topo.sfcmask_sT,
            mask_T=ev.topo.mask_T,
        )

        mb.co = co
        mb.dt = dt


        for (k, varinfo) in getDynamicVariableList(mb; varsets=["ALL",])
            writeLog("Register variable: {:s}", string(k))
            varref, grid, mask = varinfo
            regVariable!(dt, k, grid, mask, varref)
        end

        for (k, varinfo) in getCompleteVariableList(mb, :static)
            writeLog("Register variable: {:s}", string(k))
            varref, grid, mask = varinfo
            regVariable!(dt, k, grid, mask, varref)
        end



        return mb
    end
end


