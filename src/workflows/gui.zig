const std = @import("std");
const app_runtime = @import("../core/runtime.zig");
const cli = @import("../cli/root.zig");
const io_util = @import("../core/io_util.zig");
const registry = @import("../registry/root.zig");
const live_flow = @import("live.zig");
const login_workflow = @import("login.zig");
const usage_refresh = @import("usage.zig");

pub fn handleGui(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.GuiOptions) !void {
    switch (opts) {
        .state => |state_opts| try handleState(allocator, codex_home, state_opts, false),
        .refresh => |state_opts| try handleState(allocator, codex_home, state_opts, true),
        .switch_account => |account_key| try handleSwitch(allocator, codex_home, account_key),
        .login => |login_opts| try handleLogin(allocator, codex_home, login_opts),
        .import_auth => |import_opts| try handleImport(allocator, codex_home, import_opts),
        .remove_account => |account_key| try handleRemove(allocator, codex_home, account_key),
        .alias => |alias_opts| try handleAlias(allocator, codex_home, alias_opts),
    }
}

fn handleState(
    allocator: std.mem.Allocator,
    codex_home: []const u8,
    opts: cli.types.GuiStateOptions,
    force_refresh: bool,
) !void {
    var reg = try registry.loadRegistry(allocator, codex_home);
    defer reg.deinit(allocator);
    if (try registry.syncActiveAccountFromAuth(allocator, codex_home, &reg)) {
        try registry.saveRegistry(allocator, codex_home, &reg);
    }
    const attempted = force_refresh;
    if (force_refresh) {
        const usage_api_enabled = apiModeUsesApi(reg.api.usage, opts.api_mode);
        var refresh_state = try usage_refresh.refreshForegroundUsageForDisplayWithBatchFetcherUsingApiEnabledAndActiveOnly(
            allocator,
            codex_home,
            &reg,
            usage_api_enabled,
            opts.active_only,
        );
        defer refresh_state.deinit(allocator);
    }
    try writeStateJson(allocator, codex_home, &reg, attempted, if (attempted) "ok" else "skipped", null);
}

fn handleSwitch(allocator: std.mem.Allocator, codex_home: []const u8, account_key: []const u8) !void {
    var reg = try registry.loadRegistry(allocator, codex_home);
    defer reg.deinit(allocator);
    if (try registry.syncActiveAccountFromAuth(allocator, codex_home, &reg)) {
        try registry.saveRegistry(allocator, codex_home, &reg);
    }
    try registry.activateAccountByKey(allocator, codex_home, &reg, account_key);
    try registry.saveRegistry(allocator, codex_home, &reg);
    try writeStateJson(allocator, codex_home, &reg, false, "skipped", null);
}

fn handleLogin(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.LoginOptions) !void {
    try login_workflow.handleLogin(allocator, codex_home, opts);
    var reg = try registry.loadRegistry(allocator, codex_home);
    defer reg.deinit(allocator);
    try writeStateJson(allocator, codex_home, &reg, false, "skipped", null);
}

fn handleImport(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.GuiImportOptions) !void {
    var reg = try registry.loadRegistry(allocator, codex_home);
    defer reg.deinit(allocator);
    var report = try registry.importAuthPath(allocator, codex_home, &reg, opts.auth_path, opts.alias);
    defer report.deinit(allocator);
    if (report.appliedCount() > 0) {
        try registry.saveRegistry(allocator, codex_home, &reg);
    }
    if (report.failure != null) return error.ImportFailed;
    try writeStateJson(allocator, codex_home, &reg, false, "skipped", null);
}

fn handleRemove(allocator: std.mem.Allocator, codex_home: []const u8, account_key: []const u8) !void {
    var reg = try registry.loadRegistry(allocator, codex_home);
    defer reg.deinit(allocator);
    const idx = registry.findAccountIndexByAccountKey(&reg, account_key) orelse return error.AccountNotFound;
    var selected = [_]usize{idx};
    try live_flow.removeSelectedAccountsAndPersist(allocator, codex_home, &reg, selected[0..], false);
    try writeStateJson(allocator, codex_home, &reg, false, "skipped", null);
}

fn handleAlias(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.GuiAliasOptions) !void {
    var reg = try registry.loadRegistry(allocator, codex_home);
    defer reg.deinit(allocator);
    switch (opts) {
        .set => |set_opts| {
            const idx = registry.findAccountIndexByAccountKey(&reg, set_opts.account_key) orelse return error.AccountNotFound;
            try validateAlias(&reg, set_opts.alias, idx);
            try replaceAlias(allocator, &reg.accounts.items[idx], set_opts.alias);
        },
        .clear => |clear_opts| {
            const idx = registry.findAccountIndexByAccountKey(&reg, clear_opts.account_key) orelse return error.AccountNotFound;
            try replaceAlias(allocator, &reg.accounts.items[idx], "");
        },
    }
    try registry.saveRegistry(allocator, codex_home, &reg);
    try writeStateJson(allocator, codex_home, &reg, false, "skipped", null);
}

fn writeStateJson(
    allocator: std.mem.Allocator,
    codex_home: []const u8,
    reg: *const registry.Registry,
    refresh_attempted: bool,
    refresh_status: []const u8,
    refresh_message: ?[]const u8,
) !void {
    _ = allocator;
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    const now = std.Io.Timestamp.now(app_runtime.io(), .real).toSeconds();

    try out.writeAll("{");
    try out.print("\"schema_version\":{d},", .{reg.schema_version});
    try out.writeAll("\"codex_home\":");
    try writeJsonString(out, codex_home);
    try out.writeAll(",\"active_account_key\":");
    try writeOptionalJsonString(out, reg.active_account_key);
    try out.print(",\"generated_at\":{d},", .{now});
    try out.print("\"refresh\":{{\"attempted\":{},\"status\":", .{refresh_attempted});
    try writeJsonString(out, refresh_status);
    try out.writeAll(",\"message\":");
    try writeOptionalJsonString(out, refresh_message);
    try out.writeAll("},\"warnings\":[],\"accounts\":[");
    for (reg.accounts.items, 0..) |rec, idx| {
        if (idx != 0) try out.writeAll(",");
        try writeAccountJson(out, reg, &rec, now);
    }
    try out.writeAll("]}\n");
    try out.flush();
}

fn writeAccountJson(out: *std.Io.Writer, reg: *const registry.Registry, rec: *const registry.AccountRecord, now: i64) !void {
    try out.writeAll("{\"account_key\":");
    try writeJsonString(out, rec.account_key);
    try out.writeAll(",\"display_name\":");
    try writeJsonString(out, displayName(rec));
    try out.writeAll(",\"alias\":");
    try writeOptionalNonEmptyJsonString(out, rec.alias);
    try out.writeAll(",\"email\":");
    try writeOptionalNonEmptyJsonString(out, rec.email);
    try out.writeAll(",\"account_name\":");
    try writeOptionalJsonString(out, rec.account_name);
    try out.writeAll(",\"plan\":");
    if (registry.resolveDisplayPlan(rec)) |plan| {
        try writeJsonString(out, @tagName(plan));
    } else {
        try out.writeAll("null");
    }
    try out.writeAll(",\"auth_mode\":");
    if (rec.auth_mode) |mode| {
        try writeJsonString(out, @tagName(mode));
    } else {
        try out.writeAll("null");
    }
    const is_active = if (reg.active_account_key) |key| std.mem.eql(u8, key, rec.account_key) else false;
    try out.print(",\"is_active\":{},", .{is_active});
    try out.writeAll("\"usage\":{");
    try out.writeAll("\"five_hour\":");
    try writeUsageWindowJson(out, registry.resolveRateWindow(rec.last_usage, 300, true), now);
    try out.writeAll(",\"seven_day\":");
    try writeUsageWindowJson(out, registry.resolveRateWindow(rec.last_usage, 10080, false), now);
    try out.writeAll("},\"last_usage_at\":");
    try writeOptionalInt(out, rec.last_usage_at);
    try out.writeAll(",\"last_refresh_at\":");
    try writeOptionalInt(out, rec.last_usage_at);
    try out.writeAll("}");
}

fn writeUsageWindowJson(out: *std.Io.Writer, window: ?registry.RateLimitWindow, now: i64) !void {
    try out.writeAll("{\"status\":");
    if (window == null) {
        try writeJsonString(out, "unknown");
        try out.writeAll(",\"remaining_percent\":null,\"total\":null,\"used\":null,\"reset_at\":null}");
        return;
    }
    const value = window.?;
    try writeJsonString(out, "ok");
    try out.writeAll(",\"remaining_percent\":");
    try writeOptionalInt(out, registry.remainingPercentAt(window, now));
    try out.writeAll(",\"total\":100,\"used\":");
    try out.print("{d}", .{@as(i64, @intFromFloat(value.used_percent))});
    try out.writeAll(",\"reset_at\":");
    try writeOptionalInt(out, value.resets_at);
    try out.writeAll("}");
}

fn displayName(rec: *const registry.AccountRecord) []const u8 {
    if (rec.alias.len != 0) return rec.alias;
    if (rec.account_name) |account_name| {
        if (account_name.len != 0) return account_name;
    }
    return rec.email;
}

fn writeOptionalInt(out: *std.Io.Writer, value: ?i64) !void {
    if (value) |actual| {
        try out.print("{d}", .{actual});
    } else {
        try out.writeAll("null");
    }
}

fn writeOptionalJsonString(out: *std.Io.Writer, value: ?[]const u8) !void {
    if (value) |actual| {
        try writeJsonString(out, actual);
    } else {
        try out.writeAll("null");
    }
}

fn writeOptionalNonEmptyJsonString(out: *std.Io.Writer, value: []const u8) !void {
    if (value.len == 0) {
        try out.writeAll("null");
    } else {
        try writeJsonString(out, value);
    }
}

fn writeJsonString(out: *std.Io.Writer, value: []const u8) !void {
    try out.writeAll("\"");
    for (value) |ch| {
        switch (ch) {
            '"' => try out.writeAll("\\\""),
            '\\' => try out.writeAll("\\\\"),
            '\n' => try out.writeAll("\\n"),
            '\r' => try out.writeAll("\\r"),
            '\t' => try out.writeAll("\\t"),
            else => {
                if (ch < 0x20) {
                    const hex = "0123456789abcdef";
                    var escaped = [_]u8{ '\\', 'u', '0', '0', hex[(ch >> 4) & 0xf], hex[ch & 0xf] };
                    try out.writeAll(&escaped);
                } else {
                    var buf = [_]u8{ch};
                    try out.writeAll(&buf);
                }
            },
        }
    }
    try out.writeAll("\"");
}

fn replaceAlias(allocator: std.mem.Allocator, rec: *registry.AccountRecord, alias_value: []const u8) !void {
    const owned_alias = try allocator.dupe(u8, alias_value);
    allocator.free(rec.alias);
    rec.alias = owned_alias;
}

fn validateAlias(reg: *const registry.Registry, alias_value: []const u8, selected_idx: usize) !void {
    if (alias_value.len == 0) return error.InvalidAlias;
    for (alias_value) |ch| {
        if (ch < 0x20 or ch == 0x7f) return error.InvalidAlias;
    }
    for (reg.accounts.items, 0..) |rec, idx| {
        if (idx == selected_idx) continue;
        if (rec.alias.len != 0 and std.ascii.eqlIgnoreCase(rec.alias, alias_value)) {
            return error.DuplicateAlias;
        }
    }
}

fn apiModeUsesApi(default_enabled: bool, mode: cli.types.ApiMode) bool {
    return switch (mode) {
        .default => default_enabled,
        .force_api => true,
        .skip_api => false,
    };
}
