const std = @import("std");
const os = std.os;

const ZigetError = error{
    CreateSockFail,
    InvalidAddr,
    ConnectError,
    SendError,
    RecvError,
};

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var allocator = &arena.allocator;
    var args_it = std.process.args();

    // skip args[0]

    _ = args_it.skip();

    const host = try (args_it.next(allocator) orelse {
        std.debug.warn("no host provided\n", .{});
        return error.InvalidArgs;
    });

    const remote_path = try (args_it.next(allocator) orelse {
        std.debug.warn("no remote path provided\n", .{});
        return error.InvalidArgs;
    });

    const output_path = try (args_it.next(allocator) orelse {
        std.debug.warn("no path provided\n", .{});
        return error.InvalidArgs;
    });

    std.debug.warn("host: {s} remote: {s} output path: {s}\n", .{ host, remote_path, output_path });

    var conn = try std.net.tcpConnectToHost(allocator, host, 80);
    defer conn.close();

    var buffer: [256]u8 = undefined;
    const base_http = "GET {s} HTTP/1.1\r\nHost: {s}\r\nConnection: close\r\n\r\n";
    var msg = try std.fmt.bufPrint(&buffer, base_http, .{ remote_path, host });

    _ = try conn.write(msg);

    var buf: [1024]u8 = undefined;
    var total_bytes: usize = 0;

    var file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();

    while (true) {
        const byte_count = try conn.read(&buf);
        if (byte_count == 0) break;

        _ = try file.write(&buf);
        total_bytes += byte_count;
    }

    std.debug.warn("written {any} bytes to file '{s}'\n", .{ total_bytes, output_path });
}
