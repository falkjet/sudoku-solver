Sudoku Solver

A Program to solve lots of sudokus efficiently.


Building
--------

The program can be build using using the command
```sh
zig build --release=fast
```
or using nix with the command
```sh
nix build .
```

Running
-------

When build by calling `zig build` the program will be located in
`./zig-out/bin`, and it will expect sudokus getting written to its standard
input.

The following command will run the program on all 17 clue non-equivalent sudokus
```sh
./zig-out/bin/sudoku-solver < 17puz49158.txt
```

