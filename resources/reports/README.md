# Adding a report or presentation

1. Create `YYYY/short-descriptive-name.qmd` by copying the front matter below.
2. Write a concise text summary that remains useful without the binary file.
3. Link the original asset through `documents-base-url`; never hard-code a
   repository owner in the page.
4. Add the page to the matching year in both `index.qmd` and
   `../presentations-reports.qmd`. Do not add individual reports to the main
   book chapters.
5. Add the original file and its manifest record to `opalx-documents`.

This directory is a small nested Quarto website. It renders report detail pages
into the manual site's `resources/reports/` path without adding them to the
book sidebar, chapter numbering, or PDF. Four-digit year directories are
included automatically by `_quarto.yml`.

```yaml
---
title: "Report title"
description: "One-sentence description."
audience: developer
status: current
last-reviewed: "YYYY-MM-DD"
---
```

Use this form for the asset link:

```markdown
[Download the original document]({{< meta documents-base-url >}}/reports/YYYY/category/YYYY-MM-DD-name.pdf)
```
