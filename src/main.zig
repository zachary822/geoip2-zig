const std = @import("std");
const c = @cImport({
    @cInclude("maxminddb.h");
});

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var mmdb: c.MMDB_s = undefined;

    var status = c.MMDB_open(args[1], c.MMDB_MODE_MMAP, &mmdb);
    defer c.MMDB_close(&mmdb);

    if (status != c.MMDB_SUCCESS) {
        std.debug.print("Failed to open database: {s}\n", .{c.MMDB_strerror(status)});
        return 1;
    }

    const ip = try allocator.dupeZ(u8, args[2]);
    defer allocator.free(ip);

    var gai_error: c_int = undefined;

    var result = c.MMDB_lookup_string(&mmdb, ip, &gai_error, &status);

    if (gai_error != 0) {
        std.debug.print("Error parsing IP: {s}\n", .{c.gai_strerror(gai_error)});
        return 1;
    }

    if (status != 0) {
        std.debug.print("MaxMind DB lookup error: {s}\n", .{c.MMDB_strerror(status)});
        return 1;
    }

    if (!result.found_entry) {
        std.debug.print("No record found for IP address: {s}\n", .{ip});
        return 0;
    }

    std.debug.print("netmask: {d}\n", .{result.netmask - 96});

    var entry_data: c.MMDB_entry_data_s = undefined;
    status = c.MMDB_get_value(&result.entry, &entry_data, "autonomous_system_organization");

    if (status == c.MMDB_SUCCESS and entry_data.has_data) {
        std.debug.print("type: {d}\n", .{entry_data.type});

        switch (entry_data.type) {
            c.MMDB_DATA_TYPE_UTF8_STRING => {
                const str = try allocator.allocSentinel(u8, entry_data.data_size, 0);
                defer allocator.free(str);

                for (0..entry_data.data_size) |i| {
                    str[i] = entry_data.unnamed_0.utf8_string[i];
                }

                std.debug.print("AS Organization: {s}\n", .{str});
            },
            else => {},
        }

        return 0;
    }

    return 1;
}
