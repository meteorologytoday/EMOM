# ProgramTunnel
This is a tool to let different programs send text or binary data to each other using named pipes (FIFOs). This project is developed along with SMARTSLAB to let fortran program (CESM) to communicate with ocean model written in Julia.


# Basic examples

The examples are contained in folder `example`.

## A: Matlab v.s. Matlab

### I. First create fifos
```
> cd example/matlab_matlab
> ./mkTunnels.sh
```

### II. Screen 1 (Matlab interactive mode)

```
> % In folder example/matlab_matlab
> proc1
```

### III. Screen 2 (Matlab interactive mode)

```
> % In folder example/matlab_matlab
> proc2
```

## B: Fortran v.s. Matlab

### I. First create fifos

```
> cd example/fortran_matlab
> ./mkTunnels.sh
```

### II. Screen 1 (Bash)

```
> # In folder example/fortran_matlab
> gfortran proc1.f90 -o proc1.out
> ./proc1.out
```

### III. Screen 2 (Matlab interactive mode)
```
> % In folder example/fortran_matlab
> proc2
```
