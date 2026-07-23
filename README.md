# OPALX Documentation

[![Build documentation preview](https://github.com/OPALX-project/opalx-manual/actions/workflows/build.yml/badge.svg)](https://github.com/OPALX-project/opalx-manual/actions/workflows/build.yml)

This repository is the text-first source for the redesigned OPALX manual. It
combines user documentation, physics notes, reference material, developer
guides, and troubleshooting information in one Quarto book.

The historical OPAL manual remains a separate project. OPAL-only chapters,
examples, reports, and presentations are deliberately not included here.

## Preview

Render or preview the organization configuration with:

```sh
quarto render --profile opalx --to html
quarto render resources/reports --profile opalx --to html
quarto preview --profile opalx
```

An ad hoc documents repository can be tested without editing a page:

```sh
cp _quarto.yml.local.example _quarto.yml.local
quarto render --profile opalx --to html
```

Binary documents and large datasets belong in `opalx-documents`. Pages refer
to that repository only through the `documents-base-url` metadata value.

## Validation

```sh
ruby scripts/validate_manual.rb
```

Set `DOCUMENTS_CHECKOUT=../opalx-documents` to verify configurable document
links against a local checkout of the document repository.

The generated C++ API documentation is published separately at the PSI Doxygen
site and is linked through the `doxygen-url` metadata value.

On the rendered website, Quarto persists the selected color scheme and the
manual's small sidebar-state script persists expanded and collapsed sections
between page navigations.
