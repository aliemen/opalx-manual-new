# OPALX manual contribution rules

## Scope

- This repository is the text-first source for the current OPALX manual. Treat
  current OPALX source and tests as authoritative. Retain legacy OPAL only where
  a User Guide page intentionally provides a version comparison.
- Keep writing concise and user-oriented. Put detailed physics in `physics/`
  and implementation guidance in `developer-guide/`.
- Do not commit generated `_site/` or `.quarto/` content.

## Manual pages

- Every substantive `.qmd` page needs `title`, `description`, `audience`,
  `status`, and `last-reviewed` front matter. Valid audiences are `user`,
  `developer`, and `physics`; valid statuses are `current`, `experimental`,
  `planned`, and `archived`.
- Add normal chapters to the appropriate location in `_quarto.yml`.
- Use relative links for manual pages and metadata for repository links. Never
  hard-code a documents URL in a page:

  ```markdown
  [Download]({{< meta documents-base-url >}}/reports/2026/bugs/example.pdf)
  ```

## OPAL and OPALX variants

- Put current-only material in `::: {.feature-opalx}` and retained legacy
  material in `::: {.feature-opal}`. Leave genuinely shared prose outside both
  blocks. A page gets the OPALX/OPAL/Both selector only when it contains both.
- On dual pages, make OPALX source behavior authoritative. Keep ambiguous
  differences in separate blocks instead of silently merging them.
- If an OPAL interface has no current OPALX equivalent, the OPALX block must
  state clearly that it is unavailable or not yet available.
- Use unique, stable heading IDs in each variant. Add variant metadata to the
  manifest in `assets/scripts/sidebar-page-toc.html` for pages with a custom
  left subsection menu.

## Resources and large files

For each report or presentation:

1. Add an unnumbered summary at `resources/reports/YYYY/<slug>.qmd`.
2. Add it, newest first, to both `resources/presentations-reports.qmd` and
   `resources/reports/index.qmd`. Do not add detail pages to `_quarto.yml`.
3. Store the original in `OPALX-project/opalx-documents`, using
   `<category>/<year>/...`, for example `reports/2026/bugs/` or
   `presentations/2026/features/`.
4. Use lowercase filenames, prefixed with `YYYY-MM-DD-` when known. Add the
   file and its SHA-256 metadata to `opalx-documents/manifest.yml`; ensure Git
   LFS tracks binary formats.

PDFs, Office files, archives, media, datasets, and other large artifacts belong
in `opalx-documents`. This manual may contain text, source diagrams, and raster
figures no larger than 500 KiB.

## Checks

```sh
DOCUMENTS_CHECKOUT=../opalx-documents ruby scripts/validate_manual.rb
(cd ../opalx-documents && ruby scripts/validate_repository.rb)
quarto render --profile opalx --to html
quarto render resources/reports --profile opalx --to html
git diff --check
```
