!=============================================================================80
!                       Metropolis Monte Carlo Code Grid
!==============================================================================!
!       Discussion:
!Implement a gaussian pair-potential
!start with 2D Morse Potential
!!!!!!Initial distribution is wrong, need to start there, try using old 2D morse code
!==============================================================================!
!       Modified:
!   30 May 2019
!       Author:
!   Shane Flynn 
!==============================================================================!
module lj_mod
implicit none
!==============================================================================!
!                            Global Variables 
!==============================================================================!
!d              ==> Particle Dimensionality
!c_LJ           ==> parameter for LJ
!E_cut          ==> Energy Cutoff for Particle Center
!integral_P     ==> Area under the curve for P
!x,y min/max     ==> Domain for P(x)
!==============================================================================!
integer::d,Npoints
double precision::c_LJ,E_cut,integral_P 
!==============================================================================!
contains
  !==============================================================================!
  function random_integer(Nmin,Nmax) 
    !==============================================================================!
    !       Discussion:
    !Randomly generate an integer in the range 1-Npoints
    !       Variables:
    !Nmin           ==> minimum index value (1)
    !Nmax           ==> maximum index value (Npoints)
    !random_integer ==> integer returned
    !a              ==> Fortran intrinsic random number [0,1]
    !==============================================================================!
    implicit none
    integer::Nmin,Nmax,random_integer
    double precision::a
    call random_number(a)
    random_integer=floor(a*(Nmax-Nmin+1))+Nmin
  end function random_integer
  !==============================================================================!
  function V(x)
    !==============================================================================!
    !       Discussion:
    !Potential Energy (Hard-Coded 2D Morse)
    !V            ==> evaluate V(x,y)
    !x_i            ==>(d) ith particles coordinate x^i_1,..,x^i_d
    !D_morse        ==> morse constant
    !==============================================================================!
    implicit none 
    double precision::x(d),V
    double precision,parameter::omega(2)=(/0.2041241,0.18371169/)
    double precision,parameter::D_morse=12.
    V=D_morse*sum((exp(-omega(:)*x(:))-1.)**2)
  end function V
  !==============================================================================!
  subroutine Moments_Reg(Moment,N,xmin,xmax)
    !==============================================================================!
    ! The moments are computed using a regular square grid. This is the most accurate and the best for 3d case
    !==============================================================================!
    integer :: N,i1,i2,i3,j
    double precision :: r(d),xmin(d),xmax(d),Moment(0:5),dummy
    Moment=0d0
    do i1=0,N
       do i2=0,N
             r(1)=xmin(1)+i1*(xmax(1)-xmin(1))/N
             r(2)=xmin(2)+i2*(xmax(2)-xmin(2))/N
             dummy=P(r)
             Moment(0)=Moment(0)+dummy
             do j=1,d
                Moment(j)=Moment(j)+dummy*r(j)
                Moment(d+j)=Moment(d+j)+dummy*r(j)**2
             enddo
             Moment(5)=Moment(5)+dummy*r(1)*r(2)
          enddo
       enddo
    dummy=1./N**d
    do j=1,d
       dummy=dummy*(xmax(j)-xmin(j))
    enddo
    integral_P=dummy*Moment(0)
    Moment(1:5)=Moment(1:5)/Moment(0)
  end subroutine Moments_Reg
!==============================================================================!
  subroutine Moments_MC(Moment,N_MC,xmin,xmax)
    !==============================================================================!
    !   The moments are computed using Monte Carlo method (not Metropolis MC)
    !==============================================================================!
    integer :: N_MC,i,j
    double precision :: r(d),xmin(d),xmax(d),Moment(0:5),dummy
    Moment=0d0
    do i=1,N_MC
       call random_number(r)
       r(:)=xmin(:)+r(:)*(xmax(:)-xmin(:))
       dummy=P(r)
       Moment(0)=Moment(0)+dummy
       do j=1,d
          Moment(j)=Moment(j)+dummy*r(j)
          Moment(d+j)=Moment(d+j)+dummy*r(j)**2
       enddo
       Moment(5)=Moment(5)+dummy*r(1)*r(2)
    enddo
    dummy=1./N_MC
    do i=1,d
       dummy=dummy*(xmax(i)-xmin(i))
    enddo
    integral_P=dummy*Moment(0)
    Moment(1:5)=Moment(1:5)/Moment(0)
  end subroutine Moments_MC
    !==============================================================================!
  subroutine Moments_MMC(Moment,N_MC,xmin,xmax)
    !==============================================================================!
    ! Compute the moments using Metropolis MC and determin the box sizes (xmin,xmax)
    !==============================================================================!
    integer :: N_MC,i,j
    double precision :: Moment(0:5),dummy,r_trial(d),r(d),s(d),xmin(d),xmax(d)
    double precision, parameter :: mv_cutoff=0.1
    Moment=0d0
    r=0d0
    xmin=r
    xmax=r
    do i=1,N_MC
       !==============================================================================!
       !                   Generate coordinates for Random move trial
       !random numbers generated (0,1), make it (-1,1) ==> s=2*s-1
       !==============================================================================!
       call random_number(s) 
       r_trial=r+mv_cutoff*(2*s-1)
       !==============================================================================!
       !               Test to see if you should accept 
       !==============================================================================!
       call random_number(dummy) 
       if(P(r_trial)/P(r).ge.dummy) then
          r=r_trial
          do j=1,d
             if(xmin(j)>r(j)) xmin(j)=r(j)
             if(xmax(j)<r(j)) xmax(j)=r(j)
          enddo
       endif
       do j=1,d
          Moment(j)=Moment(j)+r(j)
          Moment(d+j)=Moment(d+j)+r(j)**2
       enddo
       Moment(5)=Moment(5)+r(1)*r(2)
    enddo
    Moment=Moment/N_MC
  end subroutine Moments_MMC
    !==============================================================================!
  subroutine Moments(Moment,x)
    !==============================================================================!
    !Compute the moments for a set of points
    !==============================================================================!
    integer :: i,j
    double precision :: Moment(0:5),x(d,Npoints)
    Moment=0d0
    do i=1,Npoints
       do j=1,d
          Moment(j)=Moment(j)+x(j,i)
          Moment(d+j)=Moment(d+j)+x(j,i)**2
       enddo
       Moment(5)=Moment(5)+x(1,i)*x(2,i)
    enddo
    Moment(1:5)=Moment(1:5)/Npoints
  end subroutine Moments
  !==============================================================================!
  function P(x)
    !==============================================================================!
    !       Discussion:
    !Target Distribution Function
    !==============================================================================!
    implicit none 
    double precision::x(d),P
    if(V(x)<E_cut) then
       P=(E_cut-V(x))/integral_P          
    else        !set equal to 0 if beyond Ecut
       P=1d-20
    end if
  end function P
!  !==============================================================================!
!  function Pair_Gaus_NRG(x1,x2)
!    !==============================================================================!
!    !       Discussion:
!    !computes quasi LJ energy between 2 particles
!    !       Variables:
!    !x_i            ==>(d) ith atoms coordinates
!    !x_j            ==>(d) jth atoms coordinates
!    !a              ==> evaluate LJ
!    !sigma1/2       ==> c*sigma(P)
!    !Pair_LJ_NRG    ==> Energy of the i-j LJ potential
!    !==============================================================================!
!    implicit none 
!    double precision,parameter::gama=0.1
!    double precision::x1(d),x2(d),xij,a,b,Pair_Gaus_NRG,sigma1,sigma2
!    xij=sqrt(sum((x1(:)-x2(:))**2))
!    sigma1=c_LJ*(P(x1)*Npoints)**(-1./d)    
!    sigma2=c_LJ*(P(x2)*Npoints)**(-1./d)    
!    a=-exp(-(xij-sigma1)**2/(gama*sigma1)**2)
!    b=-exp(-(xij-sigma2)**2/(gama*sigma2)**2)
!    Pair_Gaus_NRG=a+b
!  end function Pair_Gaus_NRG
!  !==============================================================================!
  function Pair_LJ_NRG(x1,x2)
    !==============================================================================!
    !       Discussion:
    !computes quasi LJ energy between 2 particles
    !       Variables:
    !x_i            ==>(d) ith atoms coordinates
    !x_j            ==>(d) jth atoms coordinates
    !a              ==> evaluate LJ
    !sigma1/2       ==> c*sigma(P)
    !Pair_LJ_NRG    ==> Energy of the i-j LJ potential
    !==============================================================================!
    implicit none 
    double precision::x1(d),x2(d),a,b,Pair_LJ_NRG,sigma1,sigma2
    a=sum((x1(:)-x2(:))**2)
    sigma1=c_LJ*(P(x1)*Npoints)**(-1./d)    
    sigma2=c_LJ*(P(x2)*Npoints)**(-1./d)    
    b=(sigma2**2/a)**4
    a=(sigma1**2/a)**4
    Pair_LJ_NRG=a**2-a+b**2-b
  end function Pair_LJ_NRG
  !==============================================================================!
end module lj_mod
!==============================================================================!
!==============================================================================!
program main
  use lj_mod
  !==============================================================================!
  !       Discussion:
  !==============================================================================!
  !d              ==> i-th particle dimensionality (x^i=x^i_1,x^i_2,..,x^i_d)
  !Npoints     ==> Number of gridpoints
  !N_Px           ==> Number of mmc iterations to normalize P
  !N_MC            ==> Number of MMC steps to execute
 !x              ==>(dimen) all atom coordinates
  !U              ==>(Npoints,Npoints) All i,j pair-wise energies (LJ-12-6)
  !U_move         ==>(Npoints)  LJ-Energy associated with trial movement
  !mv_cutoff      ==> maximum displacement parameter for trial displacement
  !x0             ==>(d) store previous coordinate before trial move
  !acc_coef       ==> scaling coefficient for making acceptance rate ~50%
  !Delta_E        ==> change in energy due to potential
  !t1             ==> random number for accepting higher energy movement
  !s              ==>(d) random number to move coordinate by
  !MMC_freq       ==> Interval to update mv_cutoff size
  !accept         ==> number of accepted trial moves, for acceptance~50%  
  !counter        ==> total number of moves, for acceptance~50%
  !t_i,t_f        ==> cpu time to ~ simulation time
  !==============================================================================!
  implicit none
  integer::N_MC,N_MC_moments,N_reg,MMC_freq,N_Px,accept,counter,i,j,k,n,plt_count
  double precision::Delta_E,mv_cutoff,t1,time1,time2,Moment(0:9)
  double precision,allocatable,dimension(:)::x0,s,U_move,alpha,xmin(:),xmax(:)
  double precision,allocatable,dimension(:,:)::x,U
  real(kind=16)::deltae1
  !==============================================================================!
  !                           Read Input Data File                               !
  !==============================================================================!
  call cpu_time(time1)
  read(*,*) d
  read(*,*) Npoints
  read(*,*) N_MC_moments  !number of MC moves using Monte carlo to compute the moments
  read(*,*) N_reg     !number of grid points each dimension using regular grid 
  read(*,*) N_MC     !number of MC moves to distribute the points
  read(*,*) MMC_freq  
  read(*,*) E_cut
  read(*,*) c_LJ
  !==============================================================================!
  !                               Allocations
  !==============================================================================!
  allocate(x(d,Npoints),x0(d),s(d),U(Npoints,Npoints),U_move(Npoints),xmin(d),xmax(d))
  allocate(alpha(Npoints))
  write(*,*) 'Test 0; Successfully Read Input File'
  !==============================================================================!
  !                   Run some Monte Carlo
  !==============================================================================!
  integral_P=1d0              !set equal to 1 so you can initially call P
  call Moments_MMC(Moment,N_MC_moments,xmin,xmax)
  write(*,*) 'Moments from Metropolis MC using N_MC=',N_MC_moments
  write(*,*) Moment(1:5)
  do i=1,d
     write(*,*) i,' xmin xmax ==>', xmin(i),xmax(i)
  enddo
  xmin=xmin-(xmax-xmin)*0.01
  xmax=xmax+(xmax-xmin)*0.01
  call Moments_Reg(Moment,N_reg,xmin,xmax)
  write(*,*) 'Moments using regular integration:'
  write(*,*) Moment(1:5)
  write(*,*) 'Integral of P =', Integral_P
!==============================================================================!
  !                       Generate Initial Distribution
!any point in the domain where Potential < Ecut
!==============================================================================!
  n=1
  do while(n.le.Npoints)   
     call random_number(s)
     s(:)=xmin(:)+s(:)*(xmax(:)-xmin(:))
     if(V(s)<E_cut)then
        x(:,n)=s(:)
        n=n+1            
     endif
  enddo
  open(unit=16,file='coor_ini.dat')
  do i=1,Npoints
     write(16,*) x(:,i)
  enddo
  close(16)
  write(*,*) 'Test 1; Successfully Generated Initial GridPoints'
  call Moments(Moment,x)
  write(*,*) 'Moments from the initial distribution, Npoints=',Npoints
  write(*,*) Moment(1:5)
  !==============================================================================!
  !                           Compute U[x_ij] 
  !compute pairwise energies for all the initial GridPoints
  !==============================================================================!
  do i=2,Npoints
     do j=1,i-1
        U(i,j)=Pair_LJ_NRG(x(:,i),x(:,j))
!        U(i,j)=Pair_LJ_NRG(x(:,i),x(:,j))
        U(j,i)=U(i,j)
     enddo
  enddo
  !==============================================================================!
  !                       Begin MMC to Optimize GridPoints
  !==============================================================================!
  accept=0
  counter=0
  mv_cutoff=0.01
  deltae1=0
  plt_count=0
  open(unit=98,file='mv_cut.dat')
  open(unit=99,file='delE.dat')
  do n=1,N_MC
     !==============================================================================!
     !                       Randomly Select Atom to Move
     !==============================================================================!
     k=random_integer(1,Npoints)
     !==============================================================================!
     !                   Generate coordinates for Random move trial
     !random numbers generated (0,1), make it (-1,1) ==> s=2*s-1
     !==============================================================================!
     call random_number(s) 
     x0=x(:,k)+mv_cutoff*(2*s-1)
     !==============================================================================!
     !                   Only consider point if V(trial) < Ecut 
     !               Compute LJ Energy Change due to Trial Move
     !==============================================================================!
     if(V(x0).lt.E_cut) then
        counter=counter+1
        U_move(k)=P(x0)
        Delta_E=0d0
        do j=1,Npoints
           if(j.ne.k) then
              U_move(j)=Pair_LJ_NRG(x(:,j),x0)
!              U_move(j)=Pair_LJ_NRG(x(:,j),x0)
              Delta_E=Delta_E+U(j,k)-U_move(j)
           endif
        enddo
        !==============================================================================!
        !               Test to see if you should accept higher energy move
        !if delta e > 0 than always larger than 1, always accept
        !==============================================================================!
!        call random_number(t1) 
!        if(exp(Delta_E).ge.t1)then
        if(Delta_E>0d0)then
           U(:,k)=U_move(:)
           U(k,:)=U_move(:)
           accept=accept+1
           x(:,k)=x0(:)
           deltae1=deltae1+Delta_E
        endif
     endif
     !==============================================================================!
     !                           Update Cutoff Paramater
     !acceptance rate ~50%, adjust random movement displacement length accordingly
     !==============================================================================!
     if(mod(n,MMC_freq)==0)then
        write(*,*) 'MMC Iteration', n
        if(dble(accept)/counter<0.3)then 
           mv_cutoff=mv_cutoff*0.9
        else
           mv_cutoff=mv_cutoff*1.1
        endif
        accept=0
        counter=0
        call Moments(Moment,x)
        write(*,*) 'Moments:'
        write(*,*) Moment(1:5)
        write(*,*) 'mv cutoff', mv_cutoff
        write(*,*) 'Deltae1==>', Deltae1
        plt_count=plt_count+1
        write(98,*) plt_count, mv_cutoff
        write(99,*) plt_count, Deltae1
        deltae1=0
     endif
  enddo
  close(98)
  close(99)
  !==============================================================================!
  !                   Write Gridpoints Configuration to file 
  !==============================================================================!
  open(unit=17,file='grid.dat')
  do i=1,Npoints
     write(17,*) x(:,i)
  enddo
  close(17)
  write(*,*) 'Test 2; Successfully Generated Quasi-Regular Gridpoints'
  !==============================================================================!
  !                               output file                                    !
  !==============================================================================!
  call cpu_time(time2)
  open(90,file='simulation.dat')
  write(90,*) 'particle dimensionality ==> ', d
  write(90,*) 'Npoints ==> ', Npoints
  write(90,*) 'P Normalization Iterations (N_MC) ==> ', N_MC_moments
  write(90,*) 'P(x) Normalization ==> ', integral_P
  write(90,*) 'Number of MMC Iterations for Grid ==> ', N_MC
  write(90,*) 'c_LJ ==> ', c_LJ
  write(90,*) 'move cutoff==> ', mv_cutoff
  write(90,*) 'E_cut ==> ', E_cut
  write(90,*) 'N_MC_moments', N_MC_moments  
  write(90,*) '# gridpoints regular moments', N_reg     
  write(90,*) '# MC moves to distribute points', N_MC     
  write(90,*) 'MMC frequency', MMC_freq  
  do i=1,d
     write(90,*) i,' xmin xmax ==>', xmin(i),xmax(i)
  enddo
  write(90,*) 'Total Time ==> ', time2-time1
  close(90)
  write(*,*) 'Hello Universe!'
end program main
