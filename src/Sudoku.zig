const std = @import("std");
const Sudoku = @This();
const SparseMatrix = @import("./SparseMatrix.zig");

dlx: SparseMatrix,
solution: [81]u8,

pub fn init(allocator: std.mem.Allocator) !Sudoku {
    var dlx = try SparseMatrix.init(allocator, 9 * 9 * 4, 4 * 9 * 9 * 9);
    for (0..9 * 9 * 9) |i| {
        const pos: u16 = @intCast(i / 9); // [0, 81⟩
        const value: u16 = @intCast(i % 9);
        const row = pos / 9; // [0, 9⟩
        const col = pos % 9; // [0, 9⟩
        const square = col / 3 + 3 * (row / 3);
        dlx.add(&.{
            0 * 81 + pos,
            1 * 81 + 9 * row + value,
            2 * 81 + 9 * col + value,
            3 * 81 + 9 * square + value,
        });
    }
    return Sudoku{ .dlx = dlx, .solution = std.mem.zeroes([81]u8) };
}

pub fn place81(self: *Sudoku, i: u16, n: u8) void {
    self.solution[i] = n;
    const j = 4 * 9 * i + 4 * n;
    self.dlx.chooserow(1 + 4 * 81 + j);
}

pub fn unplace81(self: *Sudoku, i: u16, n: u8) void {
    const j = 4 * 9 * i + 4 * n;
    self.dlx.unchooserow(1 + 4 * 81 + j);
}

pub fn place(self: *Sudoku, row: u16, col: u16, n: u8) void {
    const i = row * 9 + col;
    self.solution[i] = n;
    const j = 4 * 9 * i + 4 * n;
    self.dlx.chooserow(1 + 4 * 81 + j);
}

pub fn solve(self: *Sudoku) void {
    var solution = std.mem.zeroes([81]u16);
    if (self.dlx.algorithmX(&solution, 0)) |path| {
        for (path) |j| {
            const i = (j - 4 * 81 - 1) / 4;
            const pos = i / 9;
            const n = i % 9;
            self.solution[pos] = @intCast(n);
        }
    }
}

pub fn deinit(self: *const Sudoku, allocator: std.mem.Allocator) void {
    self.dlx.deinit(allocator);
}
