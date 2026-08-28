# AGENTS.md

## Project overview

This repository contains the source for a Jekyll site published with GitHub Pages. Blog posts live in `_posts/`, shared markup lives in `_includes/` and `_layouts/`, and supporting code examples live in `code/`.

## Repository map

- `_posts/`: dated blog posts in Markdown.
- `_includes/` and `_layouts/`: reusable Liquid/HTML templates.
- `blog/`: the blog landing page published at `/blog/`.
- `assets/posts/`: post-specific assets, including D2 sources and their rendered SVGs and PNGs.
- `build.sh`: renders every D2 source beneath a specified directory and prepares DEV.to Markdown for its post.
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
- Give each post with diagrams a descriptive directory under `assets/posts/`. For example, diagrams for `_posts/2026-03-17-zippers.md` belong in `assets/posts/understanding-zippers/`.
- Treat the `.d2` file as the authoritative, editable source and commit it with the rendered diagrams.
- Store each rendered SVG and PNG beside its source using the same base name, for example `tree.d2`, `tree.svg`, and `tree.png`.
- Use descriptive diagram filenames such as `persistent-update.d2` rather than numbered names such as `d1.d2`.
- Prefer descriptive object names and labels so the diagram source remains understandable without rendering it.
- After changing diagrams for a post, regenerate all SVGs in that post's asset directory with:

```sh
./build.sh assets/posts/<name>
```

The script searches the directory recursively, renders centered SVGs at `0.75` scale and DEV.to-compatible PNGs at `0.4` scale with 10 pixels of padding, and writes each output beside its `.d2` source using the same base name. Keep global alignment, padding, and display sizing in `build.sh` instead of individual D2 sources or HTML `<img>` elements, so diagrams remain consistent and continue to work in Markdown Preview.

When exactly one post references the asset directory, the script also writes `dev.to.markdown` there. This generated, ignored file is a copy of the post with base-path-aware Markdown image links replaced by absolute URLs based on `url` and `baseurl` in `_config.yml`; SVG image extensions are changed to PNG for DEV.to compatibility.

- Reference the rendered SVG, not the `.d2` source, with a base-path-aware Markdown path, for example `![Description]({{ "/assets/posts/understanding-zippers/persistent-update.svg" | relative_url }})`.
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
