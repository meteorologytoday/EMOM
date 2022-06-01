module RunCommands

    export runOneCmd, pleaseRun

    function runOneCmd(cmd; igs::Bool=false)
        p = (igs == true) ? "ignore" : ""
        println("$(p)>> ", string(cmd))
        if igs
            cmd = ignorestatus(cmd)
        end
        run(cmd)
    end


    function pleaseRun(cmd; igs::Bool=false)
        if isa(cmd, Array)
            for i = 1:length(cmd)
                runOneCmd(cmd[i]; igs = igs)
            end
        else
            runOneCmd(cmd; igs = igs)
        end
    end

end
