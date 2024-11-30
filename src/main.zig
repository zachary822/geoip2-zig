const std = @import("std");
const c = @cImport({
    @cInclude("maxminddb.h");
});
const geoip2 = @import("root.zig");
const MMDB = geoip2.MMDB;
const MMDBError = geoip2.MMDBError;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var mmdb = try MMDB.init(args[1]);
    defer mmdb.deinit();

    std.debug.print("version: {s}\n", .{MMDB.version()});

    const ip = try allocator.dupeZ(u8, args[2]);
    defer allocator.free(ip);

    var status: c_int = undefined;

    var result = try mmdb.lookupString(ip);

    std.debug.print("netmask: {d}\n", .{result.netmask - 96});

    var entry_data: c.MMDB_entry_data_s = undefined;
    status = c.MMDB_get_value(&result.entry, &entry_data, "autonomous_system_organization");

    if (status == c.MMDB_SUCCESS and entry_data.has_data) {
        switch (entry_data.type) {
            c.MMDB_DATA_TYPE_UTF8_STRING => {
                const str = try allocator.allocSentinel(u8, entry_data.data_size, 0);
                defer allocator.free(str);

                @memcpy(str, entry_data.unnamed_0.utf8_string[0..entry_data.data_size]);

                std.debug.print("AS Organization: {s}\n", .{str});
            },
            else => {},
        }

        return 0;
    }

    return 1;
}
