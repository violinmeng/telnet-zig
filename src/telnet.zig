const std = @import("std");

// Default port for the application
pub const DEFAULT_PORT: u16 = 23;

// Constant byte values for Telnet protocol
pub const IAC_BYTE: u8 = 255; // "Interpret as Command" byte
pub const IS_BYTE: u8 = 0; // "IS" byte
pub const SEND_BYTE: u8 = 1; // "SEND" byte

pub const Command = enum(u8) {
    se = 240, // End of subnegotiation parameters
    nop = 241, // No operation
    dm = 242, // Data mark
    brk = 243, // Break
    ip = 244, // Suspend, interrupt or abort process
    ao = 245, // Abort output
    ayt = 246, // Are you there
    ec = 247, // Erase character
    el = 248, // Erase line
    ga = 249, // Go ahead
    sb = 250, // Start of subnegotiation of the indicated option
    will = 251, // Willing to begin performing the indicated option
    wont = 252, // Refusing to perform the indicated option
    do = 253, // Request to perform the indicated option
    dont = 254, // Demand to stop performing the indicated option
    iac = 255, // data byte 255
};

pub const Option = enum(u8) {
    transmitBinary = 0, // Binary Transmission (RFC 856)
    echo = 1, // Echo (RFC 857)
    reconnection = 2, // Reconnection (NIC 15391 of 1973)
    suppressGoAhead = 3, // Suppress Go Ahead (RFC 858): No "go ahead" signal will be sent (required for half-duplex transmissions) -> full-duplex
    approxMessageSizeNegotiation = 4, // Approx Message Size Negotiation (NIC 15393 of 1973)
    status = 5, // Status (RFC 859)
    timingMark = 6, // Timing Mark (RFC 860)
    remoteControlledTransAndEcho = 7, // Remote Controlled Trans and Echo (RFC 726)
    outputLineWidth = 8, // Output Line Width (NIC 20196 of August 1978)
    outputPageSize = 9, // Output Page Size (NIC 20197 of August 1978)
    outputCarriageReturnDisposition = 10, // Output Carriage-Return Disposition (RFC 652)
    outputHorizontalTabStops = 11, // Output Horizontal Tab Stops (RFC 653)
    outputHorizontalTabDisposition = 12, // Output Horizontal Tab Disposition (RFC 654)
    outputFormfeedDisposition = 13, // Output Formfeed Disposition (RFC 655)
    outputVerticalTabstops = 14, // Output Vertical Tabstops (RFC 656)
    outputVerticalTabDisposition = 15, // Output Vertical Tab Disposition (RFC 657)
    outputLinefeedDisposition = 16, // Output Linefeed Disposition (RFC 658)
    extendedASCII = 17, // Extended ASCII (RFC 698)
    logout = 18, // Logout (RFC 727)
    byteMacro = 19, // Byte Macro (RFC 735)
    dataEntryTerminal = 20, // Data Entry Terminal (RFC 1043, RFC 732)
    supdup = 21, // SUPDUP (RFC 736, RFC 734)
    supdupOutput = 22, // SUPDUP Output (RFC 749)
    sendLocation = 23, // Send Location (RFC 779)
    terminalType = 24, // Terminal Type (RFC 1091): Requests the name of the terminal type in ASCII format
    endOfRecord = 25, // End of Record (RFC 885)
    tacacsUserIdentification = 26, // TACACS User Identification (RFC 927)
    outputMarking = 27, // Output Marking (RFC 933)
    terminalLocationNumber = 28, // Terminal Location Number (RFC 946)
    telnet3270Regime = 29, // Telnet 3270 Regime (RFC 1041)
    x3pad = 30, // X.3 PAD (RFC 1053)
    negotiateAboutWindowSize = 31, // Negotiate About Window Size (RFC 1073)
    terminalSpeed = 32, // Terminal Speed (RFC 1079)
    remoteFlowControl = 33, // Remote Flow Control (RFC 1372)
    linemode = 34, // Linemode (RFC 1184)
    xDisplayLocation = 35, // X Display Location (RFC 1096)
    environmentOption = 36, // Environment Option (RFC 1408)
    authenticationOption = 37, // Authentication Option (RFC 2941)
    encryptionOption = 38, // Encryption Option (RFC 2946)
    newEnvironmentOption = 39, // New Environment Option (RFC 1572)
    tn3270e = 40, // TN3270E (RFC 2355)
    xauth = 41, // XAUTH
    charset = 42, // CHARSET (RFC 2066)
    telnetRemoteSerialPort = 43, // Telnet Remote Serial Port (RSP)
    comPortControlOption = 44, // Com Port Control Option (RFC 2217)
    telnetSuppressLocalEcho = 45, // Telnet Suppress Local Echo
    telnetStartTLS = 46, // Telnet Start TLS
    kermit = 47, // KERMIT (RFC 2840)
    sendurl = 48, // SEND-URL
    forwardx = 49, // FORWARD_X
    unassigned50To137 = 50, // Unassigned (50-137)
    teloptpragmalogon = 138, // TELOPT PRAGMA LOGON
    teloptsspilogon = 139, // TELOPT SSPI LOGON
    teloptpragmaheartbeat = 140, // TELOPT PRAGMA HEARTBEAT
    unassigned141To254 = 141, // Unassigned (141-254)
    extendedOptionsList = 255, // Extended-Options-List (RFC 861)
};

// Function to create an instruction array from a command and option
pub fn instruction(command: Command, option: Option) [3]u8 {
    return [3]u8{ IAC_BYTE, @intFromEnum(command), @intFromEnum(option) };
}

// Function to create an instruction array from a command and option
pub fn subnegotiate(option: Option, comptime payload: []const u8) [payload.len + 5]u8 {
    var data = [_]u8{0} ** (payload.len + 5);

    data[0] = IAC_BYTE;
    data[1] = @intFromEnum(Command.sb);
    data[2] = @intFromEnum(option);
    std.mem.copyBackwards(u8, data[3 .. 3 + payload.len], payload);
    data[payload.len + 3] = IAC_BYTE;
    data[payload.len + 4] = @intFromEnum(Command.se);

    return data;
}
