//! **Files dragged onto the window**, collected frame by frame.
//!
//! SDL delivers a drop as a little conversation rather than as one event:
//! `SDL_EVENT_DROP_BEGIN`, then a `SDL_EVENT_DROP_POSITION` every time the
//! pointer moves while the drag hovers, then one `SDL_EVENT_DROP_FILE` per
//! file, then `SDL_EVENT_DROP_COMPLETE`. dvui has no event for any of it — a
//! drag is not a mouse gesture the UI can capture — so the backend collects
//! the conversation here and an app asks, once per frame, *what is hovering
//! and what was dropped*.
//!
//! This file is **pure**: fixed storage, no allocator, no SDL and no dvui. The
//! backend feeds it (`begin` / `position` / `file` / `complete`) and the app
//! reads `state()`; that split is what lets the whole thing be unit-tested
//! without a window, and what lets a host replay a synthetic drop in a headless
//! test (which is exactly what zigame's Phase 9 gate does).
//!
//! Two rules the shape encodes:
//!
//!  1. **A path is copied, never borrowed.** SDL owns the string in a
//!     `SDL_DropEvent` and frees it when the event is done, so a slice kept
//!     past the poll loop is a use-after-free. Paths are copied into one fixed
//!     byte buffer.
//!  2. **The list survives exactly one frame.** `complete` closes the set;
//!     the next `beginFrame` clears it. So an app that reads `state()` once a
//!     frame sees each drop exactly once, and one that forgets to read loses
//!     it rather than replaying it forever.
const std = @import("std");

/// Files one drop may carry. A person dropping more than this at once is
/// dropping a folder's worth; the rest are counted in `overflow` and the host
/// can say so.
pub const max_files: usize = 32;
/// Bytes for all the paths of one drop together (a Windows path is at most
/// 260 bytes; a Linux one 4096, but 32 of those is not a drop a person makes).
pub const max_bytes: usize = 8 * 1024;

/// What is hovering and what was dropped, as of this frame.
pub const State = struct {
    /// A drag is over the window: between `DROP_BEGIN` and `DROP_COMPLETE`.
    /// The app draws its target while this is true.
    hovering: bool = false,
    /// Where the pointer is, in the same units the positions were fed in
    /// (the backend feeds PHYSICAL pixels). Meaningless while `hovering` is
    /// false; it keeps the last value rather than resetting, so the drop's
    /// own point is still readable on the frame it completes.
    x: f32 = 0,
    y: f32 = 0,
    /// True on the frame the drop completed. `files` is the whole set.
    completed: bool = false,
    /// The dropped paths, valid until the next `beginFrame`.
    files: []const []const u8 = &.{},
    /// Files that did not fit (`max_files` or `max_bytes`).
    overflow: usize = 0,
};

/// The collector itself: a field of the backend, cleared once per frame.
pub const Collector = struct {
    bytes: [max_bytes]u8 = @splat(0),
    used: usize = 0,
    spans: [max_files]Span = @splat(.{ .start = 0, .len = 0 }),
    count: usize = 0,
    overflow: usize = 0,
    hovering: bool = false,
    completed: bool = false,
    x: f32 = 0,
    y: f32 = 0,

    const Span = struct { start: usize, len: usize };

    /// Start of a frame's event pump: forget the previous frame's completed
    /// drop, keep a drag that is still hovering.
    pub fn beginFrame(self: *Collector) void {
        if (!self.completed) return;
        self.completed = false;
        self.clearFiles();
    }

    /// `SDL_EVENT_DROP_BEGIN`: a new set of files is arriving.
    pub fn begin(self: *Collector) void {
        self.hovering = true;
        self.completed = false;
        self.clearFiles();
    }

    /// `SDL_EVENT_DROP_POSITION`: the pointer moved while hovering. Also
    /// turns hovering on, because a compositor may send a position before the
    /// begin (and a target that only lights up on `begin` then never lights
    /// up at all).
    pub fn position(self: *Collector, x: f32, y: f32) void {
        self.hovering = true;
        self.x = x;
        self.y = y;
    }

    /// `SDL_EVENT_DROP_FILE`: one path, copied in. A path that does not fit
    /// is counted in `overflow` and dropped, so a huge drop degrades to "some
    /// of these did not fit" rather than to a truncated path that names the
    /// wrong file.
    pub fn file(self: *Collector, path: []const u8) void {
        if (path.len == 0) return;
        if (self.count == max_files or self.used + path.len > max_bytes) {
            self.overflow += 1;
            return;
        }
        @memcpy(self.bytes[self.used..][0..path.len], path);
        self.spans[self.count] = .{ .start = self.used, .len = path.len };
        self.used += path.len;
        self.count += 1;
    }

    /// `SDL_EVENT_DROP_COMPLETE`: the set is closed. The hover ends here —
    /// the pointer's last position is kept, because it is where the drop
    /// landed.
    pub fn complete(self: *Collector) void {
        self.hovering = false;
        self.completed = true;
    }

    /// A drag that left the window without dropping anything (or a
    /// cancellation): forget both the hover and the half-built set.
    pub fn cancel(self: *Collector) void {
        self.hovering = false;
        self.completed = false;
        self.clearFiles();
    }

    /// This frame's answer. `files` points into the collector, so it is valid
    /// until the next `beginFrame`.
    pub fn state(self: *const Collector, out: *[max_files][]const u8) State {
        for (self.spans[0..self.count], 0..) |span, index| {
            out[index] = self.bytes[span.start..][0..span.len];
        }
        return .{
            .hovering = self.hovering,
            .x = self.x,
            .y = self.y,
            .completed = self.completed,
            .files = out[0..self.count],
            .overflow = self.overflow,
        };
    }

    fn clearFiles(self: *Collector) void {
        self.used = 0;
        self.count = 0;
        self.overflow = 0;
    }
};

test {
    _ = @import("drop_tests.zig");
}
