# Branch Closures, Deposit Retention, and the Credit Channel in the Digital Era — Project Context

**Paper**: Branch Closures, Deposit Retention, and the Credit Channel in the Digital Era
**Slug**: hnrs-branch-closure-deposit-retention
**Description**: Studies how branch closures affect deposit reallocation and local credit supply, contrasting pre-digital and digital eras. Central finding: organic closures in recent years retain deposits and produce muted lending spillovers, unlike the M&A-driven closures emphasized in prior work.
**Coauthors**: Philip Strahan (Collins Professor of Finance, Boston College Carroll School of Management), Charlotte, Rajesh

## Project Layout

```
data/raw/                     ← raw source data (never modified)
data/constructed/             ← intermediate constructed datasets
code/common.R                 ← shared libraries, paths, global options
code/approach-[name]/         ← early-stage: one subfolder per analytical approach
code/sample-construction/     ← plain .R scripts that build analytical samples
code/result-generation/       ← .qmd documents that generate tables and figures
code/archives/                ← old scripts (not sourced)
latex/main.tex                ← master LaTeX document
latex/main.bib                ← BibTeX references
latex/figures/                ← figure output (.png, .pdf)
latex/tables/                 ← table output (.tex)
latex/sections/               ← section .tex files (\input{} from main.tex)
latex/build/                  ← pdflatex output (gitignored)
docs/_config.yml              ← Jekyll config for GitHub Pages
docs/index.md                 ← snapshot registry (GitHub Pages landing page)
docs/snapshots/               ← versioned result snapshots (one folder per run)
docs/slides/                  ← presentation files
docs/memos/                   ← revision plans, referee responses, todo
related-papers/               ← downloaded PDFs (gitignored)
correspondence/               ← emails and agent-generated reports
scripts/                      ← new-project initialization scripts
```

## Paper-Specific Context

### Identification Strategy

Two parallel quasi-experimental designs:

1. **Incumbent (competitor-closure) design:** County-year exposure to competitor branch closures as treatment. Measures whether incumbent banks absorb deposits when competitors close nearby branches.
2. **Own-closure design:** Closing bank's own closure intensity as treatment. Measures deposit retention at remaining branches.

Key contrast: pre-digital era (pre-2012) vs. digital era (post-2012). Central claim: deposit reallocation to incumbents and credit spillovers attenuate post-2012 as digital banking substitutes for physical branch access. Event-study designs (Sun & Abraham) validate pre-trend absence.

M&A-driven closures are excluded; only organic closures studied.

### Key Variables

**Outcomes:** Branch deposit growth (incumbent analysis); deposit growth at remaining branches (own-closure analysis); mortgage origination growth (HMDA); small-business lending growth (CRA).

**Treatments:** County-level competitor closure exposure; bank's own closure intensity.

**Key heterogeneity dimensions:** Closing-bank digital adoption (mobile app presence); incumbent bank size (top-4, large, small); county-level mobile subscription rates (local digital infrastructure).

### Sample

- Units: branch-year (incumbent analysis) and bank-county-year (own-closure and lending analysis)
- Period: approximately 2001–2025
- Sources: FDIC Summary of Deposits, HMDA, CRA, proprietary branch closure panel, bank app reviews data

### Data Sources

Raw data is stored externally (OneDrive and empirical data drives) — not in `data/raw/`. Constructed panels are saved to `data/` as `.rds` files and are gitignored. See `code/v20260418/NOTES.md` for current external data paths.

---

## Early-Stage Workflow

### Code Exploration: Named Approach Subfolders

When the paper direction is not yet settled, keep competing analytical approaches in separate named subfolders directly under `code/`:

```
code/
├── approach-a-did/         ← DiD specification explorations
│   ├── 01_sample_20260401.R
│   └── 02_main_spec_20260403.R
├── approach-b-iv/          ← IV alternative
│   └── 01_first_stage_20260405.R
├── sample-construction/    ← shared data prep (used by all approaches)
├── result-generation/      ← promoted scripts for the winning approach
├── archives/               ← discarded approaches (move here, don't delete)
└── common.R                ← shared libraries and settings
```

**Conventions:**

- Name subfolders `approach-[descriptor]` (e.g., `approach-did`, `approach-iv-shift-share`).
- Scripts inside follow the same date-suffix convention: `01_desc_20260401.R`.
- Each approach folder may have its own `common_[slug].R` if it needs settings that differ from `code/common.R`.
- When an approach is chosen: move its scripts into `code/result-generation/`, archive the rest to `code/archives/`.
- When an approach is abandoned: move its folder to `code/archives/` — do not delete.

### Result Snapshots

Use `/skills/snapshot-results "slug"` to capture the current `latex/tables/` and `latex/figures/` into a versioned report under `docs/snapshots/`:

```
docs/snapshots/
└── 20260409-approach-a-baseline/
    ├── index.md        ← report with embedded figures and rendered tables
    ├── figures/        ← copies of latex/figures/*.png and *.pdf
    └── tables/         ← markdown-rendered versions of latex/tables/*.tex
```

**When to snapshot:**

- After completing a meaningful set of results (baseline spec, first pass at robustness).
- Before changing a specification that will alter existing outputs.
- When sharing preliminary findings with coauthors.

**Workflow:**

```
/skills/snapshot-results "approach-a-baseline"
# → creates docs/snapshots/20260409-approach-a-baseline/
# → updates docs/index.md registry
# → fill in the Summary section in index.md
# → git add docs/ && git commit && git push
```

### GitHub Pages (one-time setup)

1. Go to repo **Settings → Pages → Source**: Deploy from a branch → Branch: `main`, Folder: `/docs`.
2. After the first push to `docs/`, the site is live at `https://[username].github.io/[repo]/`.
3. The landing page (`docs/index.md`) lists all snapshots. Each snapshot links to its own `index.md` with embedded figures and tables.

---

## Runtime Paths

> **IMPORTANT:** Before running any R or Python command, verify these paths are filled in. If either is still a placeholder, stop and ask the user to provide the correct path before proceeding.

```
R_EXE           = "C:/Program Files/R/R-4.5.3/bin/R.exe"
PYTHON_VENV     = C:/envs/.basic_venv
PYTHON_VENV_DOCLING = C:/envs/.docling_venv
```

**Rules:**

- Always invoke R via `R_EXE` (e.g., `"$R_EXE" script.R`), never rely on `Rscript` or `R` being on PATH.
- Always activate the venv before running Python: source `$PYTHON_VENV/Scripts/activate` (Windows) or `$PYTHON_VENV/bin/activate` (Unix), then call `python`.
- **Exception:** When running `related-papers/convert_batch.py`, use `PYTHON_VENV_DOCLING` (`C:/envs/.docling_venv`) instead of `PYTHON_VENV`.
- If `R_EXE` is still `[PLACEHOLDER...]`, do **not** attempt to run the script — prompt the user: *"Please set `R_EXE` in CLAUDE.md before I can run this."*

---

## R Coding Standards

### Core Principles

- **Never render** `.qmd` or `.Rmd` files during script execution — run regressions and output tables/figures by sourcing `.R` scripts or running Quarto CLI explicitly.
- Place all `library()` calls at the very top of each script.
- Reset the environment with `rm(list = ls())` as the first line of every standalone script.
- Use **relative paths** exclusively. In Quarto/R Markdown documents, construct paths with `here::here()`. In plain `.R` scripts, use paths relative to the project root (e.g., `"data/raw/file.csv"`).
- Append date suffixes (`YYYYMMDD`) to new script filenames (e.g., `01_build_panel_20260406.R`).

### Project Organization

| Folder                      | Contents                                                                       |
| --------------------------- | ------------------------------------------------------------------------------ |
| `code/sample-construction/` | Plain `.R` scripts that read from `data/raw/` and write to `data/constructed/` |
| `code/result-generation/`   | `.qmd` documents with `type: source` that produce tables and figures           |
| `code/common.R`             | Shared libraries, paths, ggplot2 theme, fixest globals                         |

### Data Management

- Raw data lives in `data/raw/` and is **never modified**.
- Processed/constructed datasets go to `data/constructed/`.
- Define `data_path <- "data/constructed/"` near the top of each analysis script.
- Generate timestamped output filenames: `format(Sys.time(), "%Y%m%d_%H%M%S")`.
- Include a comment in each script indicating which upstream script generated any imported dataset.

### Figure & Table Export

- Figures → `latex/figures/` as timestamped `.png` files with `bg = "transparent"`.
- Tables → `latex/tables/` as `.tex` files with matching timestamps.
- Control exports with logical flags at the top of each script:
  
  ```r
  save_figures <- TRUE
  save_tables  <- TRUE
  ```

### Visualization Standards

Apply `theme_custom()` (defined in `code/common.R`) to all ggplot2 plots. Use these brand colors:

| Name           | Hex         |
| -------------- | ----------- |
| Primary blue   | `"#012169"` |
| Primary gold   | `"#f2a900"` |
| Accent gray    | `"#525252"` |
| Positive green | `"#15803d"` |
| Negative red   | `"#b91c1c"` |

### Econometric Modeling

- Use the `fixest` package for all panel regressions.
- Define global formula macros with `setFixest_fml()` and global output options with `setFixest_etable()` **once** in `code/common.R`. Reuse them across analysis files — do not redefine per script.
- Store model results in named lists (e.g., `r <- list(); r$baseline <- feols(...)`).

### Quarto Documents

- Use `type: source` in the Quarto YAML front matter so the document runs as a script without rendering to HTML/PDF.
- Suppress warnings and messages by default in chunk options.
- Do not knit/render `.qmd` files to check results — source them or run them via `quarto run`.

---

## Python Coding Standards

### Exploratory Display Rule

When displaying regression results or small DataFrames inline (exploratory snippets, intermediate diagnostics, checking results), use **plain-text formatted tables printed to stdout** — not Matplotlib pop-ups. This keeps results visible in the Claude Code conversation window without switching windows.

**Regression table format** (use this pattern for pyfixest results):

```python
coef_vars    = ["treatment_var", "control1", "control2"]   # ALL variables — treatment + controls
var_labels   = ["Treatment", "Control 1", "Control 2"]
header_labels = [lbl for lbl, m in models if m is not None]
valid_models  = [m  for lbl, m in models if m is not None]

print("\n" + "=" * 70)
print("Table Title")
print("FE: ... | SE clustered at ...")
print("=" * 70)
print(f"{'':25s}" + "".join(f"{h:>15s}" for h in header_labels))
print("-" * 70)
for var, lbl in zip(coef_vars, var_labels):
    coef_row = f"{lbl:25s}"
    se_row   = f"{'':25s}"
    for m in valid_models:
        try:
            c = m.coef()[var]; s = m.se()[var]; p = m.pvalue()[var]
            coef_row += f"{c:>+14.4f}{stars(p):1s}"
            se_row   += f"{'(' + f'{s:.4f}' + ')':>15s}"
        except KeyError:
            coef_row += f"{'—':>15s}"; se_row += f"{'':>15s}"
    print(coef_row)
    print(se_row)
print("-" * 70)
n_row = f"{'N':25s}"
for m in valid_models:
    try:    n_row += f"{int(m._N):>15,}"
    except: n_row += f"{'—':>15s}"
print(n_row)
print(f"{'FE':25s}" + f"{'<fe_spec>':>15s}" * len(valid_models))
print("=" * 70)
```

**Always show all controls** in the table — not just the treatment variable. Every row in `coef_vars` / `var_labels` appears, including controls.

**Show intermediate results before moving on.** When diagnosing a problem (e.g., testing two normalization variants, comparing treatment specs), print the numbers for each variant before drawing a conclusion and changing the code. Do not skip to the final result without showing intermediates.

**When NOT to use:** Never embed `plt.show()` pop-outs inside saved `.py` scripts. Text table prints inside saved scripts are fine.

---

## Skills & Agents

Skills and agents live in `.claude/commands/` (symlinked from ai-vault in project repositories).
Invoke via slash commands in Claude Code:

**Skills:**

- `/skills/snapshot-results` — snapshot current tables & figures into `docs/snapshots/` for GitHub Pages sharing
- `/skills/latex-compile` — compile LaTeX to PDF (pdflatex, no latexmk)
- `/skills/write-section` — write a paper section as a LaTeX file
- `/skills/latex-preflight-check` — pre-submission QA checklist
- `/skills/latex-figure-inserter` — insert a figure environment into a .tex file
- `/skills/latex-table-inserter` — insert a table environment into a .tex file
- `/skills/academic-paragraph-inserter` — insert a prose paragraph at a line number
- `/skills/academic-introduction-evaluator` — evaluate introduction against JF/RFS standards
- `/skills/table-figure-descriptions` — generate table/figure notes (Journal of Finance style)
- `/skills/figure-table-crosscheck` — audit in-text numbers against table values
- `/skills/bib-validator` — validate BibTeX entries against Google Scholar
- `/skills/sanity-check` — generate R data sanity-check script and report
- `/skills/pipeline-audit` — retrospective code-simplicity audit: maps every reported result to the code that produces it, identifies dead code and unnecessary complexity, and produces a simplification report

**Agents:**

- `/agents/finance-paper-reviewer` — full pre-submission review (6 sub-agents in parallel)
- `/agents/literature-downloader` — acquire PDFs and convert to markdown (3 phases: `seed`, `expand`, `finalize`)
- `/agents/literature-reviewer` — build .bib, summarize papers, write literature review (run after literature-downloader)
- `/agents/ai-detector` — detect LLM fingerprints and robotic prose
- `/agents/harsh-editor` — adversarial editorial review of paper vs. code
- `/agents/professor-robustness-check` — quick robustness replication from raw data
- `/agents/referee2-audit` — systematic 5-audit replication and code review
- `/agents/referee-response-evaluator` — evaluate and improve referee response letters
- `/agents/academic-paper-writer` — draft paper sections with IMRAD structure

---

## Output Style & Formatting Rules

### Professional Mode (Outward-Facing)

**Condition:** Task involves editing/generating content in `.tex`, `.bib`, or `.md` files, or drafting emails or academic prose.

- Ignore Caveman instructions entirely.
- Use professional academic English suitable for a Finance Professor: formal grammar, precise terminology, standard punctuation.
- Ensure all mathematical notation and citations strictly follow professional standards.

### Caveman Mode (Internal Communication)

**Condition:** Providing explanations, debugging code, or responding in the chat interface.

- Follow the Caveman protocol for token efficiency.
- Minimalist, no-fluff style. Technical accuracy and speed over prose.

**Examples:**

- "Why is my fixest regression failing?" → Caveman explanation.
- "Draft the methodology section in paper.tex" → Formal academic prose.

---

## LaTeX Conventions

- Output directory for pdflatex: `latex/build/`
- Figures referenced as `\includegraphics{figures/filename}` (graphicspath set in `latex/main.tex`)
- Tables `\input{}`-ed from `latex/tables/` or inline in section files
- Section files: `latex/sections/<section>/<section>_current.tex` (`\input{}`-ed from `main.tex`)
- Never edit `latex/build/` contents directly
- Compile sequence: `pdflatex → bibtex → pdflatex → pdflatex` (all run from `latex/` directory)
