module FFTGF
  use TOOLS 
  use SPLINE
  implicit none 
  private
  public :: cfft_1d_forward,cfft_1d_backward,cfft_1d_shift,swap_fftrt2rw
  public :: fftgf_rw2rt  , fftgf_rt2rw
  public :: fftgf_iw2tau , fftgf_tau2iw
  public :: fftff_iw2tau , fftff_tau2iw
  public :: fftff_iw2tau_
  public :: four1,cosft2,realft

  REAL(8),PARAMETER    :: PI    = 3.14159265358979323846264338327950288419716939937510D0
contains


  !+-------------------------------------------------------------------+
  !PURPOSE  : Evaluate forward and backward FFT using MKL routines.
  !+-------------------------------------------------------------------+
  subroutine nr_radix2_test(M)
    integer :: M
    if(IAND(M,M-1)/=0)then
       print*,"This FFT  is radix_2! abort"
       stop
    endif
  end subroutine nr_radix2_test

  subroutine cfft_1d_forward(func)
    complex(8),dimension(:),intent(inout) :: func
    call nr_radix2_test(size(func))
    call four1(func,size(func),1)
  end subroutine cfft_1d_forward

  subroutine cfft_1d_backward(func)
    complex(8),dimension(:),intent(inout) :: func
    call nr_radix2_test(size(func))
    call four1(func,size(func),-1)
  end subroutine cfft_1d_backward

  function cfft_1d_shift(fin,L) result(fout)
    integer                   :: i,L
    complex(8),dimension(2*L) :: fin
    complex(8),dimension(-L:L):: fout,dout
    forall(i=1:2*L)dout(i-L-1)=fin(i) ![1,2*L]---> [-L,L-1]
    forall(i=-L:-1)fout(i+L)=dout(i)   !g[0,M-1]<--- x[-M,-1]
    forall(i=0:L-1)fout(i-L)=dout(i)   !g[-L,-1]<--- x[0,L-1]
  end function cfft_1d_shift

  subroutine swap_fftrt2rw(func_in)
    integer                             :: i,Nsize,Nhalf
    complex(8),dimension(:)             :: func_in
    complex(8),dimension(size(func_in)) :: dummy
    Nsize=size(func_in) ; Nhalf=Nsize/2
    dummy=func_in
    do i=1,Nhalf
       func_in(i)=dummy(Nhalf+i)
       func_in(Nhalf+i)=dummy(i)
    enddo
  end subroutine swap_fftrt2rw



  !*******************************************************************
  !*******************************************************************
  !*******************************************************************


  !+-------------------------------------------------------------------+
  !PURPOSE  : Evaluate the FFT of a given Green's function from 
  !real frequencies to real time.
  !COMMENTS : INPUT: func_in (of the form 2*M)
  !           INPUT: M size of the half-array
  !           OUTPUT: func_out (-M:M)
  !+-------------------------------------------------------------------+
  subroutine fftgf_rw2rt(func_in,func_out,M)
    integer                                :: i,M
    complex(8),dimension(2*M),intent(in)   :: func_in
    complex(8),dimension(-M:M),intent(out) :: func_out
    complex(8),dimension(2*M)              :: dummy_in
    complex(8),dimension(-M:M)             :: dummy_out
    dummy_in = func_in
    call cfft_1d_forward(dummy_in(1:2*M))
    dummy_out = cfft_1d_shift(dummy_in,M)
    dummy_out(M)=dummy_out(M-1)
    forall(i=-M:M)func_out(i)=dummy_out(-i)
  end subroutine fftgf_rw2rt



  !*******************************************************************
  !*******************************************************************
  !*******************************************************************




  !+-------------------------------------------------------------------+
  !PURPOSE  : Evaluate the FFT of a given Green's function from 
  !real time to real frequency.
  !COMMENTS : INPUT: func_in (of the form -M:M)
  !           INPUT: M size of the half-array
  !           OUTPUT: func_out (2*M)
  !+-------------------------------------------------------------------+
  subroutine fftgf_rt2rw(func_in,func_out,M)
    integer                               :: i,M
    real(8)                               :: ex
    complex(8),dimension(-M:M),intent(in) :: func_in
    complex(8),dimension(2*M),intent(out) :: func_out
    complex(8),dimension(2*M)             :: dummy_out
    forall(i=1:2*M)dummy_out(i) = func_in(i-M-1)
    call cfft_1d_backward(dummy_out)
    ex=-1.d0
    do i=1,2*M
       ex=-ex
       func_out(i)=ex*dummy_out(i)
    enddo
  end subroutine fftgf_rt2rw



  !*******************************************************************
  !*******************************************************************
  !*******************************************************************





  !+-------------------------------------------------------------------+
  !PURPOSE  : Evaluate the FFT of a given function from Matsubara frequencies
  ! to imaginary time. 
  !COMMENT  : The routine implements all the necessary manipulations required 
  !by the FFT in this formalism: tail subtraction and reshaping. 
  !Output is only for tau\in[0,beta]
  !if g(-tau) is required this has to be implemented in the calling code
  !using the transformation: g(-tau)=-g(beta-tau) for tau>0
  !+-------------------------------------------------------------------+
  subroutine fftgf_iw2tau(gw,gt,beta,notail)
    implicit none
    integer                             :: i,n,L
    logical,optional                    :: notail
    logical                             :: notail_
    complex(8),dimension(:)             :: gw
    real(8),dimension(0:)               :: gt
    complex(8),dimension(:),allocatable :: tmpGw,xGt
    real(8),dimension(:),allocatable    :: tmpGt
    complex(8)                          :: tail
    real(8)                             :: wmax,beta,mues,tau,dtau,At,w
    notail_=.false.;if(present(notail))notail_=notail
    !
    n=size(gw)     ; L=size(gt)-1 ; dtau=beta/real(L,8) 
    !
    allocate(tmpGw(2*L),tmpGt(-L:L))
    !
    wmax = pi/beta*real(2*N-1,8)
    mues =-dreal(gw(N))*wmax**2
    tmpGw=(0.d0,0.d0)
    !
    select case(notail_)
    case default
       do i=1,L
          w=pi/beta*dble(2*i-1)
          tail=-(mues+w*(0.d0,1.d0))/(mues**2+w**2)
          if(i<=n)tmpGw(2*i)= gw(i)-tail
          if(i>n)tmpGw(2*i) = tail
       enddo
       call cfft_1d_backward(tmpGw)
       tmpGt = real(cfft_1d_shift(tmpGw,L),8)*2.d0/beta
       do i=0,L
          tau=dble(i)*beta/dble(L)
          At=-exp((beta-tau)*mues)/(exp(beta*mues)+1.d0)
          tmpGt(i)=tmpGt(i)+At
       enddo
       gt(0:L-1) = tmpGt(0:L-1)
       gt(L)=-gt(0)-1.d0

    case(.true.)
       if(L/=n)then
          print*,"error in fftgf_iw2tau: call w/ notail and L>n"
          stop
       endif
       allocate(xGt(-L:L))
       forall(i=1:L)tmpGw(2*i)  = gw(i)
       call fftgf_rw2rt(tmpGw,xGt,L)
       gt(0:L-1)=real(xGt(0:L-1),8)*2.d0/beta
       gt(L)=-gt(0)
       deallocate(xGt)
    end select
    deallocate(tmpGw,tmpGt)
  end subroutine fftgf_iw2tau

  subroutine fftff_iw2tau_(gw,gt,beta)
    integer                             :: i,n,L,itau,M
    complex(8),dimension(:)             :: gw
    real(8),dimension(size(gw))         :: wm
    complex(8),dimension(0:)            :: gt
    real(8)                             :: wmax,beta,mues,tau,dtau,At,w
    n=size(gw) ; L=size(gt)-1
    if(L/=N)then
       print*,"error in fftgf_iw2tau: call w/ notail and L/=N"
       stop
    endif
    dtau=beta/real(L,8) 
    gt = (0.d0,0.d0)
    forall(i=1:n)wm(i)=pi/beta*real(2*i-1,8)
    forall(i=0:L)gt(i)=sum(cos(real(i,8)*dtau*wm(:))*gw(:))
    gt=gt*2.d0/beta
  end subroutine fftff_iw2tau_

  subroutine fftff_iw2tau(gw,gt,beta)
    integer                             :: i,n,L,itau,M
    complex(8),dimension(:)             :: gw
    real(8),dimension(2*size(gw))       :: reF,imF,tau_long
    complex(8),dimension(0:size(gw))    :: gt
    real(8)                             :: beta,dtau
    real(8),dimension(0:size(gw))       :: tau_short
    N=size(gw) ; L=size(gt)-1
    if(L/=N)then
       print*,"error in fftff_iw2tau: L/=N"
       stop
    endif
    N=2*L
    reF=0.d0 ; imF=0.d0
    forall(i=1:L)
       reF(2*i) = real(gw(i),8)
       imF(2*i) = aimag(gw(i))
    end forall
    call cosft2(reF,2*L,-1)
    call cosft2(imF,2*L,-1)
    tau_long = linspace(0.d0,beta,2*L)
    tau_short= linspace(0.d0,beta,L+1)
    call linear_spline(cmplx(reF,imF,8),tau_long,gt,tau_short)
    gt(L)=-gt(0)
    gt=gt/beta*2.d0
  end subroutine fftff_iw2tau
  !*******************************************************************
  !*******************************************************************
  !*******************************************************************





  !+-------------------------------------------------------------------+
  !PURPOSE  : 
  !+-------------------------------------------------------------------+
  subroutine fftgf_tau2iw(gt,gw,beta)
    real(8)                :: gt(0:)
    complex(8)             :: gw(:)
    real(8)                :: beta
    integer                :: i,L,n,M
    complex(8),allocatable :: Igw(:)
    real(8),allocatable    :: Igt(:)
    L=size(gt)-1    ; N=size(gw)
    M=32*L
    allocate(Igt(-M:M),Igw(2*M))
    call interp(gt(0:L),Igt(0:M),L,M)
    forall(i=1:M)Igt(-i)=-Igt(M-i)
    call fftgf_rt2rw((1.d0,0.d0)*Igt,Igw,M)
    Igw=Igw*beta/real(M,8)/2.d0
    forall(i=1:n)gw(i)=-Igw(2*i)
    deallocate(Igt,Igw)
  contains
    include "splinefft.f90" !This is taken from SPLINE to make this module independent    
  end subroutine fftgf_tau2iw

  subroutine fftff_tau2iw(gt,gw,beta)
    complex(8)             :: gt(0:)
    complex(8)             :: gw(:)
    real(8)                :: beta
    integer                :: i,L,n,M
    real(8),allocatable    :: reGt(:),imGt(:)
    complex(8),allocatable :: Igw(:),Igt(:)
    L=size(gt)-1    ; N=size(gw)
    M=32*L
    allocate(Igt(-M:M),Igw(2*M))
    allocate(reGt(0:M),imGt(0:M))
    call interp(real(gt(0:L),8),reGt(0:M),L,M)
    call interp(aimag(gt(0:L)),imGt(0:M),L,M)
    Igt(0:M)=cmplx(reGt(0:M),imGt(0:M),8)
    !
    forall(i=1:M)Igt(-i)=-Igt(M-i) !Valid for every fermionic GF (bosonic case not here)
    call fftgf_rt2rw(Igt,Igw,M)
    Igw=Igw*beta/real(M,8)/2.d0
    forall(i=1:n)gw(i)=Igw(2*i)
    deallocate(Igt,Igw)
  contains
    include "splinefft.f90" !This is taken from SPLINE to make this module independent    
  end subroutine fftff_tau2iw




  !*******************************************************************
  !*******************************************************************
  !*******************************************************************




  !+-------------------------------------------------------------------+
  !PROGRAM  : FOUR1, COSFT2, REALFT
  !TYPE     : Subroutines
  !PURPOSE  : adapted from Num. Rec. 
  !+-------------------------------------------------------------------+
  subroutine cosft2(y,n,isign)
    integer :: i,isign,n
    real(8) :: y(n)
    real(8) ::  sum,sum1,y1,y2,ytemp
    real(8) ::  theta,wi,wi1,wpi,wpr,wr,wr1,wtemp
    theta=0.5d0*pi/n
    wr=1.0d0
    wi=0.0d0
    wr1=cos(theta)
    wi1=sin(theta)
    wpr=-2.0d0*wi1**2
    wpi=sin(2.d0*theta)
    if(isign.eq.1)then
       do i=1,n/2
          y1=0.5*(y(i)+y(n-i+1))
          y2=wi1*(y(i)-y(n-i+1))
          y(i)=y1+y2
          y(n-i+1)=y1-y2
          wtemp=wr1
          wr1=wr1*wpr-wi1*wpi+wr1
          wi1=wi1*wpr+wtemp*wpi+wi1
       enddo
       call realft(y,n,1)
       do i=3,n,2
          wtemp=wr
          wr=wr*wpr-wi*wpi+wr
          wi=wi*wpr+wtemp*wpi+wi
          y1=y(i)*wr-y(i+1)*wi
          y2=y(i+1)*wr+y(i)*wi
          y(i)=y1
          y(i+1)=y2
       enddo
       sum=0.5*y(2)
       do i=n,2,-2
          sum1=sum
          sum=sum+y(i)
          y(i)=sum1
       enddo
    else if(isign.eq.-1)then
       ytemp=y(n)
       do i=n,4,-2
          y(i)=y(i-2)-y(i)
       enddo
       y(2)=2.0*ytemp
       do i=3,n,2
          wtemp=wr
          wr=wr*wpr-wi*wpi+wr
          wi=wi*wpr+wtemp*wpi+wi
          y1=y(i)*wr+y(i+1)*wi
          y2=y(i+1)*wr-y(i)*wi
          y(i)=y1
          y(i+1)=y2
       enddo
       call realft(y,n,-1)
       do i=1,n/2
          y1=y(i)+y(n-i+1)
          y2=(0.5/wi1)*(y(i)-y(n-i+1))
          y(i)=0.5*(y1+y2)
          y(n-i+1)=0.5*(y1-y2)
          wtemp=wr1
          wr1=wr1*wpr-wi1*wpi+wr1
          wi1=wi1*wpr+wtemp*wpi+wi1
       enddo
    endif
  end subroutine cosft2

  subroutine realft(data,n,isign)
    integer :: isign,n
    real(8) :: data(n)
    integer ::  i,i1,i2,i3,i4,n2p3
    real(8) ::  c1,c2,h1i,h1r,h2i,h2r,wis,wrs
    real(8) ::  theta,wi,wpi,wpr,wr,wtemp
    theta=3.141592653589793d0/dble(n/2)
    c1=0.5
    if (isign.eq.1) then
       c2=-0.5
       call rfour1(data,n/2,+1)
    else
       c2=0.5
       theta=-theta
    endif
    wpr=-2.0d0*sin(0.5d0*theta)**2
    wpi=sin(theta)
    wr=1.0d0+wpr
    wi=wpi
    n2p3=n+3
    do i=2,n/4
       i1=2*i-1
       i2=i1+1
       i3=n2p3-i2
       i4=i3+1
       wrs=sngl(wr)
       wis=sngl(wi)
       h1r=c1*(data(i1)+data(i3))
       h1i=c1*(data(i2)-data(i4))
       h2r=-c2*(data(i2)+data(i4))
       h2i=c2*(data(i1)-data(i3))
       data(i1)=h1r+wrs*h2r-wis*h2i
       data(i2)=h1i+wrs*h2i+wis*h2r
       data(i3)=h1r-wrs*h2r+wis*h2i
       data(i4)=-h1i+wrs*h2i+wis*h2r
       wtemp=wr
       wr=wr*wpr-wi*wpi+wr
       wi=wi*wpr+wtemp*wpi+wi
    enddo
    if (isign.eq.1) then
       h1r=data(1)
       data(1)=h1r+data(2)
       data(2)=h1r-data(2)
    else
       h1r=data(1)
       data(1)=c1*(h1r+data(2))
       data(2)=c1*(h1r-data(2))
       call rfour1(data,n/2,-1)
    endif
    return
  end subroutine realft

  !This routine is modified version w/ respect to original NumRec!
  !Below is the original one renamed rfour1 (real input twice the size)
  subroutine four1(Fct,nn,isign)
    implicit none
    integer    :: nn, isign
    complex(8) :: Fct(nn)
    integer    :: i, istep, j, m, mmax, n
    real(8)    :: Fcttmp(2*nn)
    real(8)    :: tempi, tempr
    real(8)    :: theta, wi, wpi, wpr, wr, wtemp
    do i=1, nn
       Fcttmp(2*i-1) = real(Fct(i))
       Fcttmp(2*i)   = aimag(Fct(i))
    enddo
    n = 2*nn
    j = 1
    do i=1, n, 2
       if(j .gt. i)then
          tempr = Fcttmp(j)
          tempi = Fcttmp(j+1)
          Fcttmp(j)   = Fcttmp(i)
          Fcttmp(j+1) = Fcttmp(i+1)
          Fcttmp(i)   = tempr
          Fcttmp(i+1) = tempi
       endif
       m = n/2
       do while((m .ge. 2) .and. (j .gt. m))
          j = j-m
          m = m/2
       enddo
       j = j+m
    enddo
    mmax = 2
    do while(n .gt. mmax)
       istep = 2*mmax
       theta = 6.28318530717959d0/(isign*mmax)
       wpr = -2.d0*dsin(0.5d0*theta)**2
       wpi = dsin(theta)
       wr = 1.d0
       wi = 0.d0
       do m=1, mmax, 2
          do i=m, n, istep
             j = i+mmax
             tempr = sngl(wr)*Fcttmp(j)-sngl(wi)*Fcttmp(j+1)
             tempi = sngl(wr)*Fcttmp(j+1)+sngl(wi)*Fcttmp(j)
             Fcttmp(j)   = Fcttmp(i)-tempr
             Fcttmp(j+1) = Fcttmp(i+1)-tempi
             Fcttmp(i)   = Fcttmp(i)+tempr
             Fcttmp(i+1) = Fcttmp(i+1)+tempi
          enddo
          wtemp = wr
          wr = wr*wpr-wi*wpi+wr
          wi = wi*wpr+wtemp*wpi+wi
       enddo
       mmax = istep
    enddo
    do i=1, nn
       Fct(i) = cmplx(Fcttmp(2*i-1),Fcttmp(2*i),8)
    enddo
  end subroutine four1

  subroutine rfour1(data,nn,isign)
    integer :: isign,nn
    real(8) :: data(2*nn)
    integer :: i,istep,j,m,mmax,n
    real(8) ::  tempi,tempr
    real(8) ::  theta,wi,wpi,wpr,wr,wtemp
    n=2*nn
    j=1
    do i=1,n,2
       if(j.gt.i)then
          tempr=data(j)
          tempi=data(j+1)
          data(j)=data(i)
          data(j+1)=data(i+1)
          data(i)=tempr
          data(i+1)=tempi
       endif
       m=nn
1      if ((m.ge.2).and.(j.gt.m)) then
          j=j-m
          m=m/2
          goto 1
       endif
       j=j+m
    enddo
    mmax=2
2   if (n.gt.mmax) then
       istep=2*mmax
       theta=6.28318530717959d0/(isign*mmax)
       wpr=-2.d0*sin(0.5d0*theta)**2
       wpi=sin(theta)
       wr=1.d0
       wi=0.d0
       do m=1,mmax,2
          do i=m,n,istep
             j=i+mmax
             tempr=sngl(wr)*data(j)-sngl(wi)*data(j+1)
             tempi=sngl(wr)*data(j+1)+sngl(wi)*data(j)
             data(j)=data(i)-tempr
             data(j+1)=data(i+1)-tempi
             data(i)=data(i)+tempr
             data(i+1)=data(i+1)+tempi
          enddo
          wtemp=wr
          wr=wr*wpr-wi*wpi+wr
          wi=wi*wpr+wtemp*wpi+wi
       enddo
       mmax=istep
       goto 2
    endif
    return
  end subroutine rfour1

  !*******************************************************************
  !*******************************************************************
  !*******************************************************************


end module FFTGF
