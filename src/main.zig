const std = @import("std");
const print = std.debug.print;
const SparseMatrix = @import("./SparseMatrix.zig");
const Sudoku = @import("./Sudoku.zig");

const Errors = error{InputError};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var sudoku = try Sudoku.init(allocator);
    defer sudoku.deinit(allocator);

    while (true) {
        const stdin = std.io.getStdIn();
        var buffer: [83]u8 = undefined;
        const n = try stdin.read(&buffer);
        if (n == 0) std.process.exit(0);
        if (n != 83) return Errors.InputError;

        for (buffer[0..75], 0..) |c, i| {
            if (c != '.') {
                const j: u16 = @truncate(i);
                print("PLACE: {} {} {}\n", .{ j % 9, j / 9, c - '1' });
                sudoku.place(j % 9, j / 9, c - '1');
            }
        }

        std.debug.print("Solving...\n", .{});
        sudoku.solve();
        std.debug.print("Solved\n", .{});

        print("Resetting\n", .{});
        var i: u16 = 81;
        while (true) {
            if (i == 0) break;
            i -= 1;
            const c = buffer[i];
            if (c != '.') {
                sudoku.unplace81(@truncate(i), c - '1');
            }
        }
        print("Done resetting", .{});
        break;
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
