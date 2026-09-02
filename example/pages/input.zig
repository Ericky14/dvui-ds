const ds = @import("dvui_ds");

var name_buf: [128]u8 = @splat(0);
var email_buf: [128]u8 = @splat(0);

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Text Input").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    // Single ds.textInput
    ds.label(@src(), "DS textInput").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    ds.textInput(@src(), &name_buf).placeholder("DS themed input").draw();

    ds.gap(@src(), theme.space_lg);

    // With label + helper
    ds.label(@src(), "With label + helper").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);
    ds.textInput(@src(), &email_buf).label("Email").placeholder("you@example.com").helper("We'll never share your email.").draw();
}
