module ft8_decode

  parameter (MAXFOX=1000)
  character*12 c2fox(MAXFOX)
  character*4  g2fox(MAXFOX)
  integer nsnrfox(MAXFOX)
  integer nfreqfox(MAXFOX)
  integer n30fox(MAXFOX)
  integer n30z
  integer nfox
  
  type :: ft8_decoder
     procedure(ft8_decode_callback), pointer :: callback
   contains
     procedure :: decode
  end type ft8_decoder

  abstract interface
     subroutine ft8_decode_callback (this,sync,snr,dt,freq,decoded,nap,qual)
       import ft8_decoder
       implicit none
       class(ft8_decoder), intent(inout) :: this
       real, intent(in) :: sync
       integer, intent(in) :: snr
       real, intent(in) :: dt
       real, intent(in) :: freq
       character(len=37), intent(in) :: decoded
       integer, intent(in) :: nap 
       real, intent(in) :: qual 
     end subroutine ft8_decode_callback
  end interface

contains

  subroutine decode(this,callback,iwave,nQSOProgress,nfqso,nftx,newdat,  &
       nutc,nfa,nfb,ndepth,ncontest,nagain,lft8apon,lapcqonly, &
       napwid,mycall12,hiscall12,hisgrid6)
!    use wavhdr
    use timer_module, only: timer
    include 'ft8/ft8_params.f90'
!    type(hdr) h

    class(ft8_decoder), intent(inout) :: this
    procedure(ft8_decode_callback) :: callback
    parameter (MAXCAND=300)
    real s(NH1,NHSYM)
    real sbase(NH1)
    real candidate(3,MAXCAND)
    real dd(15*12000)
    logical, intent(in) :: lft8apon,lapcqonly,nagain
    logical newdat,lsubtract,ldupe
    character*12 mycall12,hiscall12,mycall12_0
    character*6 hisgrid6
    integer*2 iwave(15*12000)
    integer apsym2(58)
    character datetime*13,msg37*37
!   character message*22
    character*37 allmessages(100)
    integer allsnrs(100)
    data mycall12_0/'dummy'/
    save s,dd,mycall12_0

    if(mycall12.ne.mycall12_0) then
       mycall12_0=mycall12
    endif

    this%callback => callback
    write(datetime,1001) nutc        !### TEMPORARY ###
1001 format("000000_",i6.6)

    call ft8apset(mycall12,hiscall12,apsym2)
    dd=iwave
    ndecodes=0
    allmessages='                                     '
    allsnrs=0
    ifa=nfa
    ifb=nfb
    if(nagain) then
       ifa=nfqso-10
       ifb=nfqso+10
    endif

! For now:
! ndepth=1: no subtraction, 1 pass, belief propagation only
! ndepth=2: subtraction, 3 passes, belief propagation only
! ndepth=3: subtraction, 3 passes, bp+osd
    if(ndepth.eq.1) npass=1
    if(ndepth.ge.2) npass=3
    do ipass=1,npass
      newdat=.true.  ! Is this a problem? I hijacked newdat.
      syncmin=1.5
      if(ipass.eq.1) then
        lsubtract=.true.
        if(ndepth.eq.1) lsubtract=.false.
      elseif(ipass.eq.2) then
        n2=ndecodes
        if(ndecodes.eq.0) cycle
        lsubtract=.true.
      elseif(ipass.eq.3) then
        if((ndecodes-n2).eq.0) cycle
        lsubtract=.false. 
      endif 
      call timer('sync8   ',0)
      maxc=MAXCAND
      call sync8(dd,ifa,ifb,syncmin,nfqso,maxc,s,candidate,   &
           ncand,sbase)
      call timer('sync8   ',1)
      do icand=1,ncand
        sync=candidate(3,icand)
        f1=candidate(1,icand)
        xdt=candidate(2,icand)
        xbase=10.0**(0.1*(sbase(nint(f1/3.125))-40.0))
        nsnr0=min(99,nint(10.0*log10(sync) - 25.5))    !### empirical ###
        call timer('ft8b    ',0)
        call ft8b(dd,newdat,nQSOProgress,nfqso,nftx,ndepth,lft8apon,      &
             lapcqonly,napwid,lsubtract,nagain,ncontest,iaptype,mycall12,   &
             hiscall12,sync,f1,xdt,xbase,apsym2,nharderrors,dmin,           &
             nbadcrc,iappass,iera,msg37,xsnr)
        call timer('ft8b    ',1)
        nsnr=nint(xsnr) 
        xdt=xdt-0.5
        hd=nharderrors+dmin
        if(nbadcrc.eq.0) then
           ldupe=.false.
           do id=1,ndecodes
              if(msg37.eq.allmessages(id).and.nsnr.le.allsnrs(id)) ldupe=.true.
           enddo
           if(.not.ldupe) then
              ndecodes=ndecodes+1
              allmessages(ndecodes)=msg37
              allsnrs(ndecodes)=nsnr
           endif
!           write(81,1004) nutc,ncand,icand,ipass,iaptype,iappass,        &
!                nharderrors,dmin,hd,min(sync,999.0),nint(xsnr),          &
!                xdt,nint(f1),msg37
!1004          format(i6.6,2i4,3i2,i3,3f6.1,i4,f6.2,i5,2x,a37)
!           flush(81)
           if(.not.ldupe .and. associated(this%callback)) then
              qual=1.0-(nharderrors+dmin)/60.0 ! scale qual to [0.0,1.0]
              call this%callback(sync,nsnr,xdt,f1,msg37,iaptype,qual)
           endif
        endif
      enddo
  enddo
  return
  end subroutine decode

end module ft8_decode
