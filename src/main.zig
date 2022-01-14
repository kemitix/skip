const std = @import("std");
const builtin = @import("builtin");
const os = builtin.os;
const fmt = std.fmt;
const mem = std.mem;
const testing = std.testing;
const io = std.io;
const heap = std.heap;
const fs = std.fs;
const clap = @import("clap");

const version = "0.1.0";

const maxLineLength = 4096;

pub fn main() anyerror!void {
    var buffer: [maxLineLength]u8 = undefined;
    var fba = heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const config: Config = parseArgs(allocator) catch |err| switch (err) {
        error.EarlyExit => return,
        error.FileNotFound => return,
        error.BadArgs => return,
        else => @panic("Unknown error"),
    };
    defer config.deinit();

    const stdout = io.getStdOut();
    if (config.file) |file| {
        try dumpInput(config, file, stdout, allocator);
    } else {
        const stdin = io.getStdIn();
        try dumpInput(config, stdin, stdout, allocator);
    }
}

const errors = error {
    EarlyExit,
    FileNotFound,
    BadArgs,
};

const Config = struct {
    lines: u32,
    file: ?fs.File,
    line: ?[]const u8 = null,
    token: ?[]const u8 = null,
    ignoreExtras: bool,

    pub fn deinit(self: @This()) void {
        if (self.file) |f| {
            f.close();
        }
    }
};

fn parseArgs(allocator: mem.Allocator) !Config {
    const params = comptime [_]clap.Param(clap.Help) {
        clap.parseParam("<N>                 The number of lines to skip") catch unreachable,
        clap.parseParam("[<FILE>]            The file to read or stdin if not given") catch unreachable,
        clap.parseParam("-l, --line <STR>    Skip until N lines matching this") catch unreachable,
        clap.parseParam("-t, --token <STR>   Skip lines until N tokens found") catch unreachable,
        clap.parseParam("-i, --ignore-extras Only count the first token on each line") catch unreachable,
        clap.parseParam("-h, --help          Display this help and exit") catch unreachable,
        clap.parseParam("-v, --version       Display the version") catch unreachable,
    };
    var diag = clap.Diagnostic{};
    var args = clap.parse(clap.Help, &params, .{ .diagnostic = &diag }) catch |err| {
        diag.report(io.getStdErr().writer(), err) catch {};
        return error.BadArgs;
    };
    defer args.deinit();

    if (args.flag("--version")) {
        std.debug.print("skip version {s}\n", .{ version });
        return error.EarlyExit;
    }
    if (args.flag("--help")) {
        try io.getStdErr().writer().print("skip <N> [<FILE>] [-h|--help] [-v|--version]\n", .{});
        try clap.help(io.getStdErr().writer(), &params);
        return error.EarlyExit;
    }

    if (args.option("--line")) |_| {
        if (args.option("--token")) |_| {
            try io.getStdErr().writer().print("Error: only specify one of --line or --token, not both\n", .{});
            return error.BadArgs;
        }
    }


    var line: ?[]const u8 = null;
    if (args.option("--line")) |match| {
        line = try allocator.dupe(u8, match);
    }

    var token: ?[]const u8 = null;
    if (args.option("--token")) |match| {
        token = try allocator.dupe(u8, match);
    }
    var ignoreExtras: bool = false;
    if (args.flag("--ignore-extras")) {
        if (token) |_| {
            ignoreExtras = true;
        } else {
            try io.getStdErr().writer().print("Error: --ignore-extras requires --token\n", .{});
            return error.BadArgs;
        }
    }

    var n: u32 = 0;
    var file: ?fs.File = null;
    if (args.positionals().len == 0) {
        std.debug.print("Number of lines to skip not given. Try skip --help\n", .{});
        return error.EarlyExit;
    }
    if (args.positionals().len >= 1) {
        n = try fmt.parseInt(u32, args.positionals()[0], 10);
    }
    if (args.positionals().len >= 2) {
        const filename = args.positionals()[1];
        file = fs.cwd().openFile(filename, .{ .read = true, .write = false }) catch |err| switch (err) {
            error.FileNotFound => {
                try io.getStdErr().writer().print("Error: File not found: {s}\n",  .{ filename });
                return err;
            },
            else => return err,
        };
    }
    return Config {
        .lines = n,
        .file = file,
        .line = line,
        .token = token,
        .ignoreExtras = ignoreExtras,
    };
}

fn dumpInput(config: Config, in: fs.File, out: fs.File, allocator: mem.Allocator) !void {
    const writer = out.writer();
    const reader = in.reader();
    var it: LineIterator = lineIterator(reader, allocator);
    var c: usize = 0;
    while (c < config.lines) {
        const line = it.next();
        if (config.line) |match| {
            if (line) |memory| {
                if (mem.eql(u8, match, memory)) {
                    c += 1;
                }
            }
        } else {
            if (config.token) |token| {
                if (line) |memory| {
                    if (config.ignoreExtras) {
                        c += 1;
                    } else {
                        c += mem.count(u8, memory, token);
                    }
                }
            } else {
                c += 1;
            }
        }
        if (line) |memory| {
            allocator.free(memory);
        } else return;
    }
    try pumpIterator(&it, writer, allocator);
}

test "dumpInput skip 1 line" {
    const file = try fs.cwd().openFile("src/test/two-lines.txt", .{ .read = true, .write = false });
    defer file.close();

    const tempFile = "zig-cache/test.txt";

    const output = try fs.cwd().createFile(tempFile, .{});
    defer output.close();

    const config = Config{
        .lines = 1,
        .file = file,
    };

    try dumpInput(config, file, output, testing.allocator);

    const result = try fs.cwd().openFile(tempFile, .{ .read = true });
    defer result.close();

    var rit = lineIterator(result.reader(), testing.allocator);

    const line1 = rit.next().?;
    defer testing.allocator.free(line1);
    try testing.expectEqualStrings("line 2", line1);

    const eof = rit.next();
    try testing.expect(eof == null);
}

test "dumpInput skip 2 line 'alpha'" {
    const file = try fs.cwd().openFile("src/test/four-lines.txt", .{ .read = true, .write = false });
    defer file.close();

    const tempFile = "zig-cache/test.txt";

    const output = try fs.cwd().createFile(tempFile, .{});
    defer output.close();

    const config = Config{
        .lines = 2,
        .file = file,
        .line = "alpha",
    };

    try dumpInput(config, file, output, testing.allocator);

    const result = try fs.cwd().openFile(tempFile, .{ .read = true });
    defer result.close();

    var rit = lineIterator(result.reader(), testing.allocator);

    const line1 = rit.next().?;
    defer testing.allocator.free(line1);
    try testing.expectEqualStrings("gamma", line1);

    const eof = rit.next();
    try testing.expect(eof == null);
}

fn pumpIterator(it: *LineIterator, writer: fs.File.Writer, allocator: mem.Allocator) !void {
    while (it.next()) |line| {
        defer allocator.free(line);
        
        try writer.print("{s}\n", .{ windowsSafe(line) });
    }
}

test "pumpIterator" {
    const file = try fs.cwd().openFile("src/test/two-lines.txt", .{ .read = true, .write = false });
    defer file.close();

    const tempFile = "zig-cache/test.txt";

    const output = try fs.cwd().createFile(tempFile, .{});
    defer output.close();

    var reader = file.reader();
    var it = lineIterator(reader, testing.allocator);

    var writer = output.writer();

    try pumpIterator(&it, writer, testing.allocator);

    const result = try fs.cwd().openFile(tempFile, .{ .read = true });
    defer result.close();

    var rit = lineIterator(result.reader(), testing.allocator);

    const line1 = rit.next().?;
    defer testing.allocator.free(line1);
    try testing.expectEqualStrings("line 1", line1);

    const line2 = rit.next().?;
    defer testing.allocator.free(line2);
    try testing.expectEqualStrings("line 2", line2);
    const eof = rit.next();

    try testing.expect(eof == null);
}

const LineIterator = struct {
    reader: io.BufferedReader(maxLineLength, fs.File.Reader),
    delimiter: u8,
    allocator: mem.Allocator,

    const Self = @This();

    /// Caller owns returned memory
    pub fn next(self: *Self) ?[]u8 {
        return self.reader.reader().readUntilDelimiterOrEofAlloc(self.allocator, self.delimiter, maxLineLength) catch null;
    }
};

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

fn windowsSafe(line: []const u8) []const u8 {
    // trim annoying windows-only carriage return character
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
