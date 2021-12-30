const std = @import("std");
const builtin = @import("builtin");
const os = builtin.os;
const mem = std.mem;
const testing = std.testing;
const io = std.io;
const heap = std.heap;
const fs = std.fs;

// step 1: [x] read in a file from stdin and write out to stdout
// step 2: [ ] read in a named file in parameters and write out to stdout
// step 3: [ ] skip a number of lines
// step 4: [ ] skip a number of matching lines
// step 5: [ ] skip a number of tokens

pub fn main() anyerror!void {
    const stdin = io.getStdIn();
    const stdout = io.getStdOut();
    var buffer: [4096]u8 = undefined;
    var fba = heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    try dumpInput(stdin, stdout, allocator);
}

const maxLineLength = 4096;

fn dumpInput(in: fs.File, out: fs.File, allocator: mem.Allocator) !void {
    const writer = out.writer();
    const reader = in.reader();
    var it = lineIterator(reader, allocator);
    while (it.next()) |line| {
        defer allocator.free(line);
        
        try writer.print("{s}\n", .{ windowsSafe(line) });
    }
}

fn lineIterator(reader: fs.File.Reader, allocator: mem.Allocator) LineIterator {
    return LineIterator {
        .reader = io.bufferedReader(reader),
        .delimiter = '\n',
        .allocator = allocator
    };
}

test "lineIterator returns lines in buffer" {
    const file = try fs.cwd().openFile("src/test/two-lines.txt", .{ .read = true, .write = false });
    defer file.close();

    var reader = file.reader();
    var it = lineIterator(reader, testing.allocator);

    const line1 = it.next().?;
    defer testing.allocator.free(line1);
    try testing.expectEqualStrings("line 1", line1);

    const line2 = it.next().?;
    defer testing.allocator.free(line2);
    try testing.expectEqualStrings("line 2", line2);
    const eof = it.next();

    try testing.expect(eof == null);
}

const LineIterator = struct {
    reader: io.BufferedReader(4096, fs.File.Reader),
    delimiter: u8,
    allocator: mem.Allocator,

    const Self = @This();

    /// Caller owns returned memory
    pub fn next(self: *Self) ?[]u8 {
        return self.reader.reader().readUntilDelimiterOrEofAlloc(self.allocator, self.delimiter, 4096) catch null;
    }
};

// trim annoying windows-only carriage return character
fn windowsSafe(line: []const u8) []const u8 {
    if (os.tag == .windows) {
        return mem.trimRight(u8, line, "\r");
    }
    return line;
}

test "windowsSafe strips carriage return on windows" {
    const input = "line\n\r";
    const result = windowsSafe(input);
    if (os.tag == .windows) {
        // strips the carriage return if windows
        try testing.expectEqualSlices(u8, "line\n", result);
    } else {
        // doesn't change the line if not windows
        try testing.expectEqualSlices(u8, input, result);
    }
}
