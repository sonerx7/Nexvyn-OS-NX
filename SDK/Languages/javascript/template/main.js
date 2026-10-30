// My App: a minimal Nexvyn OS app in JavaScript (SDK.md section 11).
// main.js is an ES module. Put the callbacks on the global `app` object; every callback is optional.
// Differences from Lua: indexes start at 0, `null` instead of nil, async SDK calls return Promises.

let taps = 0;

function bump(n) {
  taps = n;
  store.set("taps", taps);       // store keeps small values between runs (the app's own data folder)
}

// Once, when the window opens. arg = the file / link the app was opened with, or "".
app.load = (arg) => {
  taps = store.get("taps", 0);
};

// Every frame: draw everything and handle widgets. w, h = content size in pixels.
app.draw = (w, h) => {
  gfx.clear(theme.bg);
  gfx.color(theme.text);
  gfx.text(TR("hello"), 0, h / 2 - 70, 28, "bold", "center", w);
  gfx.color(theme.text2);
  gfx.text(TR("edit_me"), 40, h / 2 - 24, 14, "sans", "center", w - 80);
  if (ui.button(TR("tap", taps), w / 2 - 90, h / 2 + 20, 180, 40, "primary")) {
    bump(taps + 1);
    audio.play("pop");
  }
};

// Raw input (SDK.md section 5).
app.event = (e) => {
  if (e.type === "keydown" && e.key === "space") bump(taps + 1);
};

// Menu bar: a list of menus, each with items {label, id}; "-" is a separator.
app.menu = () => [{ title: TR("app"), items: [{ label: TR("reset"), id: 1 }] }];

app.onmenu = (id) => {
  if (id === 1) bump(0);
};
