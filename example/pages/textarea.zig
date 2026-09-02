const ds = @import("dvui_ds");

var notes_buf: [512]u8 = @splat(0);
var bio_buf: [512]u8 = @splat(0);
var fixed_buf: [512]u8 = @splat(0);

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Text Area").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    // Basic
    ds.label(@src(), "Basic").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    ds.textarea(@src(), &notes_buf).placeholder("Write your notes…").draw();

    ds.gap(@src(), theme.space_lg);

    // With label + helper, taller
    ds.label(@src(), "With label + helper (6 rows)").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    ds.textarea(@src(), &bio_buf).rows(6).label("Bio").helper("Tell us about yourself.").draw();

    ds.gap(@src(), theme.space_lg);

    // Fixed width — pinned, wraps inside, never grows as you type.
    ds.label(@src(), "Fixed width (320px)").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    ds.textarea(@src(), &fixed_buf).rows(3).width(320).placeholder("Pinned to 320px…").draw();
}
