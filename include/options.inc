OPT =  -O3 -qarch=qp -qtune=qp
STD =  -O2
DEB =  -O0 -C
FFLAG += $(STD)
DFLAG += $(DEB)
MOPT =-qmoddir=

ifeq ($(FC),ifort)
OPT =  -O3 -ftz -assume nobuffered_io -openmp 
STD =  -O2 -assume nobuffered_io
DEB =  -p -O0 -g -debug -fpe0 -traceback -check all,noarg_temp_created
FFLAG += $(STD) -static-intel
DFLAG += $(DEB) -static-intel
MOPT=-module #leave a space here!
endif

ifeq ($(FC),gfortran)
OPT=-O3 -funroll-all-loops -fno-f2c
STD=-O2
DEB=-O0 -p -g -Wall
FFLAG += $(STD) -static
DFLAG += $(DEB) -static
MOPT=-J
endif

