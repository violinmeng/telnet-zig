const std = @import("std");
const Io = std.Io;
const net = Io.net;
const print = std.debug.print;
const telnet = @import("telnet.zig");
const Command = telnet.Command;
const Option = telnet.Option;

const State = enum {
    normal,
    iac,
    negotiating,
    subnegotiating,
};

const StateInfo = union(State) {
    normal: void,
    iac: void,
    negotiating: telnet.Command,
    subnegotiating: telnet.Option,
};

pub const TelnetClient = struct {
    stream: net.Stream,
    io: Io,
    reader: net.Stream.Reader,
    writer: net.Stream.Writer,
    state: StateInfo,

    pub fn init(stream: net.Stream, io: Io, read_buf: []u8, write_buf: []u8) TelnetClient {
        return TelnetClient{
            .stream = stream,
            .io = io,
            .reader = net.Stream.Reader.init(stream, io, read_buf),
            .writer = net.Stream.Writer.init(stream, io, write_buf),
            .state = .normal,
        };
    }

    pub fn write(self: *TelnetClient, data: []u8) anyerror!void {
        std.log.debug("Writing {d} bytes", .{data.len});

        try self.writer.interface.writeAll(data);
        try self.writer.interface.flush();
    }

    pub fn read(self: *TelnetClient) anyerror!void {
        const byte = try self.reader.interface.takeByte();

        switch (self.state) {
            .normal => {
                if (byte == telnet.IAC_BYTE) {
                    self.state = .iac;
                } else {
                    print("{c}", .{byte});
                }
            },

            .iac => {
                const cmd: telnet.Command = @enumFromInt(byte);
                switch (cmd) {
                    .nop => {
                        std.log.debug("Recieved NOP", .{});
                        self.state = .normal;
                    },
                    .iac => {
                        print("{c}", .{telnet.IAC_BYTE});
                        self.state = .normal;
                    },
                    .will, .wont, .do, .dont, .sb => {
                        self.state = StateInfo{ .negotiating = cmd };
                    },
                    .se => {
                        self.state = .normal;
                    },
                    else => {
                        std.log.warn("Unhandled command: {s} (state: {s})", .{ @tagName(cmd), @tagName(self.state) });
                        self.state = .normal;
                    },
                }
            },

            .negotiating => |command| {
                const option: telnet.Option = @enumFromInt(byte);
                std.log.debug("S: {s} {s}", .{ @tagName(command), @tagName(option) });

                switch (option) {
                    .echo => {
                        switch (command) {
                            .will => {
                                std.log.debug("Server wants to echo, we allow him", .{});
                                try self.send(.do, .echo);
                            },
                            .wont => {
                                std.log.debug("Server does not want to echo, we are fine with that", .{});
                                try self.send(.dont, .echo);
                            },
                            .do => {
                                std.log.debug("Server asks us to echo, we decline", .{});
                                try self.send(.wont, .echo);
                            },
                            .dont => {
                                std.log.debug("Server asks us not to echo, we won't", .{});
                                try self.send(.wont, .echo);
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                        self.state = .normal;
                    },
                    .suppressGoAhead => {
                        switch (command) {
                            .will => {
                                std.log.debug("Server wants to suppress go ahead, we allow him", .{});
                                try self.send(.do, .suppressGoAhead);
                            },
                            .wont => {
                                std.log.warn("Server refused to suppress go ahead", .{});
                                try self.send(.do, .suppressGoAhead);
                            },
                            .do => {
                                std.log.debug("Server asks us to suppress go ahead, we accept", .{});
                                try self.send(.will, .suppressGoAhead);
                            },
                            .dont => {
                                std.log.warn("Server asks us not to suppress go ahead, we won't", .{});
                                try self.send(.wont, .suppressGoAhead);
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                        self.state = .normal;
                    },
                    .negotiateAboutWindowSize => {
                        switch (command) {
                            .do => {
                                std.log.debug("Server wants to negotiate about window size, we send the info", .{});
                                try self.send(.will, .negotiateAboutWindowSize);

                                const windowSizeData = &[_]u8{
                                    0, 80, // Width
                                    0, 24, // Height
                                };
                                const negotiation = &telnet.subnegotiate(Option.negotiateAboutWindowSize, windowSizeData);
                                try self.writer.interface.writeAll(negotiation);
                                try self.writer.interface.flush();
                            },
                            .dont => {
                                std.log.debug("Server does not want to negotiate about window size, we accept", .{});
                                try self.send(.wont, .negotiateAboutWindowSize);
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                        self.state = .normal;
                    },
                    .terminalType => {
                        switch (command) {
                            .do => {
                                std.log.debug("Server wants to ask us for our terminal type, we agree", .{});
                                try self.send(.will, .terminalType);

                                self.state = .normal;
                            },
                            .dont => {
                                std.log.debug("Server does not want to know our terminal type", .{});
                                try self.send(.wont, .terminalType);

                                self.state = .normal;
                            },
                            .sb => {
                                std.log.debug("Server wants to know our terminal type...", .{});

                                self.state = StateInfo{
                                    .subnegotiating = Option.terminalType,
                                };
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                    },
                    .transmitBinary => {
                        switch (command) {
                            .do => {
                                std.log.debug("Server wants to transmit binary, we agree", .{});
                                try self.send(.will, .transmitBinary);
                            },
                            .dont => {
                                std.log.debug("Server does not want to transmit binary, we agree", .{});
                                try self.send(.wont, .transmitBinary);
                            },
                            .will => {
                                std.log.debug("Server wants us to transmit binary, we agree", .{});
                                try self.send(.do, .transmitBinary);
                            },
                            .wont => {
                                std.log.debug("Server does not want us to transmit binary, we agree", .{});
                                try self.send(.dont, .transmitBinary);
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                    },
                    else => {
                        switch (command) {
                            .do => {
                                std.log.debug("Server wants us to perform subcommand `{s}`, we refuse", .{@tagName(option)});
                                try self.send(.wont, option);
                            },
                            .dont => {
                                std.log.debug("Server does not want us to perform subcommand `{s}`, we refuse", .{@tagName(option)});
                            },
                            .will, .wont => {
                                std.log.warn("Server wants to negotiate option `{s}`", .{@tagName(option)});
                            },
                            else => {
                                std.log.warn("Unsupported negotiation command `{s}` for option `{s}` (state: {s})", .{ @tagName(command), @tagName(option), @tagName(self.state) });
                            },
                        }
                        self.state = .normal;
                    },
                }
            },

            .subnegotiating => |option| {
                std.log.debug("Subnegotiating option `{s}`", .{@tagName(option)});
                switch (option) {
                    .terminalType => {
                        if (byte == telnet.SEND_BYTE) {
                            std.log.debug("Send terminal type", .{});
                            const terminalTypeData: []const u8 = &[_]u8{
                                telnet.IS_BYTE, // Is
                                'X',
                                'T',
                                'E',
                                'R',
                                'M',
                                '-',
                                '2',
                                '5',
                                '6',
                                'C',
                                'O',
                                'L',
                                'O',
                                'R',
                            };
                            const negotiation: []const u8 = &telnet.subnegotiate(Option.terminalType, terminalTypeData);
                            try self.writer.interface.writeAll(negotiation);
                            try self.writer.interface.flush();

                            self.state = .normal;
                        } else {
                            std.log.warn("Unsupported data byte {d} during subnegotiation option `{s}` (state: {s}),", .{ byte, @tagName(option), @tagName(self.state) });
                            self.state = .normal;
                        }
                    },
                    else => {
                        std.log.warn("Unsupported subnegotiation option `{s}` (state: {s})", .{ @tagName(option), @tagName(self.state) });
                        self.state = .normal;
                    },
                }
            },
        }
    }

    fn send(self: *TelnetClient, command: Command, option: Option) anyerror!void {
        std.log.debug("C: {s} {s}", .{ @tagName(command), @tagName(option) });
        try self.writer.interface.writeAll(&telnet.instruction(command, option));
        try self.writer.interface.flush();
    }
};
