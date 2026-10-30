// Merhaba JS / Hello JS: a small tour of the Nexvyn OS JavaScript SDK (sdk/SDK.md, section "JavaScript").
//  - To-do list saved with `store`          (todos.js, an ES module imported below)
//  - A clock drawn with `gfx`                (clock.js)
//  - Live JSON with `await net.fetchJson()`  (Open-Meteo current weather, no API key)
import { TodoList } from "./todos.js";
import { drawClock } from "./clock.js";

const WEATHER_URL =
  "https://api.open-meteo.com/v1/forecast?latitude=41.0082&longitude=28.9784" +
  "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&timezone=auto";

let tab = 0;
let todos = null;
let draft = "";
let toast = "";
let toastTimer = null;
const weather = { loading: false, data: null, raw: "", error: "" };

app.load = (arg) => {
  todos = new TodoList();
  tab = store.get("tab", 0);
  console.log("hellojs started", { arg, todos: todos.items.length });
};

function showToast(text) {
  toast = text;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (toast = ""), 1800);
}

function addDraft() {
  const text = draft.trim();
  if (!text) return;
  todos.add(text);
  draft = "";
  showToast(TR("added"));
}

async function fetchWeather() {
  if (weather.loading) return;
  weather.loading = true;
  weather.error = "";
  try {
    const data = await net.fetchJson(WEATHER_URL);  // rejects with an Error when offline / HTTP error / bad JSON
    weather.data = data.current || null;
    weather.raw = json.encode(data.current, true);
    console.log("weather", data.current);
  } catch (e) {
    weather.error = e.message;
  } finally {
    weather.loading = false;
  }
}

// ------------------------------------------------------------------ tabs
function drawTodos(w, h) {
  gfx.color(theme.text);
  gfx.text(TR("todo_title"), 24, 58, 20, "bold");
  gfx.color(theme.text2);
  gfx.text(TR("remaining", todos.remaining()), 0, 63, 13, "sans", "right", w - 24);

  draft = ui.textfield("draft", draft, 24, 94, w - 160, 32, TR("todo_hint"));
  if (ui.submitted("draft")) addDraft();
  if (ui.button(TR("add"), w - 128, 94, 104, 32, "primary", "add", draft.trim() !== "")) addDraft();

  const top = 138, bottom = h - 54, rowH = 40, listW = w - 48;
  ui.group(24, top, listW, bottom - top);
  if (todos.items.length === 0) {
    gfx.icon("checklist", w / 2, (top + bottom) / 2 - 14, 40, theme.text3);
    gfx.color(theme.text3);
    gfx.text(TR("empty"), 0, (top + bottom) / 2 + 14, 14, "sans", "center", w);
  } else {
    let action = null;  // change the list after the loop, not while drawing it
    ui.beginScroll("list", 24, top, listW, bottom - top, todos.items.length * rowH);
    todos.items.forEach((t, i) => {
      const y = i * rowH;
      if (ui.checkbox("##done" + t.id, t.done, 14, y + 11) !== t.done) action = () => todos.toggle(t.id);
      gfx.clip(44, y, listW - 100, rowH);
      gfx.color(t.done ? theme.text3 : theme.text);
      const tw = gfx.text(t.text, 44, y + 11, 14);
      if (t.done) gfx.line(44, y + 20, 44 + tw, y + 20, 1);
      gfx.unclip();
      if (ui.iconButton("delete", listW - 42, y + 6, 28, 28, theme.red, false, "del" + t.id)) {
        action = () => todos.remove(t.id);
      }
      if (i < todos.items.length - 1) ui.separator(14, y + rowH - 0.5, listW - 14);
    });
    ui.endScroll();
    if (action) action();
  }
  if (ui.button(TR("clear_done"), 24, h - 44, 190, 30, "default", "cleaning_services", todos.doneCount() > 0)) {
    showToast(TR("cleared", todos.clearDone()));
  }
}

function drawNetwork(w, h) {
  gfx.color(theme.text);
  gfx.text(TR("net_title"), 24, 58, 20, "bold");
  gfx.color(theme.text2);
  gfx.wrap(TR("net_body"), 24, 88, w - 48, 13);

  const online = sys.online();
  if (ui.button(TR("fetch"), 24, 130, 170, 34, "primary", "cloud_download", online && !weather.loading)) {
    fetchWeather();
  }
  if (weather.loading) ui.spinner(216, 147, 9);
  else if (!online) {
    gfx.color(theme.orange);
    gfx.text(TR("offline"), 208, 139, 14);
  } else if (weather.error) {
    gfx.color(theme.red);
    gfx.text(TR("failed", weather.error), 208, 139, 13);
  }

  const top = 180, boxH = h - top - 24;
  ui.group(24, top, w - 48, boxH);
  const c = weather.data;
  if (!c) {
    gfx.icon("thermostat", w / 2, top + boxH / 2 - 12, 40, theme.text3);
    gfx.color(theme.text3);
    gfx.text(TR("no_data"), 0, top + boxH / 2 + 16, 14, "sans", "center", w);
    return;
  }
  gfx.color(theme.accent);
  gfx.text(`${Math.round(c.temperature_2m)}°`, 44, top + 14, 56, "bold");
  gfx.color(theme.text);
  gfx.text(TR("city"), 44, top + 90, 15, "semibold");
  gfx.color(theme.text2);
  gfx.text(TR("humidity", c.relative_humidity_2m), 44, top + 116, 13);
  gfx.text(TR("wind", c.wind_speed_10m), 44, top + 136, 13);
  gfx.text(TR("updated", String(c.time || "").replace("T", " ")), 44, top + 156, 13);

  const x = 250;
  ui.separator(x - 16, top + 12, x - 16);
  gfx.color(theme.text3);
  gfx.text("JSON", x, top + 14, 11, "semibold");
  gfx.color(theme.text2);
  gfx.clip(x, top + 34, w - x - 40, boxH - 46);
  gfx.wrap(weather.raw, x, top + 34, w - x - 40, 12, "mono");
  gfx.unclip();
}

function drawToast(w, h) {
  const tw = gfx.textWidth(toast, 13, "semibold") + 36;
  gfx.rect(w / 2 - tw / 2, h - 92, tw, 30, 15, [0, 0, 0, 170]);
  gfx.color("#FFFFFF");
  gfx.text(toast, w / 2 - tw / 2, h - 84, 13, "semibold", "center", tw);
}

// ------------------------------------------------------------------ callbacks
app.draw = (w, h) => {
  gfx.clear(theme.bg);
  const t = ui.segmented("tabs", [TR("tab_todo"), TR("tab_clock"), TR("tab_net")], tab, w / 2 - 180, 14, 360, 30);
  if (t !== tab) {
    tab = t;
    store.set("tab", tab);
  }
  if (tab === 0) drawTodos(w, h);
  else if (tab === 1) drawClock(w, h);
  else drawNetwork(w, h);
  if (toast) drawToast(w, h);
};

app.event = (e) => {
  if (e.type === "keydown" && e.key === "escape" && draft) draft = "";
};

app.menu = () => [
  {
    title: TR("app_name"),
    items: [
      { label: TR("clear_done"), id: 1, enabled: todos.doneCount() > 0 },
      { label: TR("refresh"), id: 2 },
      "-",
      { label: TR("about"), id: 3 },
    ],
  },
];

app.onmenu = async (id) => {
  if (id === 1) showToast(TR("cleared", todos.clearDone()));
  if (id === 2) {
    tab = 2;
    fetchWeather();
  }
  if (id === 3) {
    const button = await ui.alert(TR("about"), TR("about_body"), [TR("ok"), TR("open_code")]);  // 0-based index
    if (button === 1) sys.open("bundle:/main.js");
  }
};

app.close = () => {
  store.save();
  return true;
};
