# Building Nexvyn OS apps with AI

**English** · [Türkçe](README.tr.md)

This folder holds ready-made context packs and prompts for writing Nexvyn OS apps with Claude, ChatGPT, Gemini or
local models (LM Studio, Ollama...). Assistants do not know the SDK; without these files they invent functions that
do not exist. The packs carry the same facts as `SDK/Reference/SDK.en.md`, only shorter.

## Files

Every file comes in two versions: English `X.en.md` and Turkish `X.tr.md`. Both carry the same facts and rules.

| File | Purpose |
|---|---|
| [system-prompt.en.md](system-prompt.en.md) · [Turkish](system-prompt.tr.md) | The main context pack (~5k tokens): bundle layout, `app.json`, enforced permissions, program structure, rules (3 s, 64 MB, 60 fps, `TR()`), a summary of the whole API, language differences, the store format |
| [languages/](languages/) | Language packs: [lua](languages/lua.en.md), [javascript](languages/javascript.en.md), [python](languages/python.en.md), [squirrel](languages/squirrel.en.md), [c](languages/c.en.md), [java](languages/java.en.md) (Turkish: `.tr.md`): skeleton, language rules, checker |
| [tasks/](tasks/) | Task prompts: [make a game](tasks/make-game.en.md), [make a utility](tasks/make-utility.en.md), [port a Lua game to JS](tasks/port-lua-to-js.en.md), [add a UI language](tasks/add-language.en.md), [write store.json and the screenshot script](tasks/store-listing.en.md), [fix a checker failure](tasks/fix-lua-check.en.md) (Turkish: `.tr.md`) |
| [checklist.en.md](checklist.en.md) · [Turkish](checklist.tr.md) | What the assistant must verify before answering |

## Which language to use

- **If you talk to the assistant in English**, or use a small local model, give it the English files (small models
  usually follow English instructions more strictly).
- **If you talk to it in Turkish**, give it the `.tr.md` files: the instructions, examples and task prompts are in
  Turkish and the assistant answers in Turkish. Both system prompts tell the model to reply in the language the user
  writes in, so a Turkish question with the English context still gets a Turkish answer.
- Do not mix them: the system prompt, the language pack, the task prompt and the checklist should be in the same
  language.
- API names, `app.json` keys, file names and checker commands are the same in both versions. The app itself is
  bilingual either way, through `lang/en.json` and `lang/tr.json`.

## How to use them

1. **Give the context.** `system-prompt.en.md` (or `system-prompt.tr.md`) + the pack of your programming language:
   - **Claude:** create a Project and add both files to *Project knowledge* (or paste them into the first message).
     The context is large enough to add the whole `SDK/Reference/SDK.en.md` as well.
   - **ChatGPT:** create a GPT or a Project and upload the files, or paste them into the first message.
   - **Gemini:** put them into the Gem instructions or the first message; with long context add `SDK.en.md` too.
   - **Local models (7-14B):** put only the system prompt + the language pack into the system prompt and set the
     context length to at least 8k (16k is better). Small models mix up the language rules: prefer Lua or JavaScript and check every
     answer.
   - **On the console:** the **Ask AI** panel in Nexvyn OS Studio uses the API keys from AI Chat; attach the relevant
     file to your question. The panel never edits your files itself.
2. **Ask for the task.** Copy a prompt from `tasks/` and fill in the `<...>` parts.
3. **End the request** with "Before you answer, go through checklist.en.md" (or keep `checklist.en.md` in the context).
4. **Check it.** The assistant's code must always pass the checker:
   `python SDK/Tools/nxv/nxv.py check <folder> --sdk <Nexvyn OS checkout>`. If it fails, send the output back with the
   [tasks/fix-lua-check.en.md](tasks/fix-lua-check.en.md) prompt.
5. **Try it on the console.** The checkers use a mock SDK; the real test is the console or Ryujinx.

Safety: do not give the assistant API keys, passwords or personal data, and do not let it embed such values in the
code. Store review rejects apps that collect hidden data.
