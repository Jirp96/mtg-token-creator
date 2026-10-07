# MTG Token Creator

A Ruby CLI that generates print-ready token cards for Magic: The Gathering. It
reads a list of existing MTG cards from a CSV, fetches their artwork and data
from the [Scryfall API](https://scryfall.com/docs/api), renders them as
MTG-style token images using [`ruby-vips`](https://github.com/libvips/ruby-vips),
and assembles everything into a single A4 PDF sheet ready to cut and play.

> **Current limitation:** tokens are (for now) specific for [Hashaton, Scarab's Fist](https://gatherer.wizards.com/DRC/en-us/1/hashaton-scarabs-fist)

## Getting started

### Option A — Dev container (recommended)

The repo includes a ready-to-use dev container with Ruby and libvips pre-installed.
Open the project in VS Code (or any [Dev Containers](https://containers.dev/)-compatible
editor) and choose **Reopen in Container**. `bundle install` runs automatically on
creation.

Then [download the fonts](#font-setup) and you're ready to go.

### Option B — Local setup

**1. Install Ruby**

Ruby 3.4.9 is required (see [`.ruby-version`](.ruby-version)). Using a version
manager like [rbenv](https://github.com/rbenv/rbenv) or
[mise](https://mise.jdx.dev/) is recommended:

```sh
rbenv install 3.4.9
```

**2. Install libvips**

```sh
# macOS
brew install vips

# Debian / Ubuntu
sudo apt-get install libvips-dev
```

**3. Install gems**

```sh
bundle install
```

**4. Font setup**

The renderer uses the card fonts from
[chilli-axe](https://github.com/chilli-axe/mtg-photoshop-automation): **NDPMTG**
(mana symbols), **Beleren** (card name, type line, P/T) and **Plantin**
(rules text, regular and italic). They are not bundled in this repo due to
licensing. Download them into `fonts/`:

```sh
for font in NDPMTG.ttf Beleren2016-Bold-Asterisk.ttf PlantinMTProRg.TTF PlantinMTProRgIt.TTF; do
  curl -Lo "fonts/$font" \
    "https://raw.githubusercontent.com/chilli-axe/mtg-photoshop-automation/master/fonts/$font"
done
```

If Beleren or Plantin are missing the renderer falls back to the system serif
font; NDPMTG is required for mana symbols.

## Usage

```sh
ruby main.rb cards.csv
```

The tool fetches each card, renders a token image to `output/<card_name>.jpg`,
then assembles all images into `pdf_sheet.pdf`. The intermediate JPEGs are
deleted after the PDF is written.

### CSV format

No header row. Columns:

| Column | Required | Meaning |
| ------ | -------- | ------- |
| 1 — card name | yes | Exact card name to look up on Scryfall. Blank rows are skipped. |
| 2 — art selector | no | Choose a specific printing's art: a Scryfall card URL (e.g. `https://scryfall.com/card/dom/1/...`) or a set code (e.g. `dom`). Falls back to the default art if the selection can't be found. |

```csv
Grave Titan
Llanowar Elves,dom
Ancestral Recall,https://scryfall.com/card/2ed/48/ancestral-recall
```

### Environment variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `SCRYFALL_DELAY` | `0.12` | Seconds to wait between Scryfall requests (respect their rate limit). |

## Development

```sh
bundle exec rake     # RuboCop + RSpec (default)
bundle exec rspec    # tests only
bundle exec rubocop  # lint only
```

The test suite includes a golden-image regression test
([`spec/image_generation_spec.rb`](spec/image_generation_spec.rb)) that
compares rendered output against a committed reference within a pixel
tolerance. After an intentional rendering change, regenerate the reference
image with:

```sh
GOLDEN_REGEN=1 bundle exec rspec spec/image_generation_spec.rb
```

## Contributing

Contributions are welcome. Please follow these steps:

1. Fork the repo and create a branch from `main`.
2. Make your changes and ensure the full suite passes: `bundle exec rake`.
3. If you change the rendering output, regenerate the golden image (see above).
4. Open a pull request with a clear description of what changed and why.

For larger changes or new features, open an issue first to discuss the approach.

## License

[MIT](LICENSE) — © 2026 Juan Papazian

---

_Built with the assistance of [Claude Code](https://claude.ai/code)._

## Roadmap

- [ ] Support other token types (e.g. tokens created by Myrkul, Lord of Bones)
- [ ] Support generic power/toughness and creature type tokens from the CSV
