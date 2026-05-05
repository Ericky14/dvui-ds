/// Button — comptime builder wrapping dvui.button().
///
/// Usage:
///   if (ds.button(@src(), "Save").variant(.filled).size(.lg).draw()) { ... }
///   if (ds.button(@src(), "Cancel").draw()) { ... }  // defaults: ghost, sm
const std = @import("std");
const dvui = @import("dvui");
const tokens = @import("tokens.zig");

pub fn button(src: std.builtin.SourceLocation, label_str: []const u8) Button {
    return .{ .src = src, .label_str = label_str };
}

pub const Button = struct {
    src: std.builtin.SourceLocation,
    label_str: []const u8,
    v: tokens.Variant = .ghost,
    s: tokens.Size = .sm,

    pub fn variant(self: Button, v: tokens.Variant) Button {
        var b = self;
        b.v = v;
        return b;
    }

    pub fn size(self: Button, s: tokens.Size) Button {
        var b = self;
        b.s = s;
        return b;
    }

    pub fn draw(self: Button) bool {
        return dvui.button(self.src, self.label_str, .{}, tokens.buttonOpts(self.v, self.s));
    }
};
