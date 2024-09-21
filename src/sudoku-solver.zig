const std = @import("std");
const print = std.debug.print;
const Sudoku = @import("./Sudoku.zig");

const Errors = error{InputError};

pub fn main() !void {
    var sudoku = try Sudoku.init();
    defer sudoku.deinit();

    var stdin = std.io.bufferedReader(std.io.getStdIn().reader());
    var stdout = std.io.bufferedWriter(std.io.getStdOut().writer());
    const reader = stdin.reader();

    var buffer: [83]u8 = undefined; // 83 chars to leave room for crlf
    _ = try reader.readUntilDelimiterOrEof(buffer[0..], '\n');

    while (try reader.readUntilDelimiterOrEof(buffer[0..], '\n')) |line| {
        for (line[0..81], 0..) |c, i| {
            if (c != '0') sudoku.place(@truncate(i), c - '1');
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
            if (c != '0') sudoku.unplace(@truncate(i), c - '1');
        }
    }

    try stdout.flush();
}
