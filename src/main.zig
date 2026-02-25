const std = @import("std");
const net = std.net;
const client = @import("client.zig");
const opts = @import("opts.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();

    const parsedArgs = try opts.parse(alloc);
    if (parsedArgs) |args| {
        defer args.deinit();

        const host = if (args.uri.host) |h| h.percent_encoded else return error.InvalidHost;
        const port = if (args.uri.port) |p| p else return error.InvalidPort;
        std.log.info("Connecting to {s}:{d}\n", .{ host, port });
        const stream = try net.tcpConnectToHost(alloc, host, port);
        defer stream.close();

        var read_buf: [4096]u8 = undefined;
        var write_buf: [4096]u8 = undefined;
        var tnClient = client.TelnetClient.init(stream, &read_buf, &write_buf);

        std.log.info("Press CTL-C to exit.", .{});
        const handle = try std.Thread.spawn(.{}, readInput, .{&tnClient});
        handle.detach();

        while (true) {
            try tnClient.read();
        }
    }
}

fn readInput(tnClient: *client.TelnetClient) !void {
    const stdin_file = std.fs.File.stdin();
    while (true) {
        var buf: [64]u8 = undefined;
        const len = stdin_file.read(&buf) catch break;
        if (len > 0) {
            try tnClient.write(buf[0..len]);
        }
    }
}
