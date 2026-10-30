// clock.nut: an analog clock drawn with gfx. import("clock") returns this table.
local M = {};

M.draw <- function(w, h) {
    local side = w < h - 60 ? w : h - 60;
    local cx = w / 2.0, cy = h / 2.0 + 24, r = side / 2.0 - 30;
    local d = sys.date();
    local t = sys.time();
    local sec = d.sec + (t - floor(t));  // smooth second hand
    gfx.shadow(cx - r, cy - r, r * 2, r * 2, r, 18, 6);
    gfx.circle(cx, cy, r, theme.window);
    gfx.color(theme.separator);
    gfx.circleLine(cx, cy, r, 2);
    for (local i = 0; i < 60; i++) {
        local a = i * PI / 30, inner = i % 5 == 0 ? r - 16 : r - 8;
        gfx.color(i % 5 == 0 ? theme.text : theme.text3);
        gfx.line(cx + cos(a) * inner, cy + sin(a) * inner, cx + cos(a) * (r - 4), cy + sin(a) * (r - 4), i % 5 == 0 ? 3 : 1);
    }
    local hand = function(angle, len, width, color) {
        local a = angle - PI / 2;
        gfx.color(color);
        gfx.line(cx, cy, cx + cos(a) * len, cy + sin(a) * len, width);
    };
    hand((d.hour % 12 + d.min / 60.0) * PI / 6, r * 0.5, 6, theme.text);
    hand((d.min + sec / 60.0) * PI / 30, r * 0.75, 4, theme.text);
    hand(sec * PI / 30, r * 0.85, 2, theme.red);
    gfx.circle(cx, cy, 6, theme.red);
    gfx.color(theme.text2);
    gfx.text(format("%02d:%02d:%02d", d.hour, d.min, d.sec), 0, cy + r + 12, 16, "mono", "center", w);
};

return M;
