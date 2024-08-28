const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const al = gpa.allocator();

    // var m = try SparseMatrix.init(al, 9, 18);
    // defer m.deinit();
    //
    // // Example input
    // //   0 1 2 3 4 5 6 7 8
    // // A 1 1         1
    // // B     1 1   1
    // // C 1     1 1       1
    // // D 1   1 1   1   1 1
    // // E   1         1
    // m.add(&([_]u16{ 0, 1, 6 }));
    // m.add(&([_]u16{ 2, 3, 5 }));
    // m.add(&([_]u16{ 0, 3, 4, 8 }));
    // m.add(&([_]u16{ 0, 2, 3, 5, 7, 8 }));
    // m.add(&([_]u16{ 1, 6 }));

    var m = try SparseMatrix.init(al, 7, 16);
    defer m.deinit();
    m.add(&([_]u16{ 2, 4 }));
    m.add(&([_]u16{ 0, 3, 6 }));
    m.add(&([_]u16{ 1, 2, 5 }));
    m.add(&([_]u16{ 0, 3, 5 }));
    m.add(&([_]u16{ 1, 6 }));
    m.add(&([_]u16{ 3, 4, 6 }));

    debug_matrix_overview(&m);
    debug_matrix(&m);
    print("------------------------------------\n", .{});

    // m.chooserow(26);
    // m.unchooserow(26);
    //m.reinsertcol(9);
    m.chooserow(7);
    m.chooserow(15);
    debug_matrix(&m);
}

const Node = struct {
    above: u16,
    below: u16,
    left: u16,
    right: u16,
};

const SparseMatrix = struct {
    al: Allocator,
    nodes: []Node,
    rowlen: u16,
    i: u16,

    fn init(al: Allocator, rowlen: u16, capacity: u16) !SparseMatrix {
        const m = SparseMatrix{
            .al = al,
            .nodes = try al.alloc(Node, capacity + rowlen),
            .rowlen = rowlen,
            .i = rowlen,
        };

        // Setup Header nodes
        const first = 0;
        const last = rowlen - 1;

        var i: u16 = first + 1;
        while (i <= last) : (i += 1) {
            m.linkneighbors(i - 1, i);
            m.makeheader(i);
        }
        m.makeheader(0);
        m.linkneighbors(last, 0);
        return m;
    }

    fn deinit(self: *SparseMatrix) void {
        self.al.free(self.nodes);
    }

    // Header
    fn header(self: *SparseMatrix, col: u16) u16 {
        _ = self;
        return col;
    }

    fn isheader(self: *SparseMatrix, node: u16) bool {
        return node < self.rowlen;
    }

    fn makeheader(self: *const SparseMatrix, i: u16) void {
        self.nodes[i].above = i;
        self.nodes[i].below = i;
    }

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

    fn add(self: *SparseMatrix, cols: []const u16) void {
        var i: u16 = 1;
        while (i < cols.len) : (i += 1) {
            const col = cols[i];
            const node = self.i + i;
            self.vertical_insert_above(node, col);
            self.linkneighbors(node - 1, node);
        }
        self.linkneighbors(self.i + i - 1, self.i);
        self.vertical_insert_above(self.i, cols[0]);
        self.i += i;
    }

    fn colof(self: *SparseMatrix, i: u16) u16 {
        var j = i;
        while (!self.isheader(j)) {
            j = self.nodes[j].above;
        }
        return j;
    }

    fn removerow(self: *SparseMatrix, i: u16) void {
        print("Removing row of {}\n", .{i});
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
        print("removing col of {}\n", .{i});
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
};

fn debug_matrix_overview(m: *SparseMatrix) void {
    for (0..m.rowlen) |i| {
        print("  {:2}  ", .{i});
    }
    print("\n", .{});

    var i = m.rowlen;
    var c: u16 = 0;
    while (i < m.nodes.len) : (i += 1) {
        const col = m.colof(i);
        if (c > col) {
            while (c < m.rowlen) : (c += 1) {
                print("  \x1b[38;5;236m--\x1b[0m  ", .{});
            }
            c = 0;
            print("\n", .{});
        }
        while (c < col) : (c += 1) {
            print("  \x1b[38;5;236m--\x1b[0m  ", .{});
        }
        print("  {:2}  ", .{i});
        c += 1;
    }
    while (c < m.rowlen) : (c += 1) {
        print("  \x1b[38;5;236m--\x1b[0m  ", .{});
    }
    print("\n\n", .{});
}

fn debug_matrix(m: *SparseMatrix) void {
    for (0..m.rowlen) |i| {
        const node = m.nodes[i];
        print("  {:2}_{:2}_{:2}_{:2}  ", .{ node.left, node.below, node.above, node.right });
    }
    print("\n", .{});

    var i = m.rowlen;
    var c: u16 = 0;
    while (i < m.nodes.len) : (i += 1) {
        const col = m.colof(i);
        if (c > col) {
            while (c < m.rowlen) : (c += 1) {
                print("  \x1b[38;5;236m-----------\x1b[0m  ", .{});
            }
            c = 0;
            print("\n", .{});
        }
        while (c < col) : (c += 1) {
            print("  \x1b[38;5;236m-----------\x1b[0m  ", .{});
        }
        const node = m.nodes[i];
        print("  {:2}_{:2}_{:2}_{:2}  ", .{ node.left, node.below, node.above, node.right });
        c += 1;
    }
    while (c < m.rowlen) : (c += 1) {
        print("  \x1b[38;5;236m-----------\x1b[0m  ", .{});
    }
    print("\n", .{});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
