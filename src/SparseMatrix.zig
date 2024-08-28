const std = @import("std");

const Node = struct {
    above: u16,
    below: u16,
    left: u16,
    right: u16,
};

allocator: std.mem.Allocator,
nodes: []Node,
rowlen: u16,
i: u16,

const SparseMatrix = @This();

pub fn init(al: std.mem.Allocator, rowlen: u16, capacity: u16) !SparseMatrix {
    const m = SparseMatrix{
        .allocator = al,
        .nodes = try al.alloc(Node, capacity + rowlen + 1),
        .rowlen = rowlen,
        .i = rowlen + 1,
    };
    @memset(m.nodes, std.mem.zeroes(Node));

    // Setup Header nodes
    const first = 1;
    const last = rowlen;

    var i: u16 = first + 1;
    while (i <= last) : (i += 1) {
        m.linkneighbors(i - 1, i);
        m.makeheader(i);
    }
    m.makeheader(first);
    m.linkneighbors(last, 0);
    m.linkneighbors(0, first);
    return m;
}

pub fn deinit(self: *SparseMatrix) void {
    self.allocator.free(self.nodes);
}

pub fn algorithmX(self: *SparseMatrix, path: []u16, depth: u8) void {
    if (self.nodes[0].right == 0) {
        std.debug.print("Found solution: {any}\n", .{path[0..depth]});
        return;
    }

    const col_header = self.nodes[0].right;
    var node = self.nodes[col_header].below;
    while (node != col_header) : (node = self.nodes[node].below) {
        self.chooserow(node);
        path[depth] = node;
        self.algorithmX(path, depth + 1);
        self.unchooserow(node);
    }
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

// Header
fn header(self: *SparseMatrix, col: u16) u16 {
    _ = self;
    return col + 1;
}

fn isheader(self: *SparseMatrix, node: u16) bool {
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

fn removerow(self: *SparseMatrix, i: u16) void {
    var j = self.nodes[i].right;
    while (j != i) : (j = self.nodes[j].right) {
        const node2 = self.nodes[j];
        self.nodes[node2.above].below = node2.below;
        self.nodes[node2.below].above = node2.above;
    }
}

fn reinsertrow(self: *SparseMatrix, i: u16) void {
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
fn removecol(self: *SparseMatrix, i: u16) void {
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

fn reinsertcol(self: *SparseMatrix, i: u16) void {
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

fn chooserow(self: *SparseMatrix, i: u16) void {
    var j = self.nodes[i].right;
    self.removecol(i);
    while (j != i) : (j = self.nodes[j].right) {
        self.removecol(j);
    }
}

fn unchooserow(self: *SparseMatrix, i: u16) void {
    self.reinsertcol(i);
    var j = self.nodes[i].right;
    while (j != i) : (j = self.nodes[j].right) {
        self.reinsertcol(j);
    }
}
