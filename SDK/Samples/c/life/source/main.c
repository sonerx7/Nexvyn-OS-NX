/* Game of Life: Conway's cellular automaton in plain C, compiled on the console by TinyCC.
 * Shows: static arrays, app_update with a fixed step, painting with ui_hit + ui_mouse, ui_slider, toolbar buttons
 * with icons, rand(), app_menu, and saving the board as a string with store_setStr in app_autosave / app_close. */
#include <nexvyn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define COLS 64
#define ROWS 40

static unsigned char grid[ROWS][COLS], next[ROWS][COLS];
static bool running;
static float speed = 10;      /* generations per second */
static float acc;
static int generation;
static int paintValue = -1;   /* -1 = not painting, else the value the drag writes */

static int population(void) {
    int n = 0;
    for (int y = 0; y < ROWS; y++)
        for (int x = 0; x < COLS; x++) n += grid[y][x];
    return n;
}

static void step(void) {
    for (int y = 0; y < ROWS; y++) {
        for (int x = 0; x < COLS; x++) {
            int n = 0;
            for (int dy = -1; dy <= 1; dy++)
                for (int dx = -1; dx <= 1; dx++)
                    if (dx || dy) n += grid[(y + dy + ROWS) % ROWS][(x + dx + COLS) % COLS];  /* the edges wrap */
            next[y][x] = n == 3 || (n == 2 && grid[y][x]);
        }
    }
    memcpy(grid, next, sizeof grid);
    generation++;
}

static void clear(void) {
    memset(grid, 0, sizeof grid);
    generation = 0;
}

static void randomize(void) {
    for (int y = 0; y < ROWS; y++)
        for (int x = 0; x < COLS; x++) grid[y][x] = rand() % 100 < 28;
    generation = 0;
}

static void glider(int x, int y) {
    static const int cells[5][2] = {{1, 0}, {2, 1}, {0, 2}, {1, 2}, {2, 2}};
    for (int i = 0; i < 5; i++) grid[(y + cells[i][1]) % ROWS][(x + cells[i][0]) % COLS] = 1;
}

/* the board is saved as one string of '0' and '1' characters */
static void save(void) {
    static char buf[ROWS * COLS + 1];
    for (int i = 0; i < ROWS * COLS; i++) buf[i] = grid[i / COLS][i % COLS] ? '1' : '0';
    buf[ROWS * COLS] = 0;
    store_setStr("board", buf);
    store_setNum("speed", speed);
}

void app_load(const char* arg) {
    srand((unsigned)sys_epoch());
    speed = (float)store_getNum("speed", 10);
    const char* b = store_getStr("board", "");
    if (strlen(b) == ROWS * COLS) {
        for (int i = 0; i < ROWS * COLS; i++) grid[i / COLS][i % COLS] = b[i] == '1';
    } else {
        glider(2, 2);
        glider(20, 10);
        glider(40, 20);
    }
}

void app_update(float dt) {
    if (!running) return;
    acc += dt;
    float every = 1.0f / speed;
    int guard = 0;
    while (acc >= every && guard++ < 4) {
        acc -= every;
        step();
    }
    if (acc > every) acc = 0;
}

void app_draw(float w, float h) {
    gfx_clear(theme_color("bg"));

    /* toolbar */
    float x = 16;
    if (ui_button(running ? TR("pause") : TR("play"), x, 12, 110, 34, "primary", running ? "pause" : "play_arrow", true))
        running = !running;
    x += 118;
    if (ui_button(TR("step"), x, 12, 96, 34, NULL, "skip_next", !running)) step();
    x += 104;
    if (ui_iconButton("shuffle", x, 12, 34, 34, NULL, false, "rnd")) randomize();
    x += 42;
    if (ui_iconButton("delete", x, 12, 34, 34, NULL, false, "clr")) clear();
    x += 50;
    gfx_color(theme_color("text2"));
    gfx_text(TR1("speed", nxv_fmt("%d", (int)speed)), x, 20, 13, NULL, NULL, 0);
    speed = ui_slider("speed", speed, 1, 30, x + 110, 16, w - x - 126, 1);

    /* board: the largest square cells that fit */
    float top = 58, bottom = 30;
    float cell = (w - 32) / COLS;
    if ((h - top - bottom) / ROWS < cell) cell = (h - top - bottom) / ROWS;
    float bw = cell * COLS, bh = cell * ROWS, ox = (w - bw) / 2, oy = top;
    gfx_rect(ox, oy, bw, bh, 6, theme_dark() ? "#0D1117" : "#FFFFFF");
    /* returned strings only live for the next 15 SDK calls: copy the color before the loop */
    char live[16];
    snprintf(live, sizeof live, "%s", theme_color("accent"));
    for (int y = 0; y < ROWS; y++)
        for (int c = 0; c < COLS; c++)
            if (grid[y][c]) gfx_rect(ox + c * cell + 0.5f, oy + y * cell + 0.5f, cell - 1, cell - 1, cell / 4, live);
    gfx_color(theme_color("separator"));
    gfx_rectLine(ox, oy, bw, bh, 6, 1);

    /* painting: the first touched cell decides whether the drag draws or erases */
    nxv_hit hit = ui_hit("board", ox, oy, bw, bh);
    if (hit.held) {
        float mx, my;
        bool down, hover;
        ui_mouse(&mx, &my, &down, &hover);
        int cx = (int)((mx - ox) / cell), cy = (int)((my - oy) / cell);
        if (cx >= 0 && cx < COLS && cy >= 0 && cy < ROWS) {
            if (paintValue < 0) paintValue = !grid[cy][cx];
            grid[cy][cx] = (unsigned char)paintValue;
        }
    } else {
        paintValue = -1;
    }

    gfx_color(theme_color("text2"));
    gfx_text(TR2("status", nxv_fmt("%d", generation), nxv_fmt("%d", population())), 0, h - 22, 13, NULL, "center", w);
}

void app_event(const nxv_event* e) {
    if (strcmp(e->type, "keydown") != 0 || !e->key) return;
    if (strcmp(e->key, "space") == 0) running = !running;
    else if (strcmp(e->key, "n") == 0 && !running) step();
    else if (strcmp(e->key, "r") == 0) randomize();
    else if (strcmp(e->key, "c") == 0) clear();
}

void app_menu(void) {
    menu_begin(TR("board"));
    menu_item(running ? TR("pause") : TR("play"), 1, "Space", false, true);
    menu_item(TR("step"), 2, "N", false, !running);
    menu_separator();
    menu_item(TR("random"), 3, "R", false, true);
    menu_item(TR("add_glider"), 4, NULL, false, true);
    menu_item(TR("clear"), 5, "C", false, true);
}

void app_onmenu(int id) {
    if (id == 1) running = !running;
    else if (id == 2) step();
    else if (id == 3) randomize();
    else if (id == 4) glider(rand() % COLS, rand() % ROWS);
    else if (id == 5) clear();
}

void app_suspend(void) { running = false; }
void app_autosave(void) { save(); }
bool app_close(void) {
    save();
    return true;
}
