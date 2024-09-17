//! A Sparse matrix is a grid where all cells are either empty, or contain a
//! node. Each node is connected to a node to the node above, below and each
//! side. this means that each row, and column is a circular doubly linked list
//! of nodes. Each column contain a header node node, that is there, so we
//! always hava a reference to each column. The row of header nodes also
//! contain an extra node on the start, with index 0. This means that if we
//! iterate to the right node 0, we find the control nodes for each column, and
//! from those we can iterate over all the nodes in the column.
//!
//! One of the most powerful features of a sparse matrix is that we can remove
//! (uninsert) node, from the matrix, and the reinsert it afterwards.
//! if we use a spare matrix to represent a state space we can do a recursive
//! search with really efficient backtracking. This can be used to solve the
//! exact cover problem in a really efficient way
const std = @import("std");

const Node = struct {
    above: u16,
    below: u16,
    left: u16,
    right: u16,
};

nodes: []Node,
rowlen: u16,
i: u16,

const SparseMatrix = @This();

pub fn init(allocator: std.mem.Allocator, rowlen: u16, capacity: u16) !SparseMatrix {
    const m = SparseMatrix{
        .nodes = try allocator.alloc(Node, capacity + rowlen + 1),
        .rowlen = rowlen,
        .i = rowlen + 1,
    };
    @memset(m.nodes, std.mem.zeroes(Node));

    // Setup Header nodes
    const first = 1;
    const last = rowlen;

    var i: u16 = 1;
    while (i <= last) : (i += 1) {
        m.linkneighbors(i - 1, i);
        m.makeheader(i);
    }
    m.makeheader(first);
    m.linkneighbors(last, 0);
    return m;
}

pub fn deinit(self: *const SparseMatrix, allocator: std.mem.Allocator) void {
    allocator.free(self.nodes);
}

pub fn algorithmX(self: *const SparseMatrix, path: []u16, depth: u8) ?[]u16 {
    if (self.nodes[0].right == 0) {
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

pub fn shortest_column(self: *const SparseMatrix) u16 {
    var smallest = self.nodes[0].right;
    var height = self.column_height(smallest);

    var col = self.nodes[smallest].right;
    while (col != 0) : (col = self.nodes[col].right) {
        const h = self.column_height(col);
        if (h < height) {
            height = h;
            smallest = col;
        }
    }

    return smallest;
}

pub fn column_height(self: *const SparseMatrix, col: u16) u8 {
    var i: u8 = 0;
    var node = self.nodes[col].below;

    while (node != col) : (node = self.nodes[node].below) {
        i += 1;
    }
    return i;
}

pub fn add(self: *SparseMatrix, cols: []const u16) void {
    var i: u16 = 1; // index into nodes
    while (i < cols.len) : (i += 1) {
        const col = cols[i];
        const node = self.i + i;
        self.vertical_insert_above(node, self.header(col));
        self.linkneighbors(node - 1, node);
    }
    self.linkneighbors(self.i + i - 1, self.i);
    self.vertical_insert_above(self.i, self.header(cols[0]));
    self.i += i;
}

pub fn colof(self: *SparseMatrix, i: u16) u16 {
    var j = i;
    while (!self.isheader(j)) {
        j = self.nodes[j].above;
    }
    return j - 1;
}

pub fn chooserow(self: *const SparseMatrix, i: u16) void {
    var j = self.nodes[i].right;
    self.removecol(i);
    while (j != i) : (j = self.nodes[j].right) {
        self.removecol(j);
    }
}

pub fn unchooserow(self: *const SparseMatrix, i: u16) void {
    self.reinsertcol(i);
    var j = self.nodes[i].right;
    while (j != i) : (j = self.nodes[j].right) {
        self.reinsertcol(j);
    }
}

// Header
fn header(self: *SparseMatrix, col: u16) u16 {
    _ = self;
    return col + 1;
}

fn isheader(self: *const SparseMatrix, node: u16) bool {
    return node <= self.rowlen;
}

/// Set the up and down pointer of i to point to i
fn makeheader(self: *const SparseMatrix, i: u16) void {
    self.nodes[i].above = i;
    self.nodes[i].below = i;
}

/// connect a left and right node with each other
fn linkneighbors(self: *const SparseMatrix, left: u16, right: u16) void {
    self.nodes[left].right = right;
    self.nodes[right].left = left;
}

fn vertical_reinsert(self: *const SparseMatrix, i: u16) void {
    self.nodes[self.nodes[i].above].below = i;
    self.nodes[self.nodes[i].below].above = i;
}

fn vertical_insert_above(self: *const SparseMatrix, new: u16, node: u16) void {
    self.nodes[new].below = node;
    self.nodes[new].above = self.nodes[node].above;
    self.vertical_reinsert(new);
}

fn removerow(self: *const SparseMatrix, i: u16) void {
    var j = self.nodes[i].right;
    while (j != i) : (j = self.nodes[j].right) {
        const node2 = self.nodes[j];
        self.nodes[node2.above].below = node2.below;
        self.nodes[node2.below].above = node2.above;
    }
}

fn reinsertrow(self: *const SparseMatrix, i: u16) void {
    const node = self.nodes[i];
    self.nodes[node.above].below = i;
    self.nodes[node.below].above = i;

    var j = node.right;
    while (j != i) : (j = self.nodes[j].right) {
        const node2 = self.nodes[j];
        self.nodes[node2.above].below = j;
        self.nodes[node2.below].above = j;
    }
}

// Takes node as argument and uninserts the header and removes all
// rows where the column has a node except the row of the input node
fn removecol(self: *const SparseMatrix, i: u16) void {
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

fn reinsertcol(self: *const SparseMatrix, i: u16) void {
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
