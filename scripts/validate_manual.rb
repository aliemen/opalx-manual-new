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
  ["## Solver types {#solver-backends}", "solver-backends"],
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

physics_field_solver_page = ROOT / "physics/field-solver/index.qmd"
physics_field_solver_sections = [
  "## Scope and notation {#field-solver-scope}",
  "## Governing electrostatic model {#governing-electrostatic-model}",
  "### Poisson equation {#poisson-equation}",
  "### Self-field force {#self-field-force}",
  "## Particle-mesh discretization {#particle-mesh-discretization}",
  "### Charge deposition {#charge-deposition}",
  "### Mesh solve {#mesh-solve}",
  "### Field reconstruction and interpolation {#field-reconstruction}",
  "## Frames and relativistic transformations {#frames-transformations}",
  "## Boundary conditions and Green functions {#physics-boundary-conditions}",
  "### Periodic boundaries {#physics-periodic-boundaries}",
  "### Open boundaries {#physics-open-boundaries}",
  "### Dirichlet and image-charge boundaries {#physics-dirichlet-boundaries}",
  "## Solver formulations {#solver-formulations}",
  "### Periodic FFT solver {#physics-fft-solver}",
  "### Hockney open-boundary solver {#physics-open-solver}",
  "### Iterative solvers {#physics-iterative-solvers}",
  "## Binned rest-frame space charge {#physics-binned-space-charge}",
  "## Emission and conducting boundaries {#physics-emission-boundaries}",
  "## Numerical accuracy and convergence {#numerical-accuracy-convergence}",
  "### Mesh resolution {#mesh-resolution}",
  "### Particle noise and deposition order {#particle-noise}",
  "### Time-step coupling {#time-step-coupling}",
  "## Domain decomposition and load balancing {#domain-decomposition}",
  "## Current implementation architecture {#field-solver-architecture}",
  "## Verification and benchmarks {#field-solver-verification}",
  "## Assumptions and known limitations {#field-solver-limitations}"
]

if physics_field_solver_page.file?
  physics_field_solver_text = physics_field_solver_page.read
  previous_position = -1
  physics_field_solver_sections.each do |heading|
    position = physics_field_solver_text.index(heading)
    if position.nil?
      errors += error("physics field-solver skeleton is missing heading: #{heading}")
    elsif position <= previous_position
      errors += error("physics field-solver headings are out of order at: #{heading}")
    else
      previous_position = position
    end
  end
  {
    "HTML diagram fallback" => "current-space-charge-class-diagram.png",
    "PDF TikZ diagram" => "current-space-charge-class-diagram.tex",
    "HTML conditional" => 'when-format="html"',
    "PDF conditional" => 'when-format="pdf"',
    "user-guide boundary" => "Field Solver user guide"
  }.each do |description, required_text|
    unless physics_field_solver_text.include?(required_text)
      errors += error("physics field-solver skeleton is missing #{description}")
    end
  end
end

physics_diagram_tex = ROOT / "physics/field-solver/figures/current-space-charge-class-diagram.tex"
physics_diagram_png = ROOT / "physics/field-solver/figures/current-space-charge-class-diagram.png"
if physics_diagram_tex.file?
  diagram_text = physics_diagram_tex.read
  errors += error("embedded field-solver TikZ must not contain a document class") if diagram_text.include?("\\documentclass")
  errors += error("embedded field-solver TikZ must not contain a document wrapper") if diagram_text.include?("\\begin{document}")
  errors += error("embedded field-solver TikZ is missing its tikzpicture") unless diagram_text.include?("\\begin{tikzpicture}")
else
  errors += error("missing embedded field-solver TikZ source")
end
errors += error("missing field-solver HTML diagram fallback") unless physics_diagram_png.file?
unless (ROOT / "includes/tikz-preamble.tex").read.include?("backgrounds")
  errors += error("TikZ preamble is missing the backgrounds library required by the field-solver diagram")
end

input_language_page = ROOT / "user-guide/input-language.qmd"
if input_language_page.file?
  input_language_text = input_language_page.read
  input_language_sections = %w[
    simulation-at-a-glance core-syntax parser-native-structures simulation-definitions
    beamline-definitions time-dependence-definitions tracking-block-structures executable-actions
    execution-order
  ]
  input_language_sections.each do |anchor|
    unless input_language_text.match?(/\{##{Regexp.escape(anchor)}\}/)
      errors += error("input-language is missing ##{anchor}")
    end
  end

  %w[
    BEAM DISTRIBUTION EMISSIONSOURCE EMISSIONSOURCELIST FIELDSOLVER BINNING LINE
    DRIFT CONSTANTEFIELDCAVITY QUADRUPOLE MULTIPOLE MULTIPOLET SOLENOID RFCAVITY
    TRAVELINGWAVE RBEND SBEND VERTICALFFAMAGNET VARIABLE_RF_CAVITY LASER MONITOR
    PROBE MARKER POLYNOMIAL_TIME_DEPENDENCE SINUSOIDAL_TIME_DEPENDENCE
    SPLINE_TIME_DEPENDENCE TRACK RUN ENDTRACK OPTION TITLE CALL ECHO HELP VALUE SELECT
    DUMPEMFIELDS SYSTEM PSYSTEM STOP QUIT
  ].each do |statement|
    unless input_language_text.include?("| `#{statement}`")
      errors += error("input-language catalog is missing registered statement: #{statement}")
    end
  end

  %w[BOOL REAL CONST CONSTANT STRING VECTOR SHARED MACRO IF ELSE WHILE].each do |parser_form|
    unless input_language_text.match?(/`[^`\n]*\b#{Regexp.escape(parser_form)}\b[^`\n]*`/)
      errors += error("input-language catalog is missing parser form: #{parser_form}")
    end
  end

  {
    "source revision" => "d1e762f15a2a",
    "overview cards" => "{.doc-grid}",
    "beam guide" => "[Beam](beam.qmd)",
    "distribution guide" => "beam-distributions.qmd#distribution",
    "element guide" => "elements.qmd#drift",
    "field-solver guide" => "field-solver/index.qmd",
    "binning guide" => "structures/index.qmd#binning",
    "tracking guide" => "[Tracking](tracking.qmd)",
    "options guide" => "[Runtime options](options.qmd)"
  }.each do |description, required_text|
    unless input_language_text.include?(required_text)
      errors += error("input-language is missing #{description}")
    end
  end
end

reports_catalog = ROOT / "resources/presentations-reports.qmd"
if reports_catalog.file?
  reports_text = reports_catalog.read
  unless reports_text.include?("## 2026 {#reports-2026 .unnumbered}")
    errors += error("Presentations and Reports year heading must have a stable anchor and be unnumbered")
  end
end

elements_page = ROOT / "user-guide/elements.qmd"
element_sections = [
  ["## Common element syntax {#common-element-syntax}", "common-element-syntax"],
  ["## `DRIFT` {#drift}", "drift"],
  ["## `CONSTANTEFIELDCAVITY` {#constant-electric-field-cavity}",
   "constant-electric-field-cavity"],
  ["## `QUADRUPOLE` {#quadrupole}", "quadrupole"],
  ["## `MULTIPOLE` {#multipole}", "multipole"],
  ["## `MULTIPOLET` {#multipolet}", "multipolet"],
  ["## `SOLENOID` {#solenoid}", "solenoid"],
  ["## `RFCAVITY` {#rfcavity}", "rfcavity"],
  ["## `TRAVELINGWAVE` {#travelingwave}", "travelingwave"],
  ["## Current limitations {#element-limitations}", "element-limitations"]
]

if elements_page.file?
  elements_text = elements_page.read
  previous_position = -1
  element_sections.each do |heading, _anchor|
    position = elements_text.index(heading)
    if position.nil?
      errors += error("elements is missing required heading: #{heading}")
    elsif position <= previous_position
      errors += error("elements headings are out of order at: #{heading}")
    else
      previous_position = position
    end
  end
  {
    "regression-driven scope" => "every element type found in the current",
    "MULTIPOLE runtime order warning" =>
      "bulk particle kernel applies only indices 0 and 1",
    "strength-error limitation" => "not applied by the current field kernel",
    "RFCAVITY autophase behavior" => "`OPTION.AUTOPHASE>0`",
    "unsupported variable-radius MULTIPOLET mode" =>
      "Variable-radius curved magnets are currently rejected"
  }.each do |description, required_text|
    errors += error("elements is missing #{description}") unless elements_text.include?(required_text)
  end
end

worked_inputs_page = ROOT / "getting-started/worked-inputs.qmd"
worked_input_sections = [
  "## Drift without self-fields {#example-drift}",
  "## Autophased RF cavity {#example-rfcavity}",
  "## Emission with binned open-boundary space charge {#example-space-charge}"
]

if worked_inputs_page.file?
  worked_inputs_text = worked_inputs_page.read
  previous_position = -1
  worked_input_sections.each do |heading|
    position = worked_inputs_text.index(heading)
    if position.nil?
      errors += error("worked-inputs is missing required heading: #{heading}")
    elsif position <= previous_position
      errors += error("worked-input headings are out of order at: #{heading}")
    else
      previous_position = position
    end
  end

  opal_blocks = worked_inputs_text.scan(/^```opal\n(.*?)^```$/m).flatten
  errors += error("worked-inputs must contain exactly three complete OPAL input blocks") unless opal_blocks.length == 3
  opal_blocks.each_with_index do |block, index|
    errors += error("worked input #{index + 1} contains an ellipsis") if block.include?("...")
    %w[FIELDSOLVER DISTRIBUTION EMISSIONSOURCE EMISSIONSOURCELIST BEAM TRACK RUN ENDTRACK QUIT].each do |statement|
      errors += error("worked input #{index + 1} is missing #{statement}") unless block.match?(/\b#{statement}\b/i)
    end
  end
  {
    "drift example" => "D1: DRIFT",
    "RF cavity example" => "Gun: RFCAVITY",
    "autophase explanation" => "performs four refinement passes",
    "constant-field space-charge example" => "Gun: CONSTANTEFIELDCAVITY",
    "binned OPEN solver" => "FSOpen: FIELDSOLVER, TYPE=OPEN, BINS=Bins",
    "shifted-Green correction" => "SHIFTED_GREENS_FUNCTION=TRUE",
    "configurable regression source link" => "meta regression-tests-source-url"
  }.each do |description, required_text|
    errors += error("worked-inputs is missing #{description}") unless worked_inputs_text.include?(required_text)
  end
end

implicit_capture_report = ROOT / "resources/reports/2026/ippl-implicit-this-capture.qmd"
if implicit_capture_report.file?
  implicit_capture_text = implicit_capture_report.read
  {
    "merged IPPL pull request" => "https://github.com/IPPL-framework/ippl/pull/561",
    "implicit member access" => "`this->dview_m`",
    "class-lambda capture semantics" => "`[=, *this]`",
    "host-only layout state" => "`Layout_t* layout_m`",
    "local view capture" => "`KOKKOS_LAMBDA` captures `view` and `expr_` by value",
    "scalar deep copy" => "`Kokkos::deep_copy(dview_m, value)`",
    "constructed expression value" => "const E expr_ = static_cast<const E&>(expr);",
    "separate alignment explanation" => "address different rules",
    "unrelated halo failure" => "`accumulateHalo` segfault"
  }.each do |description, required_text|
    unless implicit_capture_text.include?(required_text)
      errors += error("implicit-this report is missing #{description}")
    end
  end

  {
    "resources/reports/index.qmd" => "2026/ippl-implicit-this-capture.qmd",
    "resources/presentations-reports.qmd" => "reports/2026/ippl-implicit-this-capture.html"
  }.each do |relative, required_link|
    catalog = ROOT / relative
    unless catalog.file? && catalog.read.include?(required_link)
      errors += error("#{relative} is missing the implicit-this report entry")
    end
  end
else
  errors += error("missing implicit-this capture report")
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
  unless toc_text.match?(/id:\s*["']binning["'],\s*text:\s*["']Binning["'],\s*suffix:\s*["']1["']/)
    errors += error("structures sidebar manifest must label BINNING as automatic subsection 1")
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
  element_sections.each do |_heading, anchor|
    unless toc_text.match?(/\bid:\s*["']#{Regexp.escape(anchor)}["']/)
      errors += error("elements sidebar manifest is missing anchor: #{anchor}")
    end
  end
  unless toc_text.include?("page-toc:elements")
    errors += error("elements sidebar manifest is missing its stable key")
  end
  unless toc_text.match?(/path:\s*["']\/user-guide\/elements\.html["']/)
    errors += error("elements sidebar manifest has an incorrect rendered path")
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
  ],
  "user-guide/elements.qmd" => %w[
    TYPE APERTURE L ELEMEDGE WAKEF PARTICLEMATTERINTERACTION X Y Z THETA PHI PSI
    DX DY DZ DTHETA DPHI DPSI OUTFN DELETEONTRANSVERSEEXIT
    GEOMETRY NSLICES EX EY EZ K1 DK1 K1S DK1S KN DKN KS DKS
    TP LFRINGE RFRINGE HAPERT VAPERT MAXFORDER ROTATION EANGLE BBLENGTH ANGLE
    MAXXORDER VARRADIUS ENTRYOFFSET SCALING_MODEL FMAPFN FAST
    VOLT DVOLT FREQ LAG DLAG APVETO RMIN RMAX PDIS GAPWIDTH PHI0 DESIGNENERGY
    PHASE_MODEL AMPLITUDE_MODEL FREQUENCY_MODEL NUMCELLS MODE
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
