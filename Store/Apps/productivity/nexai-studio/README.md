# Nex Local AI Studio (`com.sonerx7.nexai.studio`)

Nex Local AI Studio runs compact GGUF language models locally on your console, with a built-in AI Model Store, persistent chats, live web knowledge and an image and video studio. It is a native app (`nexai_studio.nxvmod`, C++17 with `llama.cpp` / `ggml`) built on the **Nexvyn Native SDK 1.2**.

| Field | Value |
|---|---|
| **ID** | `com.sonerx7.nexai.studio` |
| **Version** | `1.2.0` |
| **Category** | `productivity` |
| **Runtime** | `native` (window mode, `minNative 1.2`) |
| **Target SDK** | `1.13` (`minSdk 1.10`) |
| **Languages** | `en`, `tr`, `de`, `es`, `fr`, `ja`, `ko`, `zh` |
| **Permissions** | `network`, `files`, `notifications` |
| **License** | `MIT` |

## Permissions

| Permission | Purpose |
|---|---|
| `network` | AI Model Store (Hugging Face Hub API and GGUF downloads), live web knowledge, cloud image API (Pollinations.ai), and the optional LAN Ollama / OpenAI / Automatic1111 bridge |
| `files` | Picking local `.gguf` models, opening text and code files for analysis, exporting chats (`.md`) and generated media (`.png`, `.gif`, `.avi`) |
| `notifications` | Telling you when a background model download finishes |

## Features

- **Local GGUF runner with Memory Guard:** runs compact models from SmolLM2 135M up to Phi 3.5 mini on up to 3 CPU threads, leaving one core for Nexvyn OS. It checks free RAM before loading and blocks models that would not fit safely.
- **AI Model Store (29 verified models):** curated GGUF catalog (SmolLM2, Gemma 2/3, Qwen 2.5/Coder/3, Llama 3.2, DeepSeek-R1-Distill, TinyLlama, Granite, OLMo 2, Falcon3, Phi 3.5), all up to 2 GB. Each entry shows a speed tag, parameters, quantization, size and a "fits now / won't fit now" badge. Filter by speed and family, sort by size or name, search Hugging Face live, or import a `.gguf` from the SD card. Downloads stream to disk and are renamed atomically when complete.
- **LM Studio-style layout:** icon rail (Chat, Discover, My Models, Image & Video, Tools, Settings), a model picker bar with load progress, RAM and eject, a chat window with a conversation list, markdown code blocks with copy buttons, and a collapsible right panel (system prompt, temperature, top_p, top_k, repeat penalty, context, max tokens, threads, live tokens per second, first-token time).
- **Live web knowledge:** on by default when the console is online. Weather questions use Open-Meteo, clock questions use the device clock, currency questions use open.er-api.com, and time-sensitive questions use DuckDuckGo plus the text of the top results. Answers show a "Searched" chip and the sources. Settings has a default city and a "search every message" switch. Offline or blocked lookups fall back to a normal answer.
- **Persistent chat history:** multi-session storage, personas, context trimming and Markdown export.
- **Image and video studio:** images via Pollinations.ai, a LAN Automatic1111/Forge server, an OpenAI-compatible Images API or offline procedural art; render animations into `.gif` and MJPEG `.avi` files with built-in playback.
- **AI tools and hybrid bridge:** summarize, translate or explain documents and code, or connect to a LAN or cloud Ollama, LM Studio or OpenAI-compatible server with streaming.

## Controls

- **Gamepad:** D-pad / left stick navigate, `A` select, `B` back, `L` / `R` switch tabs, `X` focus the chat input, `Y` stop generation or a download.
- **Touch:** large touch targets, drag scrolling, automatic on-screen keyboard.
- **Keyboard and mouse:** hover, click and wheel, right-click context menu on chats, `Enter` to send.

## Versions

| Version | Highlights |
|---|---|
| `1.2.0` | LM Studio-style layout, 29-model AI Model Store with speed tags and memory-fit badges, live web knowledge, default city and search settings, stability and Memory Guard improvements. |

## Third-Party Notices

- **llama.cpp / ggml** (MIT License)
- **Mbed TLS 3.6.7** (Apache-2.0 OR GPL-2.0-or-later)
- **Dear ImGui 1.91.5** (MIT License)
- **stb_image / stb_image_write** (Public Domain / MIT)
- **nlohmann/json** (MIT License)
