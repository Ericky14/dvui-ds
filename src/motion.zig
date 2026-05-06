/// Design System — Motion tokens.
///
/// Duration tokens, easing curves, and named spring presets for consistent
/// animation across all DS widgets.
const std = @import("std");

// ─── Duration Tokens (microseconds for dvui.Animation) ─────────────────────

/// 0 ms — instantaneous state change.
pub const instant: i32 = 0;
/// 100 ms — fast micro-interactions (button hover, focus ring).
pub const fast: i32 = 100_000;
/// 200 ms — standard transitions (color changes, opacity).
pub const normal: i32 = 200_000;
/// 300 ms — deliberate transitions (panels, modals).
pub const slow: i32 = 300_000;
/// 500 ms — slow / dramatic transitions (page-level).
pub const slower: i32 = 500_000;

// ─── Easing Curves ──────────────────────────────────────────────────────────
//
// Design System easing curves mapped to dvui EasingFn signatures.
// DS reference: cubic-bezier approximations implemented as polynomial easings.

pub const EasingFn = *const fn (f32) f32;

/// DS `default`: cubic-bezier(0.22, 1, 0.36, 1) — fast attack, gentle settle.
/// Approximated with outQuint which has a similar fast-out shape.
pub fn default(t: f32) f32 {
    return cubicBezierApprox(t, 0.22, 1.0, 0.36, 1.0);
}

/// DS `in`: cubic-bezier(0.55, 0, 1, 0.45) — accelerate in.
pub fn in_(t: f32) f32 {
    return cubicBezierApprox(t, 0.55, 0.0, 1.0, 0.45);
}

/// DS `out`: cubic-bezier(0, 0.55, 0.45, 1) — decelerate out.
pub fn out(t: f32) f32 {
    return cubicBezierApprox(t, 0.0, 0.55, 0.45, 1.0);
}

/// DS `inOut`: cubic-bezier(0.65, 0, 0.35, 1) — symmetric ease.
pub fn inOut(t: f32) f32 {
    return cubicBezierApprox(t, 0.65, 0.0, 0.35, 1.0);
}

/// DS `bounce`: cubic-bezier(0.34, 1.56, 0.64, 1) — overshoot spring.
pub fn bounce(t: f32) f32 {
    return cubicBezierApprox(t, 0.34, 1.56, 0.64, 1.0);
}

/// DS `linear`: identity.
pub fn linear(t: f32) f32 {
    return t;
}

// ─── Spring Presets ─────────────────────────────────────────────────────────

pub const Spring = struct {
    stiffness: f32,
    damping: f32,
    mass: f32 = 1.0,
};

/// Window open/close/resize.
pub const spring_window = Spring{ .stiffness = 300, .damping = 28, .mass = 1.0 };
/// Dock icon bounce, tooltips.
pub const spring_dock = Spring{ .stiffness = 400, .damping = 22, .mass = 0.8 };
/// Command palette open/close.
pub const spring_launcher = Spring{ .stiffness = 500, .damping = 35, .mass = 1.0 };
/// Notification slide-in.
pub const spring_notification = Spring{ .stiffness = 200, .damping = 22, .mass = 1.0 };
/// Consent modal — deliberate, weighty.
pub const spring_consent = Spring{ .stiffness = 350, .damping = 28, .mass = 1.0 };
/// Popover/dropdown.
pub const spring_popover = Spring{ .stiffness = 400, .damping = 28, .mass = 0.8 };
/// Tooltip — snappy.
pub const spring_tooltip = Spring{ .stiffness = 600, .damping = 30, .mass = 1.0 };
/// Widget appear/reorder.
pub const spring_widget = Spring{ .stiffness = 200, .damping = 25, .mass = 1.0 };
/// Morning briefing card.
pub const spring_briefing = Spring{ .stiffness = 280, .damping = 26, .mass = 1.0 };
/// Ghost step animation.
pub const spring_ghost_step = Spring{ .stiffness = 250, .damping = 24, .mass = 1.0 };

// ─── Cubic Bezier Approximation ─────────────────────────────────────────────
//
// Attempt to evaluate a cubic-bezier(x1,y1,x2,y2) easing at parameter `t`
// using Newton-Raphson to solve for the bezier t from the x(t) curve,
// then return y(t). This is how CSS cubic-bezier works.

fn cubicBezierApprox(t: f32, x1: f32, y1: f32, x2: f32, y2: f32) f32 {
    if (t <= 0) return 0;
    if (t >= 1) return 1;

    // Find the bezier parameter `u` such that x(u) = t
    // x(u) = 3*(1-u)^2*u*x1 + 3*(1-u)*u^2*x2 + u^3
    var u: f32 = t; // initial guess
    for (0..8) |_| {
        const x = bezierComponent(u, x1, x2) - t;
        const dx = bezierComponentDeriv(u, x1, x2);
        if (@abs(dx) < 1e-6) break;
        u -= x / dx;
        u = std.math.clamp(u, 0.0, 1.0);
    }

    return bezierComponent(u, y1, y2);
}

fn bezierComponent(u: f32, p1: f32, p2: f32) f32 {
    // B(u) = 3(1-u)^2 * u * p1 + 3(1-u) * u^2 * p2 + u^3
    const inv = 1.0 - u;
    return 3.0 * inv * inv * u * p1 + 3.0 * inv * u * u * p2 + u * u * u;
}

fn bezierComponentDeriv(u: f32, p1: f32, p2: f32) f32 {
    // B'(u) = 3(1-u)^2*p1 + 6(1-u)*u*(p2-p1) + 3*u^2*(1-p2)
    const inv = 1.0 - u;
    return 3.0 * inv * inv * p1 + 6.0 * inv * u * (p2 - p1) + 3.0 * u * u * (1.0 - p2);
}
