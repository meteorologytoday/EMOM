module ProgramTunnelMod_fs
implicit none
integer, parameter :: default_charlen = 512

type ptm_ProgramTunnelInfo

    Integer            :: nchars
    character(len=default_charlen) :: path
    Integer            :: rotate

    Integer              :: recv_trackno
    Integer              :: send_trackno

    character(len = default_charlen) :: recv_fn
    character(len = default_charlen) :: send_fn

    Integer :: recv_fd
    Integer :: send_fd

    integer :: chk_freq
    integer :: timeout
    integer :: timeout_limit_cnt

    integer :: buffer
    integer :: buffer_cnt
    integer :: recv_first_sleep_max
    integer :: recv_first_sleep
    integer :: recv_first_cnt
    integer :: error_sleep
    integer :: error_max

end type


contains

subroutine ptm_setDefault(PTI, fds)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI
    Integer :: fds(:)

    PTI%nchars = default_charlen
    PTI%path   = "x_tmp"
    PTI%rotate = 100

    PTI%recv_fn  = "Y2X"
    PTI%send_fn  = "X2Y"
 

    PTI%recv_trackno = 1
    PTI%send_trackno = 1

    PTI%recv_fd = fds(1)
    PTI%send_fd = fds(2)

    PTI%chk_freq = 50               ! millisecs (0.05 secs)
    PTI%timeout  = 30 * 60 * 1000   ! millisecs (30 min)

    PTI%buffer   =  200        ! millisecs (0.2 secs)
    PTI%buffer_cnt = 40        ! A buffer cnt is a chk_freq
    PTI%recv_first_sleep_max = 5000
    PTI%recv_first_sleep = 0
    PTI%recv_first_cnt = 0

    PTI%error_sleep = 50


    call ptm_autoCalculateCnt(PTI)
end subroutine 


subroutine ptm_autoCalculateCnt(PTI)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI
    PTI%timeout_limit_cnt = ceiling(real(PTI%timeout)          / real(PTI%chk_freq))
    PTI%buffer_cnt        = ceiling(real(PTI%buffer)           / real(PTI%chk_freq))
    PTI%recv_first_cnt    = ceiling(real(PTI%recv_first_sleep) / real(PTI%chk_freq))
    PTI%error_max         = ceiling(real(PTI%timeout)          / real(PTI%error_sleep))
end


subroutine ptm_printSummary(PTI)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI

    print *, "[PTI] recv_fn: ", trim(PTI%recv_fn)
    print *, "[PTI] send_fn: ", trim(PTI%send_fn)
    print *, "[PTI] chk_freq:", PTI%chk_freq

end subroutine

subroutine ptm_incTrackno(PTI, which)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI
    character(len=*)            :: which

    if (which == "send") then
        PTI%send_trackno = PTI%send_trackno + 1

    else if (which == "recv") then
        PTI%recv_trackno = PTI%recv_trackno + 1
    else
        print *, "[ptm_incTrackno] ERROR: Unkown target: ", which
        stop 1
    end if

end



integer function ptm_sendData(PTI, msg, dat)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI
    character(len=*)         :: msg
    real(8)                  :: dat(:)
    
    character(len=default_charlen)       :: mod_msg
    character(len=default_charlen)       :: send_fn
    integer                  :: error_cnt
    logical                  :: correct, dir_exists

    write(mod_msg, '(i0.3, "#", A)') PTI%send_trackno, trim(adjustl(msg)) 
    write(send_fn, '(A, "/", A, "_", i0.3, ".tb")') trim(PTI%path), trim(PTI%send_fn), mod(PTI%send_trackno-1, PTI%rotate) + 1
    print *, "[ptm_sendData] Filename: ", trim(send_fn)
    !print *, "ready to send: [", mod_msg, "]"
    do error_cnt = 1, PTI%error_max

        correct = .true.

        inquire(directory=PTI%path, exist=dir_exists)
        if (dir_exists .eqv. .false.) then
            print *, "[ptm_sendData] ERROR: path [", trim(PTI%path), "] does not exist."
            correct = .false.
        else
            ptm_sendData = ptm_writeData(send_fn, PTI%send_fd, mod_msg, PTI%nchars, dat)
            if (ptm_sendData .gt. 0) then
                correct = .false.
            end if
        end if

        if (correct .eqv. .true. ) then
            exit
        else
            if (error_cnt .lt. PTI%error_max) then
                print *, "[ptm_sendData] ERROR: Fail to send data. Sleep and redo..."
                print *, error_cnt
                call ptm_busysleep(PTI%error_sleep)
            else
                print *, "[ptm_sendData] ERROR: Fail to send data. Maximum trail reached." 
                return
            end if
        end if

    end do

    PTI%send_trackno = PTI%send_trackno + 1
    print *, "[ptm_sendData] File sent: ", trim(send_fn)

end function

integer function ptm_recvData(PTI, msg, dat)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI
    character(len=*)            :: msg
    real(8)                     :: dat(:)
    
    integer                     :: i, n, error_cnt
    character(len=default_charlen)       :: recv_fn


    character(len=default_charlen)       :: raw_msg
    integer :: io, cnt, trackno
    logical :: file_exists

    logical :: get_through, correct_data

    n = size(dat)

    write(recv_fn, '(A, "/", A, "_", i0.3, ".tb")') trim(PTI%path), trim(PTI%recv_fn), mod(PTI%recv_trackno-1, PTI%rotate) + 1
    print *, "[ptm_recvData] Expecting filename: ", trim(recv_fn)

    ptm_recvData = 0
    get_through = .false.
    call ptm_busysleep(PTI%recv_first_sleep)

    inquire(file=recv_fn, exist=file_exists)
    if (file_exists .eqv. .true.) then
        get_through = .true.
        if (PTI%recv_first_sleep > PTI%chk_freq) then
            PTI%recv_first_sleep = PTI%recv_first_sleep - PTI%chk_freq
            print *, "[ptm_recvText] Message is already there. Adjust recv_first_sleep to ", PTI%recv_first_sleep
        end if
    else
        do cnt = 1, (PTI%timeout_limit_cnt - PTI%recv_first_cnt)
            inquire(file=recv_fn, exist=file_exists)
            if (file_exists .eqv. .true.) then
                get_through = .true.

                if (cnt > PTI%buffer_cnt) then
                    PTI%recv_first_sleep = PTI%recv_first_sleep + PTI%chk_freq
                    print *, "[ptm_recvText] Out of buffer. Adjust recv_first_sleep to : ", PTI%recv_first_sleep
                end if

                exit
            else
                call ptm_busysleep(PTI%chk_freq)
                cycle
            end if
        end do
    end if


    if (get_through .eqv. .true.) then
        print *, "[ptm_recvText] Got new message"
        ptm_recvData = 0
    else
        ptm_recvData = 1
        print *, "*** [ptm_recvText] No incoming message within timeout. Critical error ***"
        error stop
    end if



    do error_cnt = 1, PTI%error_max 
    
        correct_data = .true.
        print *, "Reading file: ", trim(recv_fn), "; Error Count: ", error_cnt
        ptm_recvData = ptm_readData(recv_fn, PTI%recv_fd, raw_msg, PTI%nchars, dat)
        
        if (ptm_recvData .gt. 0) then
            print *, "[ptm_recvData] ERROR: fail to read data."
            correct_data = .false.
        else

            ptm_recvData = ptm_parseMessage(raw_msg, trackno, msg)
            if (ptm_recvData .gt. 0) then
                print *, "[ptm_recvData] ERROR: Parsing message failed."
                correct_data = .false.
            else if (trackno /= PTI%recv_trackno) then
                print *, "[ptm_recvData] ERROR: Wrong trackno. Expect ", PTI%recv_trackno, ", but got ", trackno, "."
                correct_data = .false.
            end if

        end if

        if (correct_data .eqv. .false.) then
            if (error_cnt .lt. PTI%error_max) then
                print *, "[ptm_recvData] ERROR: Fail to recv data. Sleep and redo..."
                call ptm_busysleep(PTI%error_sleep)
            else
                print *, "[ptm_recvData] ERROR: Fail to recv data. Maximum trail reached." 
                return
            end if
        end if

        if (correct_data .eqv. .true.) then
            exit
        end if
    end do 

    PTI%recv_trackno = PTI%recv_trackno + 1
    !print *, "[ptm_recvData] Received: [", trim(msg) , "]"

    
end function


logical function ptm_messageCompare(msg1, msg2)
    implicit none
    character(*) :: msg1, msg2

    if (trim(adjustl(msg1)) .eq. trim(adjustl(msg2))) then
        ptm_messageCompare = .true.
    else
        ptm_messageCompare = .false.
    end if

end function


! ====================================================================================
! The code of ptm_busysleep is copied from
! stackoverflow.com/questions/6931846/sleep-in-fortran/6936205
! ====================================================================================
subroutine ptm_busysleep(dt)

    implicit none
    integer, dimension(8) :: t             ! arguments for date_and_time
    integer               :: s1,s2,ms1,ms2 ! start and end times [ms]
    integer               :: dt, dt_now    ! desired sleep interval [ms]
   
    if (dt > 86400000) then
        print *, "[ptm_busysleep] dt must be smaller than 86400000"
        error stop
    end if 
    
    call date_and_time(values=t)
    ms1=(t(5)*3600+t(6)*60+t(7))*1000+t(8)

    do
        call date_and_time(values=t)
        ms2=(t(5)*3600+t(6)*60+t(7))*1000+t(8)
        
        dt_now = ms2 - ms1
        if (dt_now < 0) then
            dt_now = dt_now + 86400000
        end if

        if (dt_now>=dt) then
            exit
        end if

    end do

end subroutine


integer function ptm_writeData(fn, fd, msg, nchars, dat)
    implicit none
    character(len=*)         :: fn, msg
    real(8)                  :: dat(:)
    integer                  :: fd, nchars
    
    integer                  :: i, n

    
    n = size(dat)

    if (LEN(msg) > nchars) then
        print *, "ERROR: length of message should be less than ", nchars  ," (including the msg numbering). Now: ", LEN(msg)
        ptm_writeData = 1
        return
    end if
    
    ! Text part
    ptm_writeData = 0    
    open(unit=fd, file=fn, form="formatted", status="REPLACE", &
         access="stream", action="write", iostat=ptm_writeData,  &
         convert='LITTLE_ENDIAN')

    if (ptm_writeData .gt. 0) then
        print *, "[ptm_writeData] Error during open formatted."
        close(fd)
        return
    end if


    ptm_writeData = 0
    write (fd, '(A)', iostat=ptm_writeData, advance="no") msg
    do i=1, nchars - LEN(msg)
        write (fd, '(A)', iostat=ptm_writeData, advance="no") " "
    end do

    if (ptm_writeData .gt. 0) then
        print *, "[ptm_writeData] Error during write ascii message, err code: ", ptm_writeData
        close(fd)
        return
    end if
    close(fd)

    ! Binary part
    ptm_writeData = 0    
    open(unit=fd, file=fn, form="unformatted", status="OLD", &
         access="stream", action="write", iostat=ptm_writeData,  &
         convert='LITTLE_ENDIAN', position="append")

    if (ptm_writeData .gt. 0) then
        print *, "[ptm_writeData] Error during open for binary write."
        close(fd)
        return
    end if


    ptm_writeData = 0
    write (fd, iostat=ptm_writeData, pos=nchars+1) (dat(i), i=1,n,1)
    if (ptm_writeData .gt. 0) then
        print *, "[ptm_writeData] Error during write binary, err code: ", ptm_writeData
        close(fd)
        return
    end if
 
    ptm_writeData = 0
    write (fd, iostat=ptm_writeData, pos=nchars+n*8+1) ptm_calChecksum(dat)
    if (ptm_writeData .gt. 0) then
        print *, "[ptm_writeData] Error during write checksum, err code: ", ptm_writeData
        close(fd)
        return
    end if
   
    close(fd)

end function

integer function ptm_readData(fn, fd, msg, nchars, dat)
    implicit none
    character(len=*)         :: fn, msg
    real(8)                  :: dat(:)
    integer                  :: fd, nchars
    
    integer                  :: i, n, expect_file_size, file_size
    logical                  :: file_exists
    integer(8)               :: calculated_checksum, received_checksum

    n = size(dat)
    !if ((msg) < nchars) then
    !    ptm_readData = 1
    !    print *, "ERROR: msg must be of size >= nchars : ", nchars
    !    return
    !end if


    inquire(file=fn, exist=file_exists)
    if (file_exists .eqv. .false.) then
        print *, "[ptm_readData] ERROR: File does not exist. iostat: ", ptm_readData
        ptm_readData = 1
        return
    end if


    expect_file_size = nchars + 8 * n + 8
    inquire(file=fn, size=file_size)
    if ( file_size /= expect_file_size ) then
        print *, "[ptm_readData] ERROR: Wrong file size. Expect: ", expect_file_size, ", but got ", file_size
        ptm_readData = 1
        return
    end if

    ptm_readData = 0
    open(unit=fd, file=fn, form="unformatted", status="OLD", &
         access="stream", action="read", iostat=ptm_readData,  &
         convert='LITTLE_ENDIAN')

    if (ptm_readData .gt. 0) then
        print *, "[ptm_readData] ERROR: failed to open file. iostat: ", ptm_readData
        close(fd)
        return
    end if
 
    
    ptm_readData = 0
    read (fd, pos=1, iostat=ptm_readData) msg
    if (ptm_readData .gt. 0) then
        print *, "[ptm_readData] Error during read text part. iostat: ", ptm_readData
        close(fd)
        return
    end if

    ptm_readData = 0
    read (fd, pos=nchars+1, iostat=ptm_readData) (dat(i),i=1,n,1)
    if (ptm_readData .gt. 0) then
        print *, "[ptm_readData] Error during read binary part. iostat: ", ptm_readData
        close(fd)
        return
    end if

    ptm_readData = 0
    read (fd, pos=nchars+n*8+1, iostat=ptm_readData) received_checksum
    if (ptm_readData .gt. 0) then
        print *, "[ptm_readData] Error during read checksum. iostat: ", ptm_readData
        close(fd)
        return
    end if

    close(fd)

    calculated_checksum = ptm_calChecksum(dat)
    if (received_checksum /= calculated_checksum) then
        print '(A, Z, A, Z)', "[ptm_readData] ERROR: Checksum does not match. File checksum: ", received_checksum, "; calculated: ", calculated_checksum
        ptm_readData = 1
        return
    endif

    print *, "RECEIVED: ", trim(msg) 
end function

integer function ptm_parseMessage(raw_msg, trackno, real_msg)
    implicit none
    character(len=*) :: raw_msg, real_msg
    integer          :: trackno

    integer          :: index

    raw_msg = trim(adjustl(raw_msg))

    index = scan(raw_msg, "#")
    if (index == 0) then
        ptm_parseMessage = 1
        print *, "indexing failed. Raw message: ", trim(raw_msg)
    else
        read( raw_msg(1:index-1), *)  trackno
        real_msg = raw_msg(index+1:)
        real_msg = trim(adjustl(real_msg))
        ptm_parseMessage = 0
    end if
end function


integer(8) function ptm_calChecksum(dat)
    implicit none
    real(8)       :: dat(:)
    integer(8)    :: dat_int
    integer(8)    :: i, k

    ptm_calChecksum = 0
    k = 0
    do i = 1, size(dat)
        dat_int = transfer(dat(i), dat_int)
        ptm_calChecksum = XOR(ptm_calChecksum, ISHFTC( dat_int, k) )
        k = mod(k+1, 64)
    end do
    !print ('(Z)'), ptm_calChecksum

end function

end module ProgramTunnelMod_fs
