# AGENTS.md

## Project overview

This repository contains the source for a Jekyll site published with GitHub Pages. Blog posts live in `_posts/`, shared markup lives in `_includes/` and `_layouts/`, and supporting code examples live in `code/`.

## Repository map

- `_posts/`: dated blog posts in Markdown.
- `_includes/` and `_layouts/`: reusable Liquid/HTML templates.
- `assets/posts/`: post-specific assets, including D2 sources and their rendered SVGs.
- `build.sh`: renders every D2 source beneath a specified directory.
- `code/`: supporting source-code examples used by posts.
- `_config.yml`: site-wide Jekyll configuration.
- `_site/`: generated site output; do not edit by hand.
- `Gemfile`: Ruby dependencies for local builds.

## Working guidelines

- Keep changes focused on the requested task and preserve unrelated work in the working tree.
- Follow the existing Markdown, YAML, Liquid, HTML, and source-code style in nearby files.
- Give new posts valid Jekyll front matter and name them `YYYY-MM-DD-slug.md` or `YYYY-MM-DD-slug.markdown`.
- Use relative or site-aware links for repository-hosted pages and assets.
- Do not manually modify generated or cached content such as `_site/`, `.jekyll-cache/`, `dist-newstyle/`, or `vendor/`.
- Avoid changing dependency lockfiles unless the task changes dependencies.
- Keep examples under `code/` consistent with the article that references them.

## Diagrams with D2

- Use [D2](https://d2lang.com/) for diagrams created for posts.
- Give each post with diagrams a descriptive directory under `assets/posts/`. For example, diagrams for `_posts/2026-03-17-zippers.markdown` belong in `assets/posts/understanding-zippers/`.
- Treat the `.d2` file as the authoritative, editable source and commit it with the rendered diagram.
- Store each rendered SVG beside its source using the same base name, for example `tree.d2` and `tree.svg`.
- Use descriptive diagram filenames such as `persistent-update.d2` rather than numbered names such as `d1.d2`.
- Prefer descriptive object names and labels so the diagram source remains understandable without rendering it.
- After changing diagrams for a post, regenerate all SVGs in that post's asset directory with:

```sh
./build.sh assets/posts/<name>
```

The script searches the directory recursively, renders centered SVGs with 10 pixels of padding at a preview-friendly scale, and writes each output beside its `.d2` source using the same base name. Keep global alignment, padding, and display sizing in `build.sh` instead of individual D2 sources or HTML `<img>` elements, so diagrams remain consistent and continue to work in Markdown Preview.

- Reference the rendered SVG, not the `.d2` source, with a root-relative Markdown path, for example `![Description](/assets/posts/understanding-zippers/persistent-update.svg)`. Because this site's `baseurl` is empty, this form works both on the published site and in workspace-aware Markdown previews such as VS Code's.
- Do not edit generated SVG markup by hand; make changes in the `.d2` source and regenerate it.

## Useful commands

Run these commands from the repository root:

```sh
bundle install
bundle exec jekyll serve
bundle exec jekyll build
```

For a Haskell example that contains a Cabal project, run its checks from that example's directory, for example:

```sh
cd code/zippers_perf
cabal build all
```

## Verification

- Run `bundle exec jekyll build` after changing posts, layouts, includes, configuration, or dependencies.
- Run `./build.sh assets/posts/<name>` after changing D2 sources for a post.
- Check internal links, image paths, syntax highlighting, and rendered code blocks for content changes.
- Run the narrowest relevant build or test command for changes under `code/`.
- Review `git diff --check` before handing off changes.

## Commit and review notes

- Use short, imperative commit subjects.
- In the handoff, summarize the user-visible change and list the checks that were run.
- Call out any verification that could not be completed and explain why.

## Task-specific notes

Add durable project conventions here as they emerge. More specific `AGENTS.md` files may be added in subdirectories when an area needs different instructions.
