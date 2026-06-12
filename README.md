# MTG Token Creator

A Ruby CLI that reads card names from a CSV, fetches card data from the
[Scryfall API](https://scryfall.com/docs/api), renders MTG-style **token**
images with [`ruby-vips`](https://github.com/libvips/ruby-vips), and assembles
them into a print-ready A4 PDF sheet with [`prawn`](https://prawnpdf.org/).

> Tokens are rendered with a hardcoded Zombie type and 4/4 power/toughness by
> default (generalization to other token types is a known TODO).

## Requirements

- Ruby 3.4.9 (see [`.ruby-version`](.ruby-version))
- The native [libvips](https://www.libvips.org/) library (`libvips42` on Debian/Ubuntu)
- Gems: `bundle install`
- The **NDPMTG** mana-symbol font by chilli-axe. Download
  [`NDPMTG.ttf`](https://raw.githubusercontent.com/chilli-axe/mtg-photoshop-automation/master/fonts/NDPMTG.ttf)
  and place it at `fonts/NDPMTG.ttf` (it is intentionally not committed).

A reproducible toolchain (Ruby 3.4.9 + libvips) is provided in
[`.devcontainer/`](.devcontainer/).

## Usage

```sh
ruby main.rb cards.csv
```

For each row the tool fetches the card, renders `output/<card_name>.jpg`, then
combines all rendered images into `pdf_sheet.pdf`. The intermediate JPEGs in
`output/` are deleted once the PDF is written.

### CSV format

No header row. Columns:

| Column | Required | Meaning |
| ------ | -------- | ------- |
| 1 — card name | yes | Exact card name to look up on Scryfall. Blank rows are skipped. |
| 2 — art selector | no | Choose a specific printing's art: either a Scryfall card URL (e.g. `https://scryfall.com/card/dom/1/...`) or a set code (e.g. `dom`). If the selected art can't be found, the default art is used. |

```csv
Grave Titan
Llanowar Elves,dom
Ancestral Recall,https://scryfall.com/card/2ed/48/ancestral-recall
```

The tool is resilient: cards Scryfall can't find are skipped with a warning, a
failed art download falls back to a card with no art, and a `429` rate-limit
response aborts with a clear message. The request delay is configurable via the
`SCRYFALL_DELAY` environment variable (seconds; default `0.12`).

## Development

```sh
bundle exec rake     # RuboCop + RSpec
bundle exec rspec    # tests only
bundle exec rubocop  # lint only
```

The suite includes a golden-image regression
([`spec/image_generation_spec.rb`](spec/image_generation_spec.rb)) that compares
rendered output against a committed reference within a pixel tolerance.
Regenerate the reference after an intentional rendering change with
`GOLDEN_REGEN=1 bundle exec rspec spec/image_generation_spec.rb`.

## TODO

- [ ] Add other types of tokens (e.g. Myrkul, Lord of Bones)
