const std = @import("std");
const builtin = @import("builtin");
const File = std.fs.File;

// step 1: [x] read in a file from stdin and write out to stdout
// step 2: [ ] read in a named file in parameters and write out to stdout
// step 3: [ ] skip a number of lines
// step 4: [ ] skip a number of matching lines
// step 5: [ ] skip a number of tokens

pub fn main() anyerror!void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    try dumpInput(stdin, stdout);
}

fn dumpInput(in: File, out: File) !void {
    var buffer: [100]u8 = undefined;
    while (true) {
        const input = (try nextLine(in.reader(), &buffer));
        if (input) |line| {
            try out.writer().print("{s}\n", .{ line });
        } else {
            break;
        }
    }
}

fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    var line = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;
    // trim annoying windows-only carriage return character
    if (builtin.os.tag == .windows) {
        line = std.mem.trimRight(u8, line, "\r");
    }
    return line;
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
