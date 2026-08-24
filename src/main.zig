const std = @import("std");
const net = std.Io.net;
const client = @import("client.zig");
const opts = @import("opts.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
};

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;

    const parsedArgs = try opts.parse(alloc, init);
    if (parsedArgs) |args| {
        defer args.deinit();

        const host = if (args.uri.host) |h| h.percent_encoded else return error.InvalidHost;
        const port = if (args.uri.port) |p| p else return error.InvalidPort;
        std.log.info("Connecting to {s}:{d}\n", .{ host, port });

        var host_name: net.HostName = undefined;
        net.HostName.validate(host) catch return error.InvalidHost;
        host_name = .{ .bytes = host };
        const stream = try host_name.connect(io, port, .{ .mode = .stream });
        defer stream.close(io);

        var read_buf: [4096]u8 = undefined;
        var write_buf: [4096]u8 = undefined;
        var tnClient = client.TelnetClient.init(stream, io, &read_buf, &write_buf);

        std.log.info("Press CTL-C to exit.", .{});
        const handle = try std.Thread.spawn(.{}, readInput, .{ &tnClient, io });
        handle.detach();

        while (true) {
            try tnClient.read();
        }
    }
}

fn readInput(tnClient: *client.TelnetClient, io: std.Io) !void {
    const stdin_file = std.Io.File.stdin();
    while (true) {
        var buf: [64]u8 = undefined;
        const len = stdin_file.readStreaming(io, &.{&buf}) catch break;
        if (len > 0) {
            try tnClient.write(buf[0..len]);
        }
    }
}
