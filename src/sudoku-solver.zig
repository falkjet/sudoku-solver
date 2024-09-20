const std = @import("std");
const print = std.debug.print;
const DancingLinks = @import("./DancingLinks.zig");
const Sudoku = @import("./Sudoku.zig");

const Errors = error{InputError};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var sudoku = try Sudoku.init(allocator);
    defer sudoku.deinit(allocator);

    var reader = std.io.bufferedReader(std.io.getStdIn().reader());
    const stdout = std.io.getStdOut();

    while (true) {
        var buffer: [83]u8 = undefined; // 83 chars to leave room for crlf
        const line = try reader.reader().readUntilDelimiterOrEof(buffer[0..], '\n') orelse {
            std.process.exit(0);
        };

        for (line[0..81], 0..) |c, i| {
            if (c != '.') {
                const j: u16 = @truncate(i);
                sudoku.place(j / 9, j % 9, c - '1');
            }
        }

        sudoku.solve();
        for (sudoku.solution[0..]) |*c| {
            c.* += '1';
        }
        _ = try stdout.write(sudoku.solution[0..]);
        _ = try stdout.write(&.{'\n'});

        var i: u16 = 81;
        while (i > 0) {
            i -= 1;
            const c = buffer[i];
            if (c != '.') {
                sudoku.unplace81(@truncate(i), c - '1');
            }
        }
    }
}
