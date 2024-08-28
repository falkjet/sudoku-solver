const std = @import("std");
const print = std.debug.print;
const SparseMatrix = @import("./SparseMatrix.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //   1 1 2 3 4 5 6
    //       1   1
    //   1     1     1
    //     1 1     1
    //   1     1   1
    //     1         1
    //         1 1   1
    var m = try SparseMatrix.init(allocator, 7, 16);
    defer m.deinit();
    m.add(&([_]u16{ 2, 4 }));
    m.add(&([_]u16{ 0, 3, 6 }));
    m.add(&([_]u16{ 1, 2, 5 }));
    m.add(&([_]u16{ 0, 3, 5 }));
    m.add(&([_]u16{ 1, 6 }));
    m.add(&([_]u16{ 3, 4, 6 }));

    var path = std.mem.zeroes([8]u16);
    debug_matrix_overview(&m);

    m.algorithmX(path[0..], 0);
}

fn debug_matrix_overview(m: *SparseMatrix) void {
    for (1..m.rowlen + 1) |i| {
        print(" {:2} ", .{i});
    }
    print("\n", .{});

    var i = m.rowlen + 1;
    var c: u16 = 0; // Track which column we are writing to
    while (i < m.nodes.len) : (i += 1) {
        const col = m.colof(i);
        if (c > col) {
            while (c < m.rowlen) : (c += 1) {
                print(" \x1b[38;5;236m--\x1b[0m ", .{});
            }
            c = 0;
            print("\n", .{});
        }
        while (c < col) : (c += 1) {
            print(" \x1b[38;5;236m--\x1b[0m ", .{});
        }
        print(" {:2} ", .{i});
        c += 1;
    }
    while (c < m.rowlen) : (c += 1) {
        print(" \x1b[38;5;236m--\x1b[0m ", .{});
    }
    print("\n\n", .{});
}

fn debug_node(node: SparseMatrix.Node, active: bool) void {
    if (active) {
        print("  \x1b[35m{:2}_{:2}_{:2}_{:2}\x1b[0m  ", .{ node.left, node.below, node.above, node.right });
    } else {
        print("  {:2}_{:2}_{:2}_{:2}  ", .{ node.left, node.below, node.above, node.right });
    }
}

fn debug_node_placeholder() void {
    print("  \x1b[38;5;236m-----------\x1b[0m  ", .{});
}

fn dfs_nodes(m: *SparseMatrix, visited: []bool, node: u16) void {
    if (visited[node]) {
        return;
    }
    visited[node] = true;
    dfs_nodes(m, visited, m.nodes[node].right);
    dfs_nodes(m, visited, m.nodes[node].left);
    dfs_nodes(m, visited, m.nodes[node].above);
    dfs_nodes(m, visited, m.nodes[node].below);
}

fn debug_matrix(m: *SparseMatrix, allocator: std.mem.Allocator) !void {

    // TODO: find reachable nodes from node-0
    const visited = try allocator.alloc(bool, m.nodes.len);
    defer allocator.free(visited);
    dfs_nodes(m, visited, 0);

    for (1..m.rowlen + 1) |i| {
        debug_node(m.nodes[i], visited[i]);
    }
    print("\n\n", .{});

    var i = m.rowlen + 1;
    var c: u16 = 0;
    while (i < m.nodes.len) : (i += 1) {
        const col = m.colof(i);
        if (c > col) {
            while (c < m.rowlen) : (c += 1) {
                debug_node_placeholder();
            }
            c = 0;
            print("\n\n", .{});
        }
        while (c < col) : (c += 1) {
            debug_node_placeholder();
        }
        debug_node(m.nodes[i], visited[i]);
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
