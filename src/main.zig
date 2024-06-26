const std = @import("std");
const printf = std.c.printf;
const httpz = @import("httpz");
const Request = httpz.Request;
const Response = httpz.Response;
const routes = @import("./routes.zig");
const configModule = @import("./config.zig");

pub const std_options = .{
    .log_level = .info,
};

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    try configModule.initConfig(allocator, "./config.json", true);
    const config = try configModule.getConfig();

    var port: ?u16 = config.port;
    var host: ?[]const u8 = config.host;

    if (config.unixSocket != null) {
        port = null;
        host = null;
    }

    var server = try httpz.Server().init(
        allocator,
        .{
            .port = port,
            .address = host,
            .unix_path = config.unixSocket,
            .thread_pool = .{
                .count = if (config.threads > 0) config.threads else @intCast(try std.Thread.getCpuCount()),
            },
        },
    );

    const router = server.router();

    routes.registerRoutes(router, "/v1/systemd/manager", routes.v1.systemd.manager);

    routes.registerRoutes(router, "/journal", routes.journal.Routes);
    routes.registerRoutes(router, "/pid1", routes.pidEins.Routes);
    routes.registerRoutes(router, "/linux", routes.linux.Routes);

    if (config.unixSocket) |unixSocket| {
        std.log.info("Server will listen on unix socket {s}", .{unixSocket});
    } else {
        std.log.info("Server will listen on {s}:{d}", .{
            host orelse "127.0.0.1",
            port orelse 5882,
        });
    }

    try server.listen();
}

fn getHello(_: *Request, res: *Response) !void {
    try res.json(.{ .hello = "world" }, .{});
}

fn forbiddenRoute(_: *Request, res: *Response) !void {
    res.status = 403;
    res.content_type = .JSON;
}
