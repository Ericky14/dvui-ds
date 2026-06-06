const ds = @import("dvui_ds");

var active: usize = 0;
var settings_active: usize = 1;

const main_labels = [_][]const u8{ "Design", "Code", "Preview", "Export" };
const settings_labels = [_][]const u8{ "General", "Appearance", "Advanced" };

pub fn draw() void {
    const theme = ds.tokens.current;

    ds.label(@src(), "Tabs").style(.title).draw();
    ds.gap(@src(), theme.space_md);

    ds.label(@src(), "Animated indicator").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);

    _ = ds.tabs(@src(), &active, &main_labels).draw();
    ds.gap(@src(), theme.space_sm);

    ds.label(@src(), labelFor(active)).style(.muted).draw();
    ds.gap(@src(), theme.space_sm);

    {
        var panel = ds.card(@src()).variant(.filled).expand(.horizontal).draw();
        defer panel.deinit();

        switch (active) {
            0 => {
                ds.label(@src(), "Design").style(.secondary).font(.heading).draw();
                ds.gap(@src(), theme.space_xs);
                ds.label(@src(), "Lay out the canvas and tweak the visual treatment.").style(.muted).draw();
            },
            1 => {
                ds.label(@src(), "Code").style(.secondary).font(.heading).draw();
                ds.gap(@src(), theme.space_xs);
                ds.label(@src(), "Edit the source behind the component.").style(.muted).draw();
            },
            2 => {
                ds.label(@src(), "Preview").style(.secondary).font(.heading).draw();
                ds.gap(@src(), theme.space_xs);
                ds.label(@src(), "See the live, interactive result.").style(.muted).draw();
            },
            else => {
                ds.label(@src(), "Export").style(.secondary).font(.heading).draw();
                ds.gap(@src(), theme.space_xs);
                ds.label(@src(), "Ship the component to your project.").style(.muted).draw();
            },
        }
    }

    ds.gap(@src(), theme.space_xl);

    ds.label(@src(), "Second group").style(.secondary).font(.heading).draw();
    ds.gap(@src(), theme.space_sm);

    _ = ds.tabs(@src(), &settings_active, &settings_labels).idExtra(1).draw();
}

/// Caption describing the active index for the showcase.
fn labelFor(index: usize) []const u8 {
    return switch (index) {
        0 => "Active tab: 0 (Design)",
        1 => "Active tab: 1 (Code)",
        2 => "Active tab: 2 (Preview)",
        else => "Active tab: 3 (Export)",
    };
}
