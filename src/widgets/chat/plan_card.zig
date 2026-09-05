/// PlanCard — the agent's plan (plan mode) awaiting a verdict. Returns the choice
/// on the frame a button is clicked, `.none` otherwise. CONTRACT:
///   - Container: `surface_1` fill, `border` border, corners round(radius_md), a 2px
///     accent bar on the left edge (inset by the corner radius so it follows the
///     rounded outline).
///   - "PLAN" eyebrow (mono, muted, letter-spaced — each glyph is its own label with
///     a space_3xs gap, dvui having no tracking) then the title (heading font), then
///     the body rendered through `markdown()`.
///   - Buttons: "Approve" (filled), "Edit" (outlined), "Reject" (danger ghost), sm.
///
/// Usage:
///   switch (ds.chat.planCard(@src(), "Add a bouncing ball", plan_markdown).draw()) {
///       .approve => run(), .edit => edit(), .reject => discard(), .none => {},
///   }
///   _ = ds.chat.planCard(@src(), title, body).idExtra(index).draw();
const std = @import("std");
const dvui = @import("dvui");
const ds = @import("../../ds.zig");
const tokens = @import("../../tokens.zig");
const markdown_mod = @import("markdown.zig");

/// The user's verdict on a plan.
pub const PlanChoice = enum { none, approve, edit, reject };

/// The eyebrow text above the title.
const eyebrow_text = "PLAN";
/// Width of the accent rail on the left edge.
const accent_bar_width: f32 = 2;

pub fn planCard(src: std.builtin.SourceLocation, title: []const u8, body_markdown: []const u8) PlanCard {
    return .{ .src = src, .title = title, .body_markdown = body_markdown };
}

pub const PlanCard = struct {
    src: std.builtin.SourceLocation,
    title: []const u8,
    body_markdown: []const u8,
    expand_val: dvui.Options.Expand = .horizontal,
    height_val: ?f32 = null,
    id_extra: usize = 0,

    /// How the card fills its parent. The default is `.horizontal`: a chat card
    /// is as wide as the transcript and as tall as its content.
    ///
    /// A pane that scrolls its own transcript wants `.both` so the card takes
    /// the height it is given rather than the height it asked for — otherwise
    /// the card reports one height, the pane hands it another, and the two
    /// disagree by however much the content wanted.
    pub fn expand(self: PlanCard, val: dvui.Options.Expand) PlanCard {
        var copy = self;
        copy.expand_val = val;
        return copy;
    }

    /// Pin the card's height (logical px), snapped to whole physical pixels.
    /// The door for a pane that has already decided how tall each row is.
    pub fn height(self: PlanCard, logical_px: f32) PlanCard {
        var copy = self;
        copy.height_val = logical_px;
        return copy;
    }

    /// Disambiguate identity when used in a loop / list.
    pub fn idExtra(self: PlanCard, val: usize) PlanCard {
        var copy = self;
        copy.id_extra = val;
        return copy;
    }

    /// Draw the widget.
    pub fn draw(self: PlanCard) PlanChoice {
        const theme = tokens.current;
        var choice: PlanChoice = .none;

        var card = dvui.box(self.src, .{ .dir = .vertical, .gap = theme.space_2xs }, containerOpts(theme, self.id_extra).override(sizing(self.expand_val, self.height_val)));
        defer card.deinit();
        drawAccentBar(card.data(), theme);

        // Each text block rounds its own height, so the action row below them
        // starts on a whole physical pixel instead of inheriting the sum of
        // three fractional line boxes. See `ds.snapHeightOpts`.
        {
            var eyebrow = ds.snapHeightBox(@src(), 0);
            defer eyebrow.deinit();
            drawEyebrow(theme);
        }
        {
            var title = ds.snapHeightBox(@src(), 0);
            defer title.deinit();
            dvui.labelNoFmt(@src(), self.title, .{}, titleOpts(theme));
        }
        markdown_mod.markdown(@src(), self.body_markdown).draw();

        {
            var actions = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_sm }, actionsOpts(theme));
            defer actions.deinit();
            if (ds.button(@src(), "Approve").variant(.filled).size(.sm).draw()) choice = .approve;
            if (ds.button(@src(), "Edit").variant(.outlined).size(.sm).draw()) choice = .edit;
            // Danger ghost: the danger variant's text + hover wash on a transparent rest.
            if (ds.button(@src(), "Reject").variant(.danger).size(.sm).fillColor(.transparent).draw()) choice = .reject;
        }

        return choice;
    }
};

/// `surface_1` container with the default `border`; the left padding leaves room
/// for the accent rail.
fn containerOpts(theme: tokens.Theme, id_extra: usize) dvui.Options {
    return .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = .{ .color = theme.surface_1 },
        .color_border = .{ .color = theme.border },
        .border = ds.border(theme.border_width),
        .corners = dvui.CornerRect.round(theme.radius_md),
        .padding = ds.paddingEach(theme.space_sm, theme.space_sm, theme.space_sm, theme.space_md),
    };
}

/// A 2px accent rail just inside the left border, shortened by the corner radius
/// at both ends so it sits within the rounded outline.
fn drawAccentBar(data: *const dvui.WidgetData, theme: tokens.Theme) void {
    if (!data.visible()) return;
    const rect_scale = data.borderRectScale();
    const scale = rect_scale.s;
    const inset_y = theme.radius_md * scale;
    const height = rect_scale.r.h - 2 * inset_y;
    if (height <= 0) return;
    const bar: dvui.Rect.Physical = .{
        .x = @round(rect_scale.r.x + ds.borderPx(theme.border_width, scale) * scale),
        .y = rect_scale.r.y + inset_y,
        .w = accent_bar_width * scale,
        .h = height,
    };
    bar.fill(dvui.CornerRect.Physical.round(accent_bar_width * 0.5 * scale), .{ .color = .{ .color = theme.accent }, .fade = 1.0 });
}

/// "PLAN" in mono muted caption, letter-spaced by drawing each glyph as its own
/// label separated by a space_3xs gap.
fn drawEyebrow(theme: tokens.Theme) void {
    var row = dvui.box(@src(), .{ .dir = .horizontal, .gap = theme.space_2xs }, .{});
    defer row.deinit();
    for (0..eyebrow_text.len) |index| {
        dvui.labelNoFmt(@src(), eyebrow_text[index .. index + 1], .{}, eyebrowGlyphOpts(theme, index));
    }
}

fn eyebrowGlyphOpts(theme: tokens.Theme, index: usize) dvui.Options {
    return .{
        .id_extra = index,
        .color_text = .{ .color = theme.text_muted },
        .font = monoFont(theme.font_size_sm).withWeight(.medium),
        .padding = ds.paddingXY(0, theme.space_3xs),
    };
}

fn titleOpts(theme: tokens.Theme) dvui.Options {
    return .{
        .color_text = .{ .color = theme.text_primary },
        .font = dvui.Font.theme(.heading),
    };
}

/// The button row sits a little apart from the body above it.
fn actionsOpts(theme: tokens.Theme) dvui.Options {
    return .{ .margin = ds.paddingEach(theme.space_2xs, 0, 0, 0) };
}

/// The theme's mono font at a pixel size (the DS maps `.mono` onto its font family
/// until a mono face is embedded).
fn monoFont(size_px: u16) dvui.Font {
    return dvui.Font.theme(.mono).withSize(@floatFromInt(size_px));
}

test {
    _ = @import("plan_card_tests.zig");
}

/// The caller's `expand` / `height` as options, snapped.
fn sizing(expand_val: dvui.Options.Expand, height_val: ?f32) dvui.Options {
    if (height_val) |px| {
        const snapped = ds.snapPx(px, ds.pixelScale());
        return .{
            .expand = expand_val,
            .min_size_content = .{ .w = 0, .h = snapped },
            .max_size_content = .height(snapped),
        };
    }
    return .{ .expand = expand_val };
}
