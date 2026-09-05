/// Dropdown (Select) — themed wrap of `dvui.dropdown`.
///
/// A closed control showing the current selection (or a placeholder), that opens
/// a floating menu of choices on click. Selection is driven by a `*usize` index
/// into the `entries` slice. The closed control and the open menu share the same
/// themed options, so both surfaces match the Cosmic Teal tokens.
///
/// Usage:
///   var fruit: usize = 0;
///   if (ds.dropdown(@src(), &fruit, &.{ "Apple", "Banana", "Cherry" }).draw()) { ... }
///   _ = ds.dropdown(@src(), &size_idx, &.{ "Small", "Medium", "Large" }).size(.lg).draw();
///   _ = ds.dropdown(@src(), &locked_idx, entries).disabled(true).draw();
///   // In a loop/group, disambiguate with idExtra:
///   _ = ds.dropdown(@src(), &sel, entries).idExtra(index).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../ds.zig");
const tokens = @import("../tokens.zig");

pub fn dropdown(src: std.builtin.SourceLocation, selected: *usize, entries: []const []const u8) Dropdown {
    return .{ .src = src, .selected = selected, .entries = entries };
}

pub const Dropdown = struct {
    src: std.builtin.SourceLocation,
    selected: *usize,
    entries: []const []const u8,
    dropdown_size: tokens.Size = .md,
    placeholder_text: []const u8 = "Select ...",
    is_disabled: bool = false,
    id_extra: ?usize = null,

    /// Set the control size (sm / md / lg).
    pub fn size(self: Dropdown, val: tokens.Size) Dropdown {
        var copy = self;
        copy.dropdown_size = val;
        return copy;
    }

    /// Set the text shown when there are no entries (the empty-state label).
    pub fn placeholder(self: Dropdown, text: []const u8) Dropdown {
        var copy = self;
        copy.placeholder_text = text;
        return copy;
    }

    /// Disable interaction and dim the control.
    pub fn disabled(self: Dropdown, val: bool) Dropdown {
        var copy = self;
        copy.is_disabled = val;
        return copy;
    }

    /// Disambiguate this instance when used in a loop / group (passed as
    /// `.id_extra` on the root widget).
    pub fn idExtra(self: Dropdown, val: usize) Dropdown {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the dropdown. Returns true if a selection was made this frame
    /// (even re-selecting the current choice).
    pub fn draw(self: Dropdown) bool {
        const theme = tokens.current;

        var opacity: ?ds.Opacity = null;
        if (self.is_disabled) opacity = ds.withOpacity(theme.opacity_disabled);
        defer if (opacity) |o| o.restore();

        // No entries: render an inert placeholder field (never index an empty
        // slice) and report no change.
        if (self.entries.len == 0) {
            self.drawClosed(self.placeholder_text);
            return false;
        }

        // Keep the index in range — dvui.dropdown indexes entries[selected.*]
        // directly, which would panic if a stale index outran a shrunk slice.
        if (self.selected.* >= self.entries.len) self.selected.* = self.entries.len - 1;

        // Disabled: render the closed control (dimmed by the opacity wrapper) but
        // don't let dvui handle events / open the menu.
        if (self.is_disabled) {
            self.drawClosed(self.entries[self.selected.*]);
            return false;
        }

        return dvui.dropdown(
            self.src,
            self.entries,
            .{ .choice = self.selected },
            .{},
            self.opts(),
        );
    }

    /// Render a non-interactive closed-look field (disabled / empty states,
    /// where `dvui.dropdown` must not process events).
    fn drawClosed(self: Dropdown, text: []const u8) void {
        const theme = tokens.current;
        var box = dvui.box(self.src, .{ .dir = .horizontal }, self.opts().override(.{ .background = true }));
        defer box.deinit();
        dvui.labelNoFmt(@src(), text, .{}, .{
            .color_text = .{ .color = theme.text_primary },
            .font = ds.font(fontSize(self.dropdown_size)),
            .gravity_y = 0.5,
        });
    }

    /// Themed options shared by the closed control and the open menu items.
    fn opts(self: Dropdown) dvui.Options {
        const theme = tokens.current;
        const font_size = fontSize(self.dropdown_size);
        return .{
            .color_fill = .{ .color = theme.surface_2 },
            .color_border = .{ .color = theme.border_input },
            .border = ds.border(theme.border_width),
            .corners = dvui.CornerRect.round(theme.radius_md),
            .color_text = .{ .color = theme.text_primary },
            .padding = ds.paddingXY(theme.space_md, theme.space_sm),
            .font = ds.font(font_size),
            .min_size_content = .{ .w = 160 },
            .id_extra = self.id_extra,
        };
    }
};

fn fontSize(sz: tokens.Size) u16 {
    const theme = tokens.current;
    return switch (sz) {
        .sm => theme.font_size_sm,
        .md => theme.font_size_md,
        .lg => theme.font_size_lg,
    };
}

test {
    _ = @import("dropdown_tests.zig");
}
