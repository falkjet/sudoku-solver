const std = @import("std");
const Sudoku = @This();

const column_count = 9 * 9 * 4;
const normal_node_count = 4 * 9 * 9 * 9;
const total_node_count = normal_node_count + column_count + 1;

col_pqueue: [column_count + 10]struct { left: u16, right: u16 },
col_sizes: [column_count]u8,
nodes: [total_node_count]Node,
solution: [81]u8,

pub fn init() !Sudoku {
    var self = Sudoku{
        .col_pqueue = undefined,
        .col_sizes = undefined,
        .nodes = std.mem.zeroes([total_node_count]Node),
        .solution = std.mem.zeroes([81]u8),
    };

    @memset(self.col_sizes[0..], 9);

    // Setup priority queue
    for (0..column_count - 1) |i_| {
        const i: u16 = @intCast(i_);
        self.col_pqueue[i].right = i + 1;
        self.col_pqueue[i + 1].left = i;
    }
    for (column_count..column_count + 9) |i_| {
        const i: u16 = @intCast(i_);
        self.col_pqueue[i].right = i;
        self.col_pqueue[i].left = i;
    }
    self.col_pqueue[0].left = column_count + 9;
    self.col_pqueue[column_count + 9].right = 0;
    self.col_pqueue[column_count + 9].left = column_count - 1;
    self.col_pqueue[column_count - 1].right = column_count + 9;

    // Setup header row
    for (0..column_count + 1) |i| {
        const j: u16 = @intCast(i);
        self.nodes[i].above = @intCast(i);
        self.nodes[i].below = @intCast(i);
        self.linkneighbors(j, (j + 1) % (column_count + 1));
    }

    // Setup row representing constaints
    for (0..9 * 9 * 9) |i| {
        const pos: u16 = @intCast(i / 9); // [0, 81⟩
        const value: u16 = @intCast(i % 9);
        const row = pos / 9; // [0, 9⟩
        const col = pos % 9; // [0, 9⟩
        const square = col / 3 + 3 * (row / 3);

        const a = 0 * 81 + pos;
        const b = 1 * 81 + 9 * row + value;
        const c = 2 * 81 + 9 * col + value;
        const d = 3 * 81 + 9 * square + value;

        const offset = column_count + 1 + 4 * @as(u16, @intCast(i));
        self.vertical_insert_above(offset + 0, self.header(a));
        self.vertical_insert_above(offset + 1, self.header(b));
        self.vertical_insert_above(offset + 2, self.header(c));
        self.vertical_insert_above(offset + 3, self.header(d));
        self.linkneighbors(offset + 0, offset + 1);
        self.linkneighbors(offset + 1, offset + 2);
        self.linkneighbors(offset + 2, offset + 3);
        self.linkneighbors(offset + 3, offset + 0);
    }
    return self;
}

pub fn deinit(self: *Sudoku) void {
    _ = self;
}

// Sudoku interface

pub fn place81(self: *Sudoku, i: u16, n: u8) void {
    self.solution[i] = n;
    const j = 4 * 9 * i + 4 * n;
    self.dlx.chooserow(1 + 4 * 81 + j);
}

pub fn unplace81(self: *Sudoku, i: u16, n: u8) void {
    const j = 4 * 9 * i + 4 * n;
    self.unchooserow(1 + 4 * 81 + j);
}

pub fn place(self: *Sudoku, row: u16, col: u16, n: u8) void {
    const i = row * 9 + col;
    self.solution[i] = n;
    const j = 4 * 9 * i + 4 * n;
    self.chooserow(1 + 4 * 81 + j);
}

pub fn solve(self: *Sudoku) void {
    var solution = std.mem.zeroes([81]u16);
    if (self.algorithmX(&solution, 0)) |path| {
        for (path) |j| {
            const i = (j - 4 * 81 - 1) / 4;
            const pos = i / 9;
            const n = i % 9;
            self.solution[pos] = @intCast(n);
        }
    }
}

// Dancing links stuff
fn algorithmX(self: *Sudoku, path: []u16, depth: u8) ?[]u16 {
    if (self.right_of(0) == 0) {
        return path[0..depth];
    }

    const col_header = self.shortest_column();
    var node = self.nodes[col_header].below;
    while (node != col_header) : (node = self.nodes[node].below) {
        self.chooserow(node);
        defer self.unchooserow(node);

        path[depth] = node;
        if (self.algorithmX(path, depth + 1)) |r| return r;
    }

    return null;
}

fn shortest_column(self: *Sudoku) u16 {
    for (column_count..column_count + 10) |i| {
        if (self.col_pqueue[i].right != i) {
            return self.header(self.col_pqueue[i].right);
        }
    }
    @panic("Unreachable");
}

fn column_height(self: *const Sudoku, col: u16) u8 {
    var i: u8 = 0;
    var node = self.nodes[col].below;

    while (node != col) : (node = self.nodes[node].below) {
        i += 1;
    }
    return i;
}

fn chooserow(self: *Sudoku, i: u16) void {
    self.removecol(i);

    var j = self.right_of(i);
    while (j != i) : (j = self.right_of(j)) {
        self.removecol(j);
    }
}

fn unchooserow(self: *Sudoku, i: u16) void {
    var j = self.left_of(i);
    while (j != i) : (j = self.left_of(j)) {
        self.reinsertcol(j);
    }

    self.reinsertcol(i);
}

// Takes node as argument and uninserts the header and removes all
// rows where the column has a node except the row of the input node
fn removecol(self: *Sudoku, i: u16) void {
    var j = self.nodes[i].below;
    while (j != i) : (j = self.nodes[j].below) {
        if (self.isheader(j)) {
            const node = self.nodes[j];
            self.nodes[node.left].right = node.right;
            self.nodes[node.right].left = node.left;
            continue;
        }
        self.removerow(j);
    }

    const col = colof(i);
    self.remove_col_from_pqueue(col);
}

fn reinsertcol(self: *Sudoku, i: u16) void {
    const col = colof(i);
    self.insert_col_into_pqueue(col);

    var j = self.nodes[i].below;
    while (j != i) : (j = self.nodes[j].below) {
        if (self.isheader(j)) {
            const node = self.nodes[j];
            self.nodes[node.left].right = j;
            self.nodes[node.right].left = j;
            continue;
        }
        self.reinsertrow(j);
    }
}

fn removerow(self: *Sudoku, i: u16) void {
    var j = self.right_of(i);
    while (j != i) : (j = self.right_of(j)) self.vertical_uninsert_node(j);
}

fn reinsertrow(self: *Sudoku, i: u16) void {
    var j = self.left_of(i);
    while (j != i) : (j = self.left_of(j)) self.vertical_reinsert_node(j);
}

fn vertical_uninsert_node(self: *Sudoku, j: u16) void {
    const col = colof(j);
    self.col_sizes[col] -= 1;
    self.update_col_priority(col);

    const node = self.nodes[j];
    self.nodes[node.above].below = node.below;
    self.nodes[node.below].above = node.above;
}

fn vertical_reinsert_node(self: *Sudoku, j: u16) void {
    const col = colof(j);
    self.col_sizes[col] += 1;
    self.update_col_priority(col);

    const node = self.nodes[j];
    self.nodes[node.above].below = j;
    self.nodes[node.below].above = j;
}

fn update_col_priority(self: *Sudoku, col: u16) void {
    self.remove_col_from_pqueue(col);
    self.insert_col_into_pqueue(col);
}

fn remove_col_from_pqueue(self: *Sudoku, col: u16) void {
    const node = self.col_pqueue[col];

    self.pqueue_link(node.left, node.right);
    self.pqueue_link(col, col);
}

fn pqueue_link(self: *Sudoku, left: u16, right: u16) void {
    self.col_pqueue[left].right = right;
    self.col_pqueue[right].left = left;
}

fn insert_col_into_pqueue(self: *Sudoku, col: u16) void {
    const priority = self.col_sizes[col];

    const head = column_count + @as(u16, priority);
    const right_of_header = self.col_pqueue[head].right;

    self.pqueue_link(head, col);
    self.pqueue_link(col, right_of_header);
}

pub fn colof(node: u16) u16 {
    const n = node - (column_count + 1);
    const i = n / 4;
    const pos: u16 = i / 9; // [0, 81⟩
    const value: u16 = i % 9;
    const row = pos / 9; // [0, 9⟩
    const col = pos % 9; // [0, 9⟩
    const square = col / 3 + 3 * (row / 3);

    const a = 0 * 81 + pos;
    const b = 1 * 81 + 9 * row + value;
    const c = 2 * 81 + 9 * col + value;
    const d = 3 * 81 + 9 * square + value;

    return switch (n % @as(u16, 4)) {
        0 => a,
        1 => b,
        2 => c,
        3 => d,
        else => @panic("Impossible"),
    };
}

/// connect a left and right node with each other
fn linkneighbors(self: *Sudoku, left: u16, right: u16) void {
    self.nodes[left].right = right;
    self.nodes[right].left = left;
}

fn vertical_insert_above(self: *Sudoku, new: u16, node: u16) void {
    self.nodes[new].below = node;
    self.nodes[new].above = self.nodes[node].above;
    self.nodes[self.nodes[new].above].below = new;
    self.nodes[self.nodes[new].below].above = new;
}

// Utils to read data structure
fn header(self: *Sudoku, col: u16) u16 {
    _ = self;
    return col + 1;
}

fn isheader(_: *const Sudoku, node: u16) bool {
    return node <= column_count;
}

fn right_of(self: *const Sudoku, i: u16) u16 {
    return self.nodes[i].right;
}

fn left_of(self: *const Sudoku, i: u16) u16 {
    return self.nodes[i].left;
}

const Node = struct {
    above: u16,
    below: u16,
    left: u16,
    right: u16,
};
