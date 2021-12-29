const std = @import("std");
const builtin = @import("builtin");
const os = builtin.os;
const mem = std.mem;
const testing = std.testing;
const io = std.io;
const fs = std.fs;
const File = fs.File;
const FileReader = File.Reader;

// step 1: [x] read in a file from stdin and write out to stdout
// step 2: [ ] read in a named file in parameters and write out to stdout
// step 3: [ ] skip a number of lines
// step 4: [ ] skip a number of matching lines
// step 5: [ ] skip a number of tokens

pub fn main() anyerror!void {
    const stdin = io.getStdIn();
    const stdout = io.getStdOut();
    try dumpInput(stdin, stdout);
}

const maxLineLength = 100;

fn dumpInput(in: File, out: File) !void {
    var buffer: [maxLineLength]u8 = undefined;
    const writer = out.writer();
    const reader = in.reader();
    while (true) {
        const input = try nextLine(reader, &buffer);
        if (input) |line| {
            try writer.print("{s}\n", .{ line });
        } else {
            break;
        }
    }
}

fn nextLine(reader: FileReader, buffer: []u8) !?[]const u8 {
    var line = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;
    return windowsSafe(line);
}

// trim annoying windows-only carriage return character
fn windowsSafe(line: []u8) []u8 {
    if (os.tag == .windows) {
        return mem.trimRight(u8, line, "\r");
    }
    return line;
}

test "windowsSage strips carriage return on windows" {
    if (os.tag == .windows) {
        try testing.expectEqualSlices(u8, "line\n\r", "line\n");
    } else {
        try testing.expectEqualSlices(u8, "line\n\r", "line\n\r");
    }
}
