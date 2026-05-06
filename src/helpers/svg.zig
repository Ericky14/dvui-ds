const dvui = @import("dvui");

/// Cache SVG→TVG conversion using dvui's persistent data store.
/// Returns a stable slice pointer suitable for renderIcon's texture cache.
pub fn cachedTvg(id: dvui.Id, key: []const u8, svg: []const u8) ?[]const u8 {
    if (dvui.dataGetSlice(null, id, key, []const u8)) |cached| return cached;
    const tvg_bytes = dvui.svgToTvg(dvui.currentWindow().arena(), svg) catch return null;
    dvui.dataSetSlice(null, id, key, tvg_bytes);
    return tvg_bytes;
}
