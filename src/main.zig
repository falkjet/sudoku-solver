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
    defer m.deinit(allocator);

    m.add(&([_]u16{ 2, 4 }));
    m.add(&([_]u16{ 0, 3, 6 }));
    m.add(&([_]u16{ 1, 2, 5 }));
    m.add(&([_]u16{ 0, 3, 5 }));
    m.add(&([_]u16{ 1, 6 }));
    m.add(&([_]u16{ 3, 4, 6 }));

    var path = std.mem.zeroes([8]u16);

    m.algorithmX(path[0..], 0);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
