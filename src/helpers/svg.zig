const dvui = @import("dvui");

/// Cache SVG→TVG conversion using dvui's persistent data store.
/// Returns a stable slice pointer suitable for renderIcon's texture cache.
pub fn cachedTvg(id: dvui.Id, key: []const u8, svg: []const u8) ?[]const u8 {
    if (dvui.dataGetSlice(null, id, key, []const u8)) |cached| return cached;
    const cw = dvui.currentWindow();
    const tvg_bytes = dvui.svgToTvg(cw.arena(), svg) catch return null;
    defer cw.arena().free(tvg_bytes);
    dvui.dataSetSlice(null, id, key, tvg_bytes);
    // Return the persisted copy, not the arena scratch (freed at frame end), so
    // the slice stays valid across frames.
    return dvui.dataGetSlice(null, id, key, []const u8);
}
