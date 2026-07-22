#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "set"
require "yaml"

ROOT = Pathname.new(__dir__).parent.expand_path
CONFIG = YAML.safe_load(File.read(ROOT / "_quarto.yml"), permitted_classes: [], aliases: false)
REQUIRED_METADATA = %w[title description audience status last-reviewed].to_set
AUDIENCES = %w[user developer physics].to_set
STATUSES = %w[current experimental planned archived].to_set
BANNED_SUFFIXES = %w[.pdf .ppt .pptx .doc .docx .xls .xlsx .zip .7z .tgz .gz .xz .mp4 .mov].to_set
RASTER_SUFFIXES = %w[.png .jpg .jpeg .webp .gif].to_set

def chapter_paths(items)
  items.flat_map do |item|
    if item.is_a?(String)
      [item]
    elsif item.is_a?(Hash)
      parent = item["part"] || item["section"] || item["href"]
      parent_path = parent.is_a?(String) && parent.match?(/\.qmd?\z/) ? [parent] : []
      children = item["chapters"] || item["contents"] || []
      parent_path + chapter_paths(children)
    else
      []
    end
  end
end

def front_matter(path)
  text = path.read
  return {} unless text.start_with?("---\n")

  closing = text.index("\n---\n", 4)
  return {} unless closing

  YAML.safe_load(text[4...closing], permitted_classes: [], aliases: false) || {}
end

def error(message)
  warn "error: #{message}"
  1
end

errors = 0
chapters = chapter_paths(CONFIG.dig("book", "chapters"))
report_pages = [ROOT / "resources/reports/index.qmd"] +
               ROOT.glob("resources/reports/[0-9][0-9][0-9][0-9]/*.qmd")
substantive_pages = (chapters.map { |relative| ROOT / relative } + report_pages).uniq

chapters.each do |relative|
  path = ROOT / relative
  unless path.file?
    errors += error("missing chapter: #{relative}")
  end
end

substantive_pages.select(&:file?).each do |path|
  relative = path.relative_path_from(ROOT)
  metadata = front_matter(path)
  missing = REQUIRED_METADATA - metadata.keys.to_set
  errors += error("#{relative} is missing metadata: #{missing.to_a.sort.join(', ')}") unless missing.empty?
  errors += error("#{relative} has invalid audience: #{metadata['audience']}") unless AUDIENCES.include?(metadata["audience"])
  errors += error("#{relative} has invalid status: #{metadata['status']}") unless STATUSES.include?(metadata["status"])
end

ROOT.glob("**/*", File::FNM_DOTMATCH).select(&:file?).each do |path|
  next if path.each_filename.any? { |part| %w[.git .quarto _site _external].include?(part) }

  relative = path.relative_path_from(ROOT)
  suffix = path.extname.downcase
  errors += error("binary document belongs in opalx-documents: #{relative}") if BANNED_SUFFIXES.include?(suffix)
  if RASTER_SUFFIXES.include?(suffix) && path.size > 512_000
    errors += error("raster asset exceeds 500 KiB: #{relative} (#{path.size} bytes)")
  end

  next unless suffix == ".qmd"

  text = path.read
  if text.match?(%r{https://github\.com/(aliemen|OPALX-project)/opalx-documents})
    errors += error("hard-coded documents repository URL in #{relative}; use documents-base-url metadata")
  end
end

distribution_page = ROOT / "user-guide/beam-distributions.qmd"
distribution_toc = ROOT / "assets/scripts/sidebar-page-toc.html"
distribution_sections = [
  ["## `EMISSIONSOURCE` {#emissionsource}", "emissionsource"],
  ["## `EMISSIONSOURCELIST` {#emissionsourcelist}", "emissionsourcelist"],
  ["## `DISTRIBUTION` {#distribution}", "distribution"],
  ["### `GAUSS` {#gauss}", "gauss"],
  ["### `MULTIVARIATEGAUSS` {#multivariategauss}", "multivariategauss"],
  ["### `FLATTOP` {#flattop}", "flattop"],
  ["### `OPALFLATTOP` {#opalflattop}", "opalflattop"],
  ["### `FROMFILE` {#fromfile}", "fromfile"],
  ["### `EMITTEDFROMFILE` {#emittedfromfile}", "emittedfromfile"],
  ["## Reproducibility and current limitations {#reproducibility-limitations}",
   "reproducibility-limitations"]
]

if distribution_page.file?
  distribution_text = distribution_page.read
  previous_position = -1
  distribution_sections.each do |heading, _anchor|
    position = distribution_text.index(heading)
    if position.nil?
      errors += error("beam-distributions is missing required heading: #{heading}")
    elsif position <= previous_position
      errors += error("beam-distributions headings are out of order at: #{heading}")
    else
      previous_position = position
    end
  end
  unless distribution_text.include?("Accepted but currently ignored")
    errors += error("beam-distributions must flag parser-accepted parameters that are ignored")
  end
  %w[BINOMIAL GAUSSMATCHED MULTIGAUSS].each do |legacy_type|
    if distribution_text.match?(/`#{legacy_type}`/)
      errors += error("beam-distributions contains legacy-only type: #{legacy_type}")
    end
  end
end

if distribution_toc.file?
  toc_text = distribution_toc.read
  distribution_sections.each do |_heading, anchor|
    unless toc_text.match?(/\bid:\s*["']#{Regexp.escape(anchor)}["']/)
      errors += error("distribution sidebar manifest is missing anchor: #{anchor}")
    end
  end
  %w[page-toc:beam-distributions page-toc:beam-distributions:distribution].each do |state_key|
    errors += error("distribution sidebar manifest is missing stable key: #{state_key}") unless toc_text.include?(state_key)
  end
else
  errors += error("missing distribution sidebar manifest: #{distribution_toc.relative_path_from(ROOT)}")
end

if ENV["DOCUMENTS_CHECKOUT"] && !ENV["DOCUMENTS_CHECKOUT"].empty?
  checkout = Pathname.new(ENV["DOCUMENTS_CHECKOUT"]).expand_path
  abort "error: DOCUMENTS_CHECKOUT is not a directory: #{checkout}" unless checkout.directory?

  ROOT.glob("**/*.qmd").each do |path|
    path.read.scan(/\{\{<\s*meta\s+documents-base-url\s*>\}\}\/([^\s\)\"']+)/).flatten.each do |destination|
      errors += error("document link target does not exist: #{destination}") unless (checkout / destination).file?
    end
  end
end

abort "manual validation failed with #{errors} error(s)" unless errors.zero?

puts "validated #{chapters.length} chapters and the text-only asset policy"
