const std = @import("std");
const c = @cImport({
    @cInclude("maxminddb.h");
});

pub const MMDBError = error{
    OpenError,
    GaiError,
    LookupError,
    EntryNotFound,
};

pub const MMDB = struct {
    pub const Result = struct {
        entry: c.MMDB_entry_s,
        netmask: u16,
    };

    mmdb: c.MMDB_s,

    pub fn init(path: [:0]const u8) !MMDB {
        var mmdb: c.MMDB_s = undefined;
        const status = c.MMDB_open(path, c.MMDB_MODE_MMAP, &mmdb);

        if (status != c.MMDB_SUCCESS) {
            std.debug.print("{s}\n", .{c.MMDB_strerror(status)});
            return MMDBError.OpenError;
        }

        return .{ .mmdb = mmdb };
    }

    pub fn deinit(self: *MMDB) void {
        c.MMDB_close(&self.mmdb);
    }

    pub fn version() [:0]const u8 {
        return std.mem.span(c.MMDB_lib_version());
    }

    pub fn lookupString(self: *MMDB, ip: [:0]const u8) !Result {
        var gai_error: c_int = undefined;
        var status: c_int = undefined;

        const result = c.MMDB_lookup_string(&self.mmdb, ip, &gai_error, &status);

        if (gai_error != 0) {
            std.debug.print("Error parsing IP: {s}\n", .{c.gai_strerror(gai_error)});
            return MMDBError.GaiError;
        }
        if (status != 0) {
            std.debug.print("MaxMind DB lookup error: {s}\n", .{c.MMDB_strerror(status)});
            return MMDBError.LookupError;
        }
        if (!result.found_entry) {
            return MMDBError.EntryNotFound;
        }

        return .{ .entry = result.entry, .netmask = result.netmask };
    }
};
