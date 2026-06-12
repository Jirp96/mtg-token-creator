# MTG Token Creator — Quality Analysis & Refactor Plan

## Context

`mtg-token-creator` is a ~780-line procedural Ruby CLI that reads card names from a
CSV, fetches data from the Scryfall API, renders MTG-style token images with
`ruby-vips`, and assembles them into a printable PDF with `prawn`. It works, but the
README itself flags "Refactor code" as an open TODO. The code has accumulated debt:
module-level mutable state, ~40 scattered magic-number constants, a 421-line god
module (`lib/image_generation.rb`), no error handling on network/file I/O,
inconsistent naming (camelCase vs snake_case), non-idiomatic Ruby, and **zero tests,
linting, or CI**.

This plan does a **behavior-preserving, incremental refactor** plus adds a
**test/lint/CI safety net first**, so cleanup can proceed without regressions. The
hardcoded Zombie token type and 4/4 P/T defaults are intentionally **left as-is**
(generalization is deferred). The goal: same output, dramatically better
maintainability.

---

## Findings (what we're fixing)

### Critical
- **No safety net**: no tests, no `.rubocop.yml`, no CI, no `.ruby-version`. Refactoring blind is risky.
- **No error handling on I/O**: `download_image` (`lib/image_generation.rb:418`) has no timeout/retry/rescue; `write_to_file` (`lib/image_generation.rb:85`) assumes `output/` exists; Scryfall responses are `.parse`d without status checks (`main.rb:68-69`).
- **`raise StandardError`** with no message/class (`main.rb:57`, marked `#TODO: Custom error`).

### Major
- **God module**: `lib/image_generation.rb` is 421 lines mixing config, layout math, vips compositing, oracle-text wrapping, second-face rendering, and HTTP download.
- **~40 magic-number constants** at file top (`lib/image_generation.rb:7-46`) with no grouping/source-of-truth; aspect ratios (457/626) and RGB colors (`[30,60,120]`, `[205,220,240]`) duplicated inline.
- **Long methods**: `generate` (39 lines, 11 sequential ops), `wrapped_oracle_lines` (40 lines), `render_second_face_box` (42 lines), `add_text` (duplicated nil-fontfile branches, `lib/image_generation.rb:97-112`).
- **Module-level instance-variable cache** (`@oracle_space_width`, `@default_oracle_line_height`, etc.) on a `self.`-method module — confusing state ownership.
- **Top-level global functions** in `main.rb` (`csv_value`, `resolve_art_crop_url`, …) and **top-level constants leaking** across files (`CARD_API_URL`, `CARD_TEXT_SIZE`, etc. are global, not namespaced).
- **`main()` invoked at load** (`main.rb:96`) — not guarded by `if __FILE__ == $PROGRAM_NAME`, so the file can't be required for testing.

### Medium / Minor
- **Naming**: camelCase locals/params (`cardName`, `fileName`, `fontFile`, `apiCardInfo`, `generatedCard`) violate Ruby snake_case.
- **Idioms**: `if not card.is_saga` → `unless card.saga?`; `cards.append(x)` → `cards << x`; `p "..."` used as logging (`main.rb:77,83,88`); predicate readers named `is_legendary`/`is_saga` instead of `legendary?`/`saga?`.
- **Dead code**: `SCRYFALL_URL = ""` (`main.rb:10`); `mana_simbols` (`lib/scryfall/card.rb:34`) — unused **and** misspelled.
- **Duplication**: mana-cost stripping logic in two places (`lib/scryfall/card.rb:50` and `lib/image_generation.rb:387`); `vertical_center` defined in both `image_generation.rb` and `title_section_renderer.rb`.
- **Repeated nil-or-empty guards** (`x.nil? || x.empty?`) ~6 times across `main.rb`.
- **`sleep(0.1)`** rate-limit (`lib/scryfall/cards.rb:63`) is uncommented and unconfigurable.
- **README**: no usage/run instructions, no CSV format docs; broken-ish font link; stale `.gitignore` (RubyMotion/CocoaPods entries).

---

## Plan

### Phase 0 — Safety net (do first, no production-code changes)
Establish reproducibility and characterization before touching logic.

1. Add **`.ruby-version`** (`3.4.9`, matching `.devcontainer/Dockerfile`) and a `ruby "3.4.9"` directive to `Gemfile`.
2. Add dev dependencies to a `group :development, :test` in the Gemfile: `rake`, `rspec`, `rubocop`, `rubocop-rspec`, `webmock` (stub Scryfall).
3. Add **`.rubocop.yml`** — start lenient (`NewCops: enable`, relaxed layout/metrics cops to match current reality), tighten over phases. Run `rubocop --auto-gen-config` to baseline `.rubocop_todo.yml` so the build is green day one.
4. Add **characterization tests** (`spec/`) that pin current behavior — the regression guard for every later phase:
   - `spec/scryfall/card_spec.rb`: assert `name`, `type` (the literal Zombie string incl. its historical double space), `stat_line`, `raw_cost`, `processed_name` (incl. ASCII-only `\w` stripping), `second_face`, `art_crop_url` fallback chain.
   - `spec/scryfall/cards_spec.rb`: WebMock-stub `parse_scryfall_card_url`, `get`, `get_by_set_and_number`, and `get_print_from_uri` pagination.
   - `spec/pdf_generation_spec.rb`: `mm_to_pt` math + a smoke test that `generate` emits a valid PDF.
   - `spec/image_generation_spec.rb`: **golden-image test** — generate one card from a JSON fixture (download stubbed) and assert the output JPEG matches a committed golden via vips pixel diff within tolerance. This is the linchpin guarding the vips refactor.
5. Add **`.github/workflows/ci.yml`**: install `libvips42`, `bundle install`, run `rubocop` + `rspec` on push/PR.
6. Add a **`Rakefile`** with `default => %i[rubocop spec]`.
7. Add `vendor/` and any local test artifacts to `.gitignore`.

### Phase 1 — Centralize configuration (kill magic numbers)
Behavior-preserving constant extraction; values stay numerically identical.

- Create **`lib/layout.rb`** (e.g. `module Layout`) holding the card/art/title/pips/oracle/second-face/stat-line constants currently at `lib/image_generation.rb:7-46`, grouped and namespaced (no more global leakage).
- Define named **color constants** for the duplicated RGBs: `SECOND_FACE_BORDER_COLOR = [30,60,120,255]`, `SECOND_FACE_BG_COLOR = [205,220,240,255]`, `TEXT_BLACK = [0,0,0]`.
- Move PDF page/card dimensions (`lib/pdf_generation.rb:3-6`) and Scryfall API URLs (`lib/scryfall/cards.rb:4-5`) under their respective namespaces instead of top-level constants.
- Delete dead `SCRYFALL_URL` and the unused/misspelled `mana_simbols`.

### Phase 2 — Decompose the image-generation god module
Split `lib/image_generation.rb` by responsibility. Keep `ImageGeneration.generate(card)` as the stable public entry point (tests/`main` unchanged).

- **`lib/vips_helpers.rb`** (mixin): shared low-level primitives — `transparent_layer`, `text_layer`, `vertical_center` (dedupe the copy in `title_section_renderer.rb:81`), `add_image`, the colorize-mask pattern. Collapse `add_text`'s duplicated nil-fontfile branches into one call that conditionally merges `fontfile` into an options hash (mirror the cleaner pattern already in `text_layer`, `lib/image_generation.rb:256-263`).
- **`lib/oracle_text_renderer.rb`**: the inline-symbol oracle pipeline (`render_inline_oracle_text`, `wrapped_oracle_lines`, `oracle_token_image`, padding/metric/caching helpers). Convert the module-level `@`-cache into a small instance (or cleanly memoized object) so state ownership is explicit. Extract the inline regex `/\{[^}]+\}|\s+|[^\s{]+/` to a named constant.
- **`lib/second_face_renderer.rb`**: `render_second_face_box` + `draw_second_face_separator`, using the new color constants; pull the repeated `y += text.height + pad` advance into a helper.
- Trim `generate` to a readable orchestration sequence delegating to the above.

### Phase 3 — Clean up `main.rb`, Card, Cards
- Wrap the top-level functions in `main.rb` into a `TokenCreator` (or `CLI`) class/module; guard execution with `if __FILE__ == $PROGRAM_NAME`.
- Rename camelCase locals/params to snake_case repo-wide (`card_name`, `file_name`, `font_file`, `api_card_info`, `generated_card`).
- Rename predicate readers `is_legendary`/`is_saga` → `legendary?`/`saga?`; update `if not card.is_saga` → `unless card.saga?`. Update all call sites **and the matching spec assertions** in lockstep.
- Replace `cards.append` → `cards <<`; replace `p "..."` status prints with a tiny logger or `warn`/`$stdout.puts`.
- Extract the repeated `x.nil? || x.empty?` into a `blank?(str)` helper.
- Dedupe mana-cost stripping: have `lib/image_generation.rb:387` reuse a `Card`/helper method instead of re-implementing `.tr("{","").split("}")…`.

### Phase 4 — Robustness (error handling, still behavior-preserving on the happy path)
- Replace bare `raise StandardError` (`main.rb:57`) with a custom `UsageError` and a helpful message.
- `download_image`: add HTTP timeout + a small retry, rescue `Net::HTTP`/`SocketError`, surface a clear warning and skip/fallback rather than crashing the whole batch.
- Validate Scryfall HTTP status before `.parse` (`main.rb:68`); warn-and-skip on 404/429.
- Ensure `output/` exists before writing; guard the temp-file cleanup loop (`main.rb:90-92`).
- Comment the `sleep(0.1)` rate-limit and make the delay a named constant.

### Phase 5 — Docs & hygiene
- Rewrite `README.md`: add **Usage** (`ruby main.rb cards.csv`), **CSV format** (name column, optional art-selector column accepting a Scryfall URL or set code), output/PDF description, and the dev workflow (`rake`, `rspec`, `rubocop`).
- Prune the stale `.gitignore` entries (RubyMotion, CocoaPods, etc.).
- Tighten `.rubocop.yml` / shrink `.rubocop_todo.yml` now that the code is clean.

---

## Sequencing & risk

Phases are ordered so each builds on a green test suite. **Phase 0 is mandatory
first** — especially the golden-image test, which is the only thing that makes the
vips decomposition in Phase 2 safe. Phases 1, 3, 4, 5 are low-risk and independently
shippable. Phase 2 is the highest-risk; do it in small commits, re-running the golden
test after each extraction.

## Verification

1. **Automated** (after Phase 0, run continuously): `bundle exec rake` → `rubocop` clean + all `rspec` green, including the Card/Cards/PDF unit specs and the golden-image spec.
2. **Golden-image regression**: before refactoring, generate the current output for a fixture card and commit the JPEG as golden. After each phase, regenerate with identical (stubbed) inputs and confirm visual equivalence (vips pixel diff within tolerance).
3. **End-to-end smoke**: run `ruby main.rb cards.csv` against the live (or WebMock-recorded) Scryfall API; confirm `output/*.jpg` are produced, `pdf_sheet.pdf` is generated, and temp JPEGs are cleaned up — matching pre-refactor behavior.
4. **CI**: confirm the GitHub Actions workflow runs `libvips`-installed `rake` green on a PR.

---

## Environment notes (no local Ruby on this machine)

There is no Ruby on the host PATH; the project is meant to run in the devcontainer.
A reproducible toolchain is available via Docker:

```sh
# Build the dev image (from .devcontainer/Dockerfile — Ruby 3.4.9 + libvips42)
docker build -t mtg-token-creator-dev -f .devcontainer/Dockerfile .devcontainer

# Long-lived container with the workspace mounted and gems persisted to vendor/bundle
docker run -d --name mtg-dev -v "${PWD}:/workspace" -w /workspace mtg-token-creator-dev sleep infinity

# Ruby/bundle are provided by mise; add its shims to PATH inside exec'd commands:
docker exec mtg-dev bash -lc 'export PATH="/home/vscode/.local/share/mise/shims:$PATH"; bundle install'
docker exec mtg-dev bash -lc 'export PATH="/home/vscode/.local/share/mise/shims:$PATH"; bundle exec rake'
```

---

## Progress — all phases complete

Implemented on branch `refactor/quality-cleanup`, one commit per phase, each
verified green via `bundle exec rake` (RuboCop clean + RSpec) in the `mtg-dev`
Docker container (Ruby 3.4.9 + libvips). The golden-image spec matched after
every phase, confirming pixel-equivalent output.

- ✅ **Phase 0** — safety net: `.ruby-version`, dev/test Gemfile group, `.rubocop.yml`
  + `.rubocop_todo.yml`, `Rakefile`, `spec/` (Card, Cards/WebMock, PDF, and the
  golden-image characterization specs), CI workflow, pruned `.gitignore`.
- ✅ **Phase 1** — `lib/layout.rb` centralizes all magic numbers/fonts/colors;
  PDF + Scryfall constants namespaced; dead code removed.
- ✅ **Phase 2** — god module split into `vips_helpers`, `oracle_text_renderer`
  (instance-owned metric cache), `second_face_renderer`; `image_generation.rb`
  is now a 92-line orchestrator (was 421).
- ✅ **Phase 3** — `TokenCreator` class + `__FILE__` guard, snake_case throughout,
  `legendary?`/`saga?` predicates, `log`/`blank?` helpers, deduped mana stripping.
- ✅ **Phase 4** — `UsageError`, resilient art download (timeout/retry/skip),
  output-dir creation, guarded cleanup; spec for the no-art fallback.
- ✅ **Phase 5** — rewritten README, CI font fetch, tightened lint baseline (only
  the vips `Image#insert` false positives and one layout preference remain).

Final: **35 examples, 0 failures; RuboCop clean.**
