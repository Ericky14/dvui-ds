//! The geometric rules, run over the widgets one design-system fixture draws.
//!
//! These are the same rules — and the same tolerances — that the engine's
//! `zigame ui lint` runs over a whole editor pane
//! (`D:\Dev\zigame\src\editor\ui_lint.zig`). They live here too because the
//! engine can only see the design system through a pinned commit: a finding it
//! reports against `src/widgets/plan_card.zig:63` has to be *provable and
//! fixable* in this repo, before any pin moves, or the fix is a guess.
//!
//! Only the four rules that ds widgets can actually be responsible for are
//! implemented. Containment, overlap and elision are the composing app's
//! business — a widget cannot know how small a pane it will be put in.
//!
//!   snapped    at a fractional scale, everything that draws a visible edge
//!              lands within 0.01 of a whole physical pixel. Half a pixel off
//!              is a grey line where a black one was meant, and that is most of
//!              what "blurry at 175 %" means.
//!   grid       the gap between two siblings of a row or column is a multiple
//!              of 4 logical px (±0.5). 1 px dividers are exempt — a line is
//!              not a box on the grid.
//!   row_centre a child of a horizontal row that does not fill it shares the
//!              row's vertical centre line within 0.5 px.
//!   hit_target anything clickable is at least 24 logical px on both axes.
const std = @import("std");
const dvui = @import("dvui");

pub const tolerance: f32 = 0.5;
pub const snap_tolerance: f32 = 0.01;
pub const grid_step: f32 = 4;
pub const min_hit_target: f32 = 24;
pub const divider_thickness: f32 = 1.5;

pub const Rule = enum { snapped, grid, row_centre, hit_target };

const nl = "\n";

pub const Counts = struct {
    snapped: usize = 0,
    grid: usize = 0,
    row_centre: usize = 0,
    hit_target: usize = 0,

    pub fn total(self: Counts) usize {
        return self.snapped + self.grid + self.row_centre + self.hit_target;
    }
};

const Node = struct {
    name: []const u8,
    src_file: []const u8,
    src_line: u32,
    background: bool,
    /// Logical (scale-divided) border and content rects.
    border: dvui.Rect,
    content: dvui.Rect,
    physical: dvui.Rect.Physical,
    parent: ?usize,
    children: usize = 0,
};

fn toLogical(rect: dvui.Rect.Physical, scale: f32) dvui.Rect {
    return .{ .x = rect.x / scale, .y = rect.y / scale, .w = rect.w / scale, .h = rect.h / scale };
}

const clickable_words = [_][]const u8{ "button", "checkbox", "chip", "toggle", "switch", "radio", "tab" };

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0 or haystack.len < needle.len) return false;
    var start: usize = 0;
    while (start + needle.len <= haystack.len) : (start += 1) {
        var same = true;
        for (needle, 0..) |wanted, offset| {
            if (std.ascii.toLower(haystack[start + offset]) != std.ascii.toLower(wanted)) {
                same = false;
                break;
            }
        }
        if (same) return true;
    }
    return false;
}

fn isClickable(node: Node) bool {
    if (std.mem.eql(u8, node.name, "Button")) return true;
    if (std.mem.eql(u8, node.name, "TextEntry")) return true;
    for (clickable_words) |word| {
        if (containsIgnoreCase(node.name, word)) return true;
    }
    return false;
}

fn drawsAnEdge(node: Node) bool {
    if (node.background) return true;
    if (node.border.w <= divider_thickness or node.border.h <= divider_thickness) return true;
    return node.children == 0 and node.name.len == 0;
}

const Orientation = enum { empty, single, horizontal, vertical, stacked };

fn orientationOf(nodes: []const Node, children: []const usize) Orientation {
    if (children.len == 0) return .empty;
    if (children.len == 1) return .single;
    var horizontal = true;
    var vertical = true;
    var advance_x: f32 = 0;
    var advance_y: f32 = 0;
    var index: usize = 1;
    while (index < children.len) : (index += 1) {
        const previous = nodes[children[index - 1]].border;
        const current = nodes[children[index]].border;
        const shared_x = @min(previous.x + previous.w, current.x + current.w) - @max(previous.x, current.x);
        const shared_y = @min(previous.y + previous.h, current.y + current.h) - @max(previous.y, current.y);
        if (current.x <= previous.x + tolerance) horizontal = false;
        if (shared_y <= 0) horizontal = false;
        if (shared_x > 0.5 * @min(previous.w, current.w)) horizontal = false;
        if (current.y <= previous.y + tolerance) vertical = false;
        if (shared_x <= 0) vertical = false;
        if (shared_y > 0.5 * @min(previous.h, current.h)) vertical = false;
        advance_x += current.x - previous.x;
        advance_y += current.y - previous.y;
    }
    if (horizontal and vertical) return if (advance_x >= advance_y) .horizontal else .vertical;
    if (horizontal) return .horizontal;
    if (vertical) return .vertical;
    return .stacked;
}

/// Run the rules over the frame dvui has just built. Arm the capture with
/// `dvui.debug.captureFrame()` before that frame, and call this after it — the
/// capture is retained until the next one.
///
/// `only_file`, when given, limits the report to widgets registered from that
/// source file, so a fixture can hold a page's worth of scaffolding and still
/// assert about exactly one widget.
pub fn run(allocator: std.mem.Allocator, scale: f32, only_file: ?[]const u8, print: bool) !Counts {
    const captured = dvui.debug.lastCapture() orelse return error.NoCapture;
    const raw = captured.widgets.items;

    var nodes = try allocator.alloc(Node, raw.len);
    defer allocator.free(nodes);

    var positions: std.AutoHashMapUnmanaged(u64, usize) = .empty;
    defer positions.deinit(allocator);
    try positions.ensureTotalCapacity(allocator, @intCast(raw.len + 1));
    for (raw, 0..) |node, index| {
        const key = node.id.asU64();
        if (!positions.contains(key)) positions.putAssumeCapacity(key, index);
    }

    for (raw, 0..) |node, index| {
        const id = node.id.asU64();
        const parent_id = node.parent_id.asU64();
        nodes[index] = .{
            .name = node.name orelse "",
            .src_file = std.fs.path.basename(node.src_file),
            .src_line = node.src_line,
            .background = node.background,
            .border = toLogical(node.rect_border, scale),
            .content = toLogical(node.rect_content, scale),
            .physical = node.rect_border,
            .parent = if (parent_id == id) null else positions.get(parent_id),
        };
    }
    for (nodes) |node| {
        if (node.parent) |slot| nodes[slot].children += 1;
    }

    // children of each node, in registration order
    var children_of = try allocator.alloc(std.ArrayListUnmanaged(usize), raw.len);
    defer {
        for (children_of) |*list| list.deinit(allocator);
        allocator.free(children_of);
    }
    for (children_of) |*list| list.* = .empty;
    for (nodes, 0..) |node, index| {
        if (node.parent) |slot| try children_of[slot].append(allocator, index);
    }

    var counts: Counts = .{};

    const mine = struct {
        fn check(node: Node, filter: ?[]const u8) bool {
            const want = filter orelse return true;
            return std.mem.eql(u8, node.src_file, want);
        }
    }.check;

    // ── snapped ──────────────────────────────────────────────────────────────
    if (scale > 1 + snap_tolerance) {
        for (nodes) |node| {
            if (!mine(node, only_file)) continue;
            if (!drawsAnEdge(node)) continue;
            if (node.physical.w <= 0 or node.physical.h <= 0) continue;
            const edges = [_]f32{
                node.physical.x,
                node.physical.y,
                node.physical.x + node.physical.w,
                node.physical.y + node.physical.h,
            };
            const edge_names = [_][]const u8{ "left", "top", "right", "bottom" };
            for (edges, edge_names) |edge, edge_name| {
                if (@abs(edge - @round(edge)) <= snap_tolerance) continue;
                counts.snapped += 1;
                if (print) std.debug.print(
                    "  snapped: {s}:{d} {s} {s} edge {d:.3} rect {d:.3},{d:.3} {d:.3}x{d:.3}" ++ nl,
                    .{ node.src_file, node.src_line, node.name, edge_name, edge, node.physical.x, node.physical.y, node.physical.w, node.physical.h },
                );
                break;
            }
        }
    }

    // ── hit_target ───────────────────────────────────────────────────────────
    for (nodes) |node| {
        if (!mine(node, only_file)) continue;
        if (!isClickable(node)) continue;
        if (node.border.w < min_hit_target - tolerance or node.border.h < min_hit_target - tolerance) {
            counts.hit_target += 1;
            if (print) std.debug.print(
                "  hit_target: {s}:{d} {s} is {d:.2} x {d:.2}\n",
                .{ node.src_file, node.src_line, node.name, node.border.w, node.border.h },
            );
        }
    }

    // ── grid + row_centre ────────────────────────────────────────────────────
    for (nodes, 0..) |_, index| {
        const children = children_of[index].items;
        if (children.len < 2) continue;
        const direction = orientationOf(nodes, children);
        if (direction != .horizontal and direction != .vertical) continue;

        var step: usize = 1;
        while (step < children.len) : (step += 1) {
            const previous = nodes[children[step - 1]];
            const current = nodes[children[step]];
            if (!mine(current, only_file)) continue;
            const gap = if (direction == .horizontal)
                current.border.x - (previous.border.x + previous.border.w)
            else
                current.border.y - (previous.border.y + previous.border.h);
            if (gap < 0) continue;
            const thin = if (direction == .horizontal)
                previous.border.w <= divider_thickness or current.border.w <= divider_thickness
            else
                previous.border.h <= divider_thickness or current.border.h <= divider_thickness;
            if (thin) continue;
            const nearest = @round(gap / grid_step) * grid_step;
            if (@abs(gap - nearest) <= tolerance) continue;
            counts.grid += 1;
            if (print) std.debug.print(
                "  grid: {s}:{d} {s} sits {d:.2} px after {s} (nearest {d:.0})\n",
                .{ current.src_file, current.src_line, current.name, gap, previous.name, nearest },
            );
        }

        if (direction != .horizontal) continue;
        const row = nodes[index];
        if (row.content.h <= 0) continue;
        const row_centre_y = row.content.y + row.content.h / 2;
        for (children) |child_index| {
            const child = nodes[child_index];
            if (!mine(child, only_file)) continue;
            // A child that fills the row has nothing to centre.
            if (child.border.h >= row.content.h - tolerance) continue;
            const child_centre = child.border.y + child.border.h / 2;
            const delta = @abs(child_centre - row_centre_y);
            if (delta <= tolerance) continue;
            counts.row_centre += 1;
            if (print) std.debug.print(
                "  row_centre: {s}:{d} {s} is {d:.2} px off the row centre\n",
                .{ child.src_file, child.src_line, child.name, delta },
            );
        }
    }

    return counts;
}
