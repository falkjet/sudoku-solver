const std = @import("std");
const Sudoku = @This();

const column_count = 9 * 9 * 4;
const normal_node_count = 4 * 9 * 9 * 9;
const total_node_count = normal_node_count + column_count + 1;

nodes: [total_node_count]Node,
solution: [81]u8,

pub fn init() !Sudoku {
    var self = Sudoku{ .nodes = std.mem.zeroes([total_node_count]Node), .solution = std.mem.zeroes([81]u8) };

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
    var smallest = self.right_of(0);
    var height = self.column_height(smallest);

    var col = self.right_of(smallest);
    while (col != 0) : (col = self.right_of(col)) {
        const h = self.column_height(col);
        if (h < height) {
            height = h;
            smallest = col;
        }
    }

    return smallest;
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
    var j = self.right_of(i);
    self.removecol(i);
    while (j != i) : (j = self.right_of(j)) {
        self.removecol(j);
    }
}

fn unchooserow(self: *Sudoku, i: u16) void {
    self.reinsertcol(i);
    var j = self.right_of(i);
    while (j != i) : (j = self.right_of(j)) {
        self.reinsertcol(j);
    }
}

// Takes node as argument and uninserts the header and removes all
// rows where the column has a node except the row of the input node
fn removecol(self: *Sudoku, i: u16) void {
    var j = self.nodes[i].below;
    while (j != i) : (j = self.nodes[j].below) {
        if (self.isheader(j)) {
            const node = self.nodes[j];
            const left = node.left;
            const right = node.right;
            self.nodes[left].right = right;
            self.nodes[right].left = left;
            continue;
        }
        self.removerow(j);
    }
}

fn reinsertcol(self: *Sudoku, i: u16) void {
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
    while (j != i) : (j = self.right_of(j)) {
        const node2 = self.nodes[j];
        self.nodes[node2.above].below = node2.below;
        self.nodes[node2.below].above = node2.above;
    }
}

fn reinsertrow(self: *Sudoku, i: u16) void {
    const node = self.nodes[i];
    self.nodes[node.above].below = i;
    self.nodes[node.below].above = i;

    var j = node.right;
    while (j != i) : (j = self.right_of(j)) {
        const node2 = self.nodes[j];
        self.nodes[node2.above].below = j;
        self.nodes[node2.below].above = j;
    }
}

/// connect a left and right node with each other
fn linkneighbors(self: *Sudoku, left: u16, right: u16) void {
    self.nodes[left].right = right;
    self.nodes[right].left = left;
}

fn vertical_reinsert(self: *Sudoku, i: u16) void {
    self.nodes[self.nodes[i].above].below = i;
    self.nodes[self.nodes[i].below].above = i;
}

fn vertical_insert_above(self: *Sudoku, new: u16, node: u16) void {
    self.nodes[new].below = node;
    self.nodes[new].above = self.nodes[node].above;
    self.vertical_reinsert(new);
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
