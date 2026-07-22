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

field_solver_page = ROOT / "user-guide/field-solver/index.qmd"
field_solver_sections = [
  ["## Solver backends {#solver-backends}", "solver-backends"],
  ["### `NONE` {#solver-none}", "solver-none"],
  ["### `FFT` {#solver-fft}", "solver-fft"],
  ["### `OPEN` {#solver-open}", "solver-open"],
  ["### `CG` {#solver-cg}", "solver-cg"],
  ["## `FIELDSOLVER` parameters {#fieldsolver-parameters}", "fieldsolver-parameters"],
  ["## Mesh and particle-in-cell cycle {#mesh-pic-cycle}", "mesh-pic-cycle"],
  ["## Boundary conditions {#boundary-conditions}", "boundary-conditions"],
  ["### Open and periodic boundaries {#open-periodic-boundaries}", "open-periodic-boundaries"],
  ["### Generic all-face Dirichlet boundaries {#generic-dirichlet-boundaries}",
   "generic-dirichlet-boundaries"],
  ["## Space-charge modes {#space-charge-modes}", "space-charge-modes"],
  ["### Monolithic electrostatic mode {#monolithic-mode}", "monolithic-mode"],
  ["### Binned rest-frame mode {#binned-mode}", "binned-mode"],
  ["### Explicit image-charge Dirichlet correction {#explicit-image-charges}",
   "explicit-image-charges"],
  ["### Shifted-Green Dirichlet correction {#shifted-greens-correction}",
   "shifted-greens-correction"],
  ["## Compatibility and selection {#compatibility-selection}", "compatibility-selection"],
  ["## Accuracy, cost, and reproducibility {#accuracy-cost}", "accuracy-cost"]
]

if field_solver_page.file?
  field_solver_text = field_solver_page.read
  previous_position = -1
  field_solver_sections.each do |heading, _anchor|
    position = field_solver_text.index(heading)
    if position.nil?
      errors += error("field-solver is missing required heading: #{heading}")
    elsif position <= previous_position
      errors += error("field-solver headings are out of order at: #{heading}")
    else
      previous_position = position
    end
  end

  {
    "disabled CG backend" => "Cannot use CGSolver yet, not fully implemented.",
    "unavailable P3M backend" => "`P3M` is not an accepted `FIELDSOLVER.TYPE`",
    "mandatory 3D decomposition" => "`PARFFTX`, `PARFFTY`, and `PARFFTZ` are all",
    "uniform boundary restriction" => "Mixed boundary conditions",
    "generic Dirichlet limitation" => "this is **not a usable mode**",
    "shifted-Green backend and binning requirements" =>
      "**requires both `TYPE=OPEN` and a named `BINS` definition**",
    "explicit-image backend caveat" => "current input checks do not reject other backends"
  }.each do |description, required_text|
    unless field_solver_text.include?(required_text)
      errors += error("field-solver is missing #{description}")
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
  unless toc_text.match?(/path:\s*["']\/user-guide\/structures\/index\.html["'][\s\S]*?id:\s*["']binning["']/)
    errors += error("structures sidebar manifest is missing the BINNING anchor")
  end
  unless toc_text.include?("page-toc:structures")
    errors += error("structures sidebar manifest is missing its stable key")
  end
  field_solver_sections.each do |_heading, anchor|
    unless toc_text.match?(/\bid:\s*["']#{Regexp.escape(anchor)}["']/)
      errors += error("field-solver sidebar manifest is missing anchor: #{anchor}")
    end
  end
  %w[
    page-toc:field-solver page-toc:field-solver:backends
    page-toc:field-solver:boundaries page-toc:field-solver:modes
  ].each do |state_key|
    errors += error("field-solver sidebar manifest is missing stable key: #{state_key}") unless toc_text.include?(state_key)
  end
  unless toc_text.match?(/path:\s*["']\/user-guide\/field-solver\/index\.html["']/)
    errors += error("field-solver sidebar manifest has an incorrect rendered path")
  end
else
  errors += error("missing distribution sidebar manifest: #{distribution_toc.relative_path_from(ROOT)}")
end

source_audited_inputs = {
  "user-guide/beam.qmd" => %w[
    PARTICLE MASS CHARGE ENERGY PC GAMMA BCURRENT BFREQ BCHARGE NALLOC SOURCES
    GLOBALPROCESSES DAUGHTERBEAM POLARIZATION
  ],
  "user-guide/tracking.qmd" => %w[
    LINE SOURCES BEAM BEAMS DT DTSCINIT DTAU T0 MAXSTEPS ZSTART ZSTOP STEPSPERTURN
    TIMEINTEGRATOR MAP_ORDER METHOD TURNS FIELDSOLVER BOUNDARYGEOMETRY TRACKBACK
  ],
  "user-guide/options.qmd" => %w[
    ECHO INFO TRACE WARN SEED TELL PSDUMPFREQ STATDUMPFREQ STEPINFOFQ PRINTRANKDISTRFQ
    PSDUMPEACHTURN PSDUMPFRAME SPTDUMPFREQ REPARTFREQ REBINFREQ SCSOLVEFREQ MTSSUBSTEPS
    REMOTEPARTDEL RHODUMP EBDUMP RANKDUMP CSRDUMP AUTOPHASE NUMBLOCKS RECYCLEBLOCKS NLHS
    CZERO RNGTYPE ENABLEHDF5 ENABLEVTK ASCIIDUMP BOUNDPDESTROY BEAMHALOBOUNDARY CLOTUNEONLY
    IDEALIZED LOGBENDTRAJECTORY VERSION MEMORYDUMP HALOSHIFT DELPARTFREQ MINBINEMITTED
    MINSTEPFORREBIN COMPUTEPERCENTILES QM_MODE AGGRESSIVE_STATE_SYNC LOADBALANCINGTHRESHOLD
  ],
  "user-guide/structures/index.qmd" => %w[
    MAXBINS DESIREDWIDTH BINNINGALPHA BINNINGBETA PARAMETER ADAPTIVEBINNING DUMPBINSFILE
    DUMPBINSFREQ TABLEPRINTFREQ
  ],
  "user-guide/field-solver/index.qmd" => %w[
    TYPE BINS NX NY NZ PARFFTX PARFFTY PARFFTZ BCFFTX BCFFTY BCFFTZ GREENSF BBOXINCR
    BCHARGE ZEROFACE_R0Z SHIFTED_GREENS_FUNCTION ZEROFACEPLANEDUMP ZEROFACE_MAXSTEPS
  ]
}

source_audited_inputs.each do |relative, attributes|
  path = ROOT / relative
  unless path.file?
    errors += error("missing source-audited input page: #{relative}")
    next
  end

  text = path.read
  attributes.each do |attribute|
    errors += error("#{relative} is missing input attribute: #{attribute}") unless text.include?("`#{attribute}`")
  end
end

tracking_text = (ROOT / "user-guide/tracking.qmd").read
unless tracking_text.include?("`BEAMS` takes precedence")
  errors += error("tracking page must document BEAMS precedence")
end
unless tracking_text.include?("`RUN` does not register `BEAM`, `BEAMS`, `SOURCES`, or `DISTRIBUTION`")
  errors += error("tracking page must document current RUN ownership")
end

binning_text = (ROOT / "user-guide/structures/index.qmd").read
%w[VELOCITYZ POSITIONZ PZ GAMMAZ].each do |parameter|
  errors += error("binning page is missing parser value: #{parameter}") unless binning_text.include?("`#{parameter}`")
end
unless binning_text.include?("implements only `VELOCITYZ` and `GAMMAZ`")
  errors += error("binning page must distinguish parser values from runtime support")
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
