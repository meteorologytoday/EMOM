

module TBIO

    using Formatting
    export readTB!, writeTB

    function readTB!(
        filename   :: AbstractString,
        txt_nchars :: Integer,
        arrs       :: AbstractArray{T};
        endianess  :: Symbol = :LITTLE,   # Small: 0x04030201,  Big: 0x01020304
        trim       :: Bool   = true,
    ) where T <: AbstractArray{Float64}

        if endianess != :LITTLE && endianess != :BIG
            throw(ErrorException("Unknown symbol: " * string(endianess)))
        end

        if txt_nchars < 0
            throw(ErrorException("txt_nchars cannot be negative."))
        end

        msg = nothing
        if isfile(filename)

            get_filesize = filesize(filename)
            expect_filesize = sum(length.(arrs)) * 8 + txt_nchars + 8
            if get_filesize == expect_filesize 

                open(filename, "r") do io
                    msg = String(read(io, txt_nchars))
                    
                    trim && (msg = strip(msg))
                    

                    for i = 1:length(arrs)
                        read!(io, arrs[i])
                    end

                    if     endianess == :LITTLE && Base.ENDIAN_BOM == 0x01020304
                        for i = 1:length(arrs)
                            arrs[i][:] = ltoh.(arrs[i])
                        end
                    elseif endianess == :BIG && Base.ENDIAN_BOM == 0x04030201
                        for i = 1:length(arrs)
                            arrs[i][:] = ntoh.(arrs[i])
                        end
                    end

                    received_cs   = reinterpret(UInt64, read(io, 8))[1]
                    calculated_cs = calChecksum(arrs)

                    if received_cs != calculated_cs
                        msg = nothing
                        println(format("[readTB!] Checksum does not match. Received: {:X}, calculated: {:X}", received_cs, calculated_cs))
                    end

                end
            else 
                println(format("[readTB!] Expecting filesize: {} bytes, but got {} bytes", expect_filesize, get_filesize))
            end
        else
            println(format("[readTB!] File {} does not exist.", filename))
        end

        return msg
    end


    function writeTB(
        filename   :: AbstractString,
        msg        :: AbstractString,
        txt_nchars :: Integer,
        arrs       :: AbstractArray{T};
        endianess  :: Symbol = :LITTLE,
    ) where T <: AbstractArray{Float64}


        if endianess != :LITTLE && endianess != :BIG
            throw(ErrorException("Unknown symbol: " * string(endianess)))
        end

        if length(msg) > txt_nchars
            throw(ErrorException("Message length exceeds txt_nchars."))
        end

        if txt_nchars < 0
            throw(ErrorException("txt_nchars cannot be negative."))
        end

        open(filename, "w") do io
            write(io, msg)
            
            for i = 1:(txt_nchars - length(msg))
                write(io, " ")
            end

            if     endianess == :LITTLE && Base.ENDIAN_BOM == 0x01020304
                for i = 1:length(arrs)
                    write(io, htol.(arrs[i]))
                end
                write(io, htol(calChecksum(arrs)))
            elseif endianess == :BIG && Base.ENDIAN_BOM == 0x04030201
                for i = 1:length(arrs)
                    write(io, hton.(arrs[i]))
                end
                write(io, hton(calChecksum(arrs)))
            else
                for i = 1:length(arrs)
                    write(io, arrs[i])
                end
                write(io, calChecksum(arrs))
            end



        end
    end

    # ror, rol :: bitwise circular shift to right / left
    # Source:
    # https://discourse.julialang.org/t/efficient-bit-rotate-functions-ror-rol-what-is-the-official-way-for-julia-v1/19062
    ror(x::UInt64, k::Int) = (x >>> (0x3f & k)) | (x << (0x3f & -k))
    rol(x::UInt64, k::Int) = (x >>> (0x3f & -k)) | (x << (0x3f & k))


    function calChecksum(
        arrs :: AbstractArray{T},
    ) where T <: AbstractArray{Float64}

        k = 0
        s = UInt64(0)
        for i = 1:length(arrs)
            arr = reinterpret(UInt64, arrs[i])
            
            for j = 1:length(arr)

                s = xor(s, rol(arr[j], k))
                #s = xor(s, arr[j])
                k = mod(k+1, 64)
            end

        end

#        println(format("{:X}", s))
        return s
    end
end


