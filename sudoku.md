The dancing links algorithm solves the problem of taking a set S of sets
(options), and find a subset $S'$ of $S$ (set of options), such that $S'$ is a
partition of $option_1 \cup option_2 \cup option_3, \ldots$

A standard $9 \times 9$ Sudoku can be stated with a list of $9^3$ options
of the following form
$$
\{ p_{ij}, r_{ik}, c_{jk}, b_{zk} \}
$$


why is sudoku written with a capital S.

- The item $p_{ij}$ states that the position $(i, j)$ is filled
- The item $r_{ik}$ states that k is placed in row $i$
- The item $c_{jk}$ states that k is placed in column $j$
- The item $b_{zk}$ states that k is placed in box $x$


