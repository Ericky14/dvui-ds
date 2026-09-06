const std = @import("std");
const dvui = @import("dvui");
const ds = @import("dvui_ds");

var name_buf: [128]u8 = @splat(0);
var email_buf: [128]u8 = @splat(0);
var folder_buf: [128]u8 = @splat(0);
/// What the last Enter in the folder field submitted, so the page shows that a
/// field REPORTS rather than only draws.
var submitted: [128]u8 = @splat(0);
var submitted_len: usize = 0;

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Text Input").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    // Single ds.textInput
    ds.label(@src(), "DS textInput").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    _ = ds.textInput(@src(), &name_buf).placeholder("DS themed input").draw();

    ds.gap(@src(), theme.space_lg);

    // With label + helper
    ds.label(@src(), "With label + helper").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    _ = ds.textInput(@src(), &email_buf).label("Email").placeholder("you@example.com").helper("We'll never share your email.").draw();

    ds.gap(@src(), theme.space_lg);

    // The three sizes side by side, with the placeholder that found the bug:
    // a path is all ascenders and descenders, so a line box one pixel short
    // shows immediately.
    ds.label(@src(), "Sizes (sm / md / lg)").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    inline for (.{ ds.Size.sm, ds.Size.md, ds.Size.lg }, 0..) |size, index| {
        var buffer: [1]u8 = @splat(0);
        _ = ds.textInput(@src(), &buffer)
            .size(size)
            .idExtra(index)
            .placeholder("C:\\games\\MyGame")
            .draw();
        ds.gap(@src(), theme.space_xs);
    }

    ds.gap(@src(), theme.space_lg);

    // `draw()` REPORTS: Enter in the field below submits it, with no
    // hand-rolled `dvui.TextEntryWidget` beside it.
    ds.label(@src(), "Enter submits").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    const field = ds.textInput(@src(), &folder_buf).placeholder("Type and press Enter").draw();
    if (field.enter_pressed) {
        const typed = std.mem.sliceTo(&folder_buf, 0);
        submitted_len = @min(typed.len, submitted.len);
        @memcpy(submitted[0..submitted_len], typed[0..submitted_len]);
    }
    ds.gap(@src(), theme.space_xs);
    if (submitted_len > 0) {
        ds.label(@src(), submitted[0..submitted_len]).style(.muted).draw();
    } else {
        ds.label(@src(), "nothing submitted yet").style(.weak).draw();
    }
}
