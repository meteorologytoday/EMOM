module ProgramTunnelMod_fs
implicit none

type ptm_ProgramTunnelInfo
    Integer :: recv_cnt
    Integer :: send_cnt
    Integer :: recv_fd
    Integer :: send_fd
    Integer :: lock_fd


    character(len = 256) :: recv_fn
    character(len = 256) :: send_fn
    character(len = 256) :: lock_fn

    integer :: chk_freq
    integer :: timeout
    integer :: timeout_limit_cnt

    integer :: buffer
    integer :: buffer_cnt
    integer :: recv_first_sleep
    integer :: recv_first_cnt


end type


contains

subroutine ptm_setDefault(PTI, fds)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI
    Integer :: fds(:)

    PTI%recv_fn  = "ProgramTunnel-Y2X.txt"
    PTI%send_fn  = "ProgramTunnel-X2Y.txt"
 
    PTI%lock_fn  = "ProgramTunnel-lock"

    PTI%recv_cnt = 0
    PTI%send_cnt = 0

    PTI%recv_fd = fds(1)
    PTI%send_fd = fds(2)
    PTI%lock_fd = fds(3)

    PTI%chk_freq = 50          ! millisecs (0.05 secs)
    PTI%timeout  = 30 * 1000   ! millisecs (30 secs)

    PTI%buffer   =  200        ! millisecs (0.2 secs)
    PTI%buffer_cnt = 40        ! A buffer cnt is a chk_freq
    PTI%recv_first_sleep = 0
    PTI%recv_first_cnt = 0


    call ptm_autoCalculateCnt(PTI)
end subroutine 


subroutine ptm_autoCalculateCnt(PTI)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI
    PTI%timeout_limit_cnt = ceiling(real(PTI%timeout)          / real(PTI%chk_freq))
    PTI%buffer_cnt        = ceiling(real(PTI%buffer)           / real(PTI%chk_freq))
    PTI%recv_first_cnt    = ceiling(real(PTI%recv_first_sleep) / real(PTI%chk_freq))
end


subroutine ptm_printSummary(PTI)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI

    print *, "[PTI] recv_fn: ", trim(PTI%recv_fn)
    print *, "[PTI] send_fn: ", trim(PTI%send_fn)
    print *, "[PTI] lock_fn: ", trim(PTI%lock_fn)
    print *, "[PTI] chk_freq:", PTI%chk_freq

end subroutine



subroutine ptm_appendPath(PTI, path)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI
    character(len=256) :: path

    PTI%recv_fn  = trim(path) // "/" // trim(PTI%recv_fn)
    PTI%send_fn  = trim(path) // "/" // trim(PTI%send_fn)
    PTI%lock_fn  = trim(path) // "/" // trim(PTI%lock_fn)

end subroutine 

subroutine ptm_obtainLock(PTI, stat)
    type(ptm_ProgramTunnelInfo) :: PTI
    integer                      :: stat

    logical :: file_exists
    integer :: io

    logical :: get_through
    integer :: cnt

    get_through = .false.

    print *, "Getting lock...", trim(PTI%lock_fn)
    do cnt = 1, ceiling(real(PTI%timeout) / real(PTI%chk_freq))

        ! try to get lock
        inquire(file=PTI%lock_fn, exist=file_exists)
        
        if (file_exists .eqv. .true.) then
            call ptm_busySleep(PTI%chk_freq)
            cycle
        end if
       

        ! Try to create a file 
        io = 0
        open(unit=PTI%lock_fd, file=PTI%lock_fn, form="formatted", access="stream", action="write", iostat=io)
        close(PTI%lock_fd)
        if (io == 0) then
            ! If we did open a file then leave
            get_through = .true.        
            print *, "Lock got"

            exit
        end if

        ! But if open file fails then try again
        call ptm_busySleep(PTI%chk_freq)

    end do 

    if (get_through .eqv. .true.) then
        stat = 0
    else
        stat = 1
        print *, "*** Timeout getting lock! Critical error ***"
        error stop
    end if

end subroutine

subroutine ptm_releaseLock(PTI)
    type(ptm_ProgramTunnelInfo) :: PTI
    call ptm_delFile(PTI%lock_fn, PTI%lock_fd)
end subroutine

subroutine ptm_delFile(fn, fd)
    implicit none
    integer :: fd
    character(len=*) :: fn

    open(unit=fd, file=fn, status="old")
    close(unit=fd, status="delete")

end subroutine


subroutine ptm_delFile_until_gone(fn, fd)
    implicit none
    integer :: fd, io
    character(len=*) :: fn
    logical :: file_exists

    do 
        inquire(file=fn, exist=file_exists)
        if (file_exists .eqv. .true.) then
            open(unit=fd, file=fn, status="old", iostat=io)
            close(unit=fd, status="delete")
            if (io == 0) then
                exit
            end if
        else
            exit
        end if
    end do

end subroutine

subroutine ptm_clean(PTI)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI

    call ptm_delFile(PTI%recv_fn, PTI%recv_fd)
    call ptm_delFile(PTI%send_fn, PTI%send_fd)
end subroutine


integer function ptm_recvText(PTI, msg)
    implicit none
    type(ptm_ProgramTunnelInfo)  :: PTI
    character(len=*)       :: msg

    integer :: io, cnt
    logical :: file_exists

    logical :: get_through

    ptm_recvText = 0
    
    print *, "[ptm_recvText] Detecting if new message exists."
    get_through = .false.
    call ptm_busysleep(PTI%recv_first_sleep)

    inquire(file=PTI%recv_fn, exist=file_exists)
    if (file_exists .eqv. .true.) then
        get_through = .true.
        if (PTI%recv_first_sleep > PTI%chk_freq) then
            PTI%recv_first_sleep = PTI%recv_first_sleep - PTI%chk_freq
            print *, "[ptm_recvText] Message is already there. Adjust recv_first_sleep to ", PTI%recv_first_sleep
        end if
    else
        do cnt = 1, (PTI%timeout_limit_cnt - PTI%recv_first_cnt)
!            print *, "[ptm_recvText] test"
            inquire(file=PTI%recv_fn, exist=file_exists)
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
        ptm_recvText = 0
    else
        ptm_recvText = 1
        print *, "*** [ptm_recvText] No incoming message within timeout. Critical error ***"
        error stop
    end if

    call ptm_obtainLock(PTI, ptm_recvText)
    if (ptm_recvText /= 0 ) then
        print *, "[ptm_recvText] Can't obtain lock. iostat: ", ptm_recvText
        return
    end if
    
    ptm_recvText = 0
    open(unit=PTI%recv_fd, file=PTI%recv_fn, form="formatted", access="stream", action="read", iostat=ptm_recvText)
    
    read (PTI%recv_fd, '(A)', iostat=ptm_recvText) msg
    close(PTI%recv_fd)
    
    msg = trim(msg)
    print *, "[ptm_recvText] Received: [", trim(msg) , "]"

    call ptm_delFile_until_gone(PTI%recv_fn, PTI%recv_fd)
    call ptm_releaseLock(PTI)
    
end function


integer function ptm_sendText(PTI, msg)
    implicit none
    type(ptm_ProgramTunnelInfo)  :: PTI
    character(len=*)       :: msg
    character(len=1024)    :: double_chk_msg

    ptm_sendText = 0
    call ptm_obtainLock(PTI, ptm_sendText)
    if (ptm_sendText /= 0 ) then
        return
    end if

    ptm_sendText = 0
    open(unit=PTI%send_fd, file=PTI%send_fn, form="formatted", access="stream", action="write", iostat=ptm_sendText)
    if (ptm_sendText /= 0) then
        print *, "Create send file iostat: ", ptm_sendText
        return
    end if

   
    do

        ptm_sendText = 0
        write (PTI%send_fd, *, iostat=ptm_sendText) msg
        if (ptm_sendText /= 0) then
            print *, "Output send file iostat: ", ptm_sendText
            return
        end if
        close(PTI%send_fd)

        ptm_sendText = 0
        double_chk_msg = ""
        open(unit=PTI%send_fd, file=PTI%send_fn, form="formatted", access="stream", action="read", iostat=ptm_sendText)
        read (PTI%send_fd, '(A)', iostat=ptm_sendText) double_chk_msg
        close(PTI%send_fd)
      
        !print *, "msg:[", trim(msg), "]#[", trim(double_chk_msg), "]"
        !print *, "msglen:", len_trim(msg), "#", len_trim(double_chk_msg)
 
        if (ptm_messageCompare(msg, double_chk_msg) .eqv. .true.) then
            exit
        end if

    end do

    call ptm_releaseLock(PTI)

    print *, "[ptm_sendText] Text sent and checked."

end function

subroutine ptm_hello(PTI)
    implicit none
    type(ptm_ProgramTunnelInfo) :: PTI
    character(256) :: msg

    integer :: stat

    stat = ptm_recvText(PTI, msg)
    if (stat /= 0) then
        print *, "Something went wrong during recv stage... exit"
        return
    end if

    if (ptm_messageCompare(msg, "<<TEST>>")) then
        print *, "Recv hello!"
    else
        print *, len(msg), " : ", len("<<TEST>>")
        print *, "Weird msg: [", msg, "]"
    end if

    stat = ptm_sendText(PTI, "<<TEST>>")
    if (stat /= 0) then
        print *, "Something went wrong during send stage... exit"
        return
    end if


end subroutine

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


end module ProgramTunnelMod_fs
