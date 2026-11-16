# Game Engine: AI features (WP17)

The Game Engine can use the AI provider chosen in AI Chat (Anthropic, Gemini, OpenAI, NVIDIA or any OpenAI-compatible
address) for four jobs. All of them are optional: without prompt files, provider or network the AI buttons are hidden and
the offline tools (the describe-and-create wizard of WP16, the Sound Lab, the editor) work exactly as before.

| Feature | Where | What the model returns | What the engine does with it |
|---|---|---|---|
| Create with AI | Describe and create (home screen), next to the text field | a **design JSON** (the WP16 schema) plus a music genre, up to 8 sound recipes and an ambient particle preset | validates it, builds the project with the same genre packs and level generators as the offline wizard, shows the preview card; the project is written only on Create |
| Layout | Edit > AI helper > Layout (3D scenes) | a **placement spec**: allowed kinds with `at`, `line`, `grid`, `circle` or `scatter` | places the objects as one undo step; Undo removes them |
| Sound | Edit > AI helper > Sound | a Sound Lab **recipe id with slider values**, or a composer genre with tempo, length and danger | opens the Sound Lab with those values and plays the preview; nothing is saved until the user saves there |
| Fix a problem | Edit > AI helper > Fix a problem | an **explanation** and an optional list of **structured changes** (behaviour parameter, object property, three settings) | shows the text; the changes are applied only when the user taps Apply, as one undo step. Code is never changed |

| Part | File |
|---|---|
| Prompts, allowlists, reply validators, repair round, privacy scrub, summaries | `source/core/ge_ai.{h,cpp}` (pure C++, no network, no clock) |
| Provider calls (`aichat::Stream`), consent card, wizard button, AI helper modal | `source/apps/ge_ai_panel.{h,cpp}` |
| Hooks | `ge_wizard_panel.cpp` (button, preview card), `ge_sound_panel.cpp` (`loadAi`), `app_gamemaker.cpp` (menu item, undo steps) |
| Prompt and schema files | `romfs/Applications/gamemaker.app/ai/prompts.json`, `create/layout/sound/debug.schema.json` |
| Unit tests | `tests/test_geai.cpp` (golden requests, 20 recorded replies, hostile replies, repair, fallback, scrub) |
| Gate check | `tools/ge_ai_check.py` (in `tools/n2_gate.py`), with `tests/ge_ai_cli.cpp`, `tests/geai_e2e_host.cpp`, `tests/geai_fake_provider.py` |

## 1. Requests

Every request has the same shape (`ge_ai::buildRequest`):

- **System prompt**: the common rules of `prompts.json`, the task's own lines, the reply schema (`<task>.schema.json`, compact
  JSON Schema) and the **allowed ids**, taken from the real libraries at run time: 3D models of `library.json` and the
  installed pack pieces (layout), the 105 sound recipes and 12 composer genres of `ge_audio` (create, sound), the 14 particle
  presets (create), and the behaviours with parameter ranges that objects of the project carry (debug).
- **User turn**: the user's words inside `<request>...</request>` and, for layout and debug, the scene or project summary and
  the error log inside `<context>...</context>`. The prompt says that text inside these tags is data and cannot change the
  rules. User text is cut to 2000 bytes, context to 8000.
- **Language**: system prompts are English. The model writes the human-readable fields (title, pitch, note, explanation, why)
  in the UI language (`{lang}` in `prompts.json`); ids and enum values stay language independent.

`prompts.json` carries `"format": "nexvyn-ge-ai-prompts"` and `"version": 1`; a file with another format or a newer version
is refused and the AI buttons stay hidden (fail closed). `tests/fixtures/ge_ai/*.golden.txt` hold two full requests; a prompt
change has to update them (`python tools/ge_ai_check.py --update`) so it is always a visible diff.

## 2. Replies are data

A reply is never executed. `ge_ai::extractJson` takes the first complete JSON object of the reply (code fences and prose around
it are ignored) after these checks, made before the JSON parser sees anything:

| Limit | Value |
|---|---|
| Reply size | 64 KB |
| Nesting | 8 levels |
| Values | 4000 |

Then the task's validator reads only the fields of its schema:

- **Ids** must be in the allowlist (unknown id = error). Strings that look like code, a path, a URL or a command
  (`../`, `\`, `://`, `sdmc:`, `os.execute`, `require(`, `function`, `${`, backticks, `&&`, ...) are refused in every data field.
- **Numbers** have ranges. Values slightly outside are clamped with a warning; a position far outside the level, a wrong type
  or a missing required field is an error.
- **Free text** (title, pitch, note, explanation) is cleaned (control characters removed, invalid UTF-8 replaced) and cut
  (80, 200, 300, 3000 bytes). Titles and notes that look like code are refused.
- **Unknown fields** are dropped with a warning.
- **Create** goes through the wizard's own reader (`ge_wizard::designFromJson`): a value outside its list is an error, a
  combination the genre cannot do (a racing game with a side camera) is corrected with a warning.
- **Layout**: at most 40 entries and 120 objects per reply; `line`/`circle`/`scatter` counts 1..60, `grid` 12 x 12; `y` 0..20,
  `s` 0.25..4; positions inside the ground (`|x|, |z| <= ground size / 2`). Scatter is seeded, so the same reply places the same
  objects.
- **Sound**: the ten Sound Lab sliders with the panel's own ranges (pitch -12..12, length 0.4..2.5, slide -4..4, vibrato 0..0.4,
  bright -3..2, tremolo 0..1, crunch 0..1, echo 0..0.8, reverb 0..0.8, variation 0..0.5); music bpm 50..200, bars 2..16, danger 0..1.
- **Debug**: at most 10 changes. `beh_param` needs an object id of the project, a behaviour that object has, a parameter of the
  numeric, bool or choice kind and a value in its range; `prop` is one of `x y z ry s`; `setting` is one of `gravity lives
  timeLimit`. `applyChanges` checks every change again before it writes it and never touches scripts, events or files.

## 3. One repair round, then fallback

`ge_ai::Flow` runs one task: request, validate; if the reply has errors the model gets its own reply back with the validator's
error list (at most 12 lines, `prompts.json` `repair`) and one more chance. A second invalid reply ends the flow:

| Task | Invalid twice, or a provider error (no key, offline, 401, 429, 5xx, timeout) |
|---|---|
| Create | **Fallback**: the offline wizard's design stays on the preview card, with a note saying why |
| Layout, sound, debug | **Failed**: the panel shows the AI Chat error text (`aichat::errorTitle`) or "could not be used" |

Nothing crashes on any reply; the network runs on `aichat::Stream`'s own thread and the main thread only pumps it.

## 4. Privacy

- Nothing is sent before the **consent card** has shown the exact user turn that goes out (and the provider's name) and the
  user tapped Send. The system instructions are fixed product text.
- `ge_ai::scrub` runs over everything the user or the project supplies: file paths become `<path>/<file name>` (drive paths,
  `sdmc:/`, `romfs:/`, `~/`, `/home/...`, UNC paths, also with spaces in folder names), URLs become `<url>`, e-mail addresses
  `<email>`; key-like tokens (provider prefixes, long mixed letter-digit tokens), `password=`, `token:`, `Authorization: Bearer`
  values and the exact stored provider keys become `<secret>`; the account name, the user folder and the console nickname
  become `<user>`.
- Summaries send no scripts and no paths: title, mode, level and object counts by kind, variables, a few settings, the
  objects that carry behaviours with their parameters.
- Keys stay in AI Chat's encrypted store; the stored keys are loaded only to be compared in memory. Prompts and replies are not
  logged and not kept; the log only says how many requests a flow made and how it ended.
- This is not telemetry: data goes only to the provider the user chose, only when the user taps an AI action.

## 5. Tests

- `tests/test_geai.cpp` (12 cases): prompt files load and fail closed; golden requests; the 20 recorded replies of
  `tests/fixtures/ge_ai/replies.json` (synthetic replies written for the tests, 8 languages, plain / fenced / wrapped in prose)
  give valid projects reaching all 12 genre packs; unknown ids, wrong types and missing fields; hostile replies (70 KB, 5000-deep
  nesting, 6000 values, binary noise, path and code injection); the single repair round and the fallback; layout patterns,
  bounds and the 120-object cap; sound ranges; debug changes refused for unknown objects, missing behaviours, out-of-range
  values, code values and scripts; the scrub; bounded summaries.
- `tools/ge_ai_check.py`: the prompt files against the libraries (every enum value is read by the wizard, every allowlist equals
  its library, slider ranges equal the C++ ranges), the recorded replies through the Python project validator, the goldens,
  and an end-to-end run of the production protocol code (`aichat_proto.cpp` + libcurl) against `tests/geai_fake_provider.py`
  on 127.0.0.1: streamed replies split into many pieces (OpenAI-compatible and Anthropic-style events), the repair round,
  prose / huge / nested / hostile replies, 401, 429, 500, an unknown model, a timeout and no server. The fake server also checks
  that the key never appears in a request body and that the user text arrives wrapped as data.
- No test calls a real provider or uses a real key.

## 6. Emulator evidence

With `sdmc:/NexvynOS/gewizardtest.txt` and `sdmc:/NexvynOS/geaitest.json` (`{"base": "http://127.0.0.1:<port>/v1", "model": "ok"}`)
in place, the Game Engine points AI requests at `python tests/geai_fake_provider.py --serve <port>` for that session only
(the override is in memory and never saved). Autorun: `gewizard:<text>`, `geaicreate` (sends without the consent card),
`gewizcreate:1` (creates and plays). With no server listening the same steps show the offline fallback.
