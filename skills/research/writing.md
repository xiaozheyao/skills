# Paper Writing

How to structure, draft, and submit a research paper for systems or ML venues.

---

## Critical rules

1. **Figures and tables first.** Finalise every figure and table before writing prose. The
   story is determined by the data; prose explains figures, not the other way around.
2. **Write for the skimming reviewer.** Abstract, introduction, and every figure caption
   must be self-contained. A reviewer reading only these four things should understand
   the full paper.
3. **One claim per paragraph, one key message per figure.** If a paragraph makes two
   points, split it. If a figure needs two sentences to state its takeaway, simplify it.
4. **Never bury the lead.** State the core contribution in the first paragraph of the
   introduction, not at the end.
5. **Related work is not a citation dump.** Group prior work by theme, explain the
   limitation of each theme, and state precisely where your work sits.
6. **Every number in the paper must be reproducible** from the exact scripts and configs
   checked into the repository at submission time.

---

## Writing order

Follow this order — it forces you to think about the argument before the words:

1. **Outline the story** — one bullet per section, one sub-bullet per paragraph.
2. **Make all figures and tables** from real data.
3. **Write captions** for every figure and table (complete sentences, self-contained).
4. **Write the evaluation section** — you know exactly what you measured.
5. **Write the design / system section** — explain what produces those numbers.
6. **Write the introduction** — now that the whole paper exists, the intro writes itself.
7. **Write the abstract** — last, as a compression of the introduction.
8. **Write related work** — place it after evaluation or just before conclusion.
9. **Write the conclusion** — 1–2 paragraphs summarising contributions and future work.
10. **Revise top-down** — global structure, then section structure, then paragraphs, then sentences.

---

## Paper structure

### Standard section order (systems / ML systems)

| # | Section | Purpose |
|---|---------|---------|
| — | Abstract | 150–250 words; 4-sentence formula (see below) |
| 1 | Introduction | Problem, gap, approach, contributions |
| 2 | Background / Motivation | Evidence the problem is real and hard; set up vocabulary |
| 3 | Design / System | What you built and why each decision was made |
| 4 | Implementation | Key implementation details that affect results |
| 5 | Evaluation | Experimental setup, main results, ablations |
| 6 | Related Work | Themes of prior work and your positioning |
| 7 | Conclusion | Summary + forward-looking one paragraph |

- **Background is optional** for short papers — fold it into the introduction if it fits.
- **Related work placement**: after evaluation is fine for systems papers (readers understand your work first, then comparisons make sense). Some venues prefer it after the introduction; check reviewer expectations.
- **Implementation is optional** — fold into Design if it adds nothing to the argument.

---

## Abstract formula

Four sentences, strictly in this order:

```
[Context]      The <domain> has seen <trend/challenge>.
[Problem]      However, <specific unsolved problem> because <root cause>.
[Approach]     We present <name>, a <what it is> that <key mechanism>.
[Result]       <Name> achieves <quantified result> over <baseline> on <workload/benchmark>.
```

Example:
> Large-scale deep learning clusters increasingly face resource fragmentation as jobs
> with heterogeneous GPU demands compete for fixed hardware pools. However, existing
> schedulers waste up to 30% of available GPU-hours because they treat jobs as
> monolithic, ignoring internal parallelism structure. We present Seren, a
> structure-aware scheduler that decomposes jobs into pipeline stages and packs them
> jointly across nodes. Seren reduces average job completion time by 2.3× and
> increases cluster utilisation by 28% compared to the state-of-the-art scheduler on
> a 1,000-GPU production trace.

**Avoid** in abstracts: vague claims ("significantly better"), future tense for completed
work, undefined acronyms, citations.

---

## Introduction formula

Seven paragraphs, each with a single job:

| Para | Job | Length |
|------|-----|--------|
| 1 — Hook | Why does this problem matter right now? Make it concrete: a number, a trend, a failure mode. | 3–5 sentences |
| 2 — Problem | State the specific technical problem. End with a one-sentence problem statement. | 3–5 sentences |
| 3 — Inadequacy of prior work | What do existing approaches do? Why are they insufficient? Be specific, not vague. | 3–5 sentences |
| 4 — Key insight | The core insight that makes your approach possible. One sentence, in bold or italics. | 2–4 sentences |
| 5 — Approach | What you built, at one level of abstraction. Not implementation detail, not a spec sheet. | 4–6 sentences |
| 6 — Results | Quantified highlights. Three to five numbers. Name baselines and workloads. | 3–5 sentences |
| 7 — Contributions | Bulleted list of 3–5 concrete contributions. Start each with a verb. | — |

**Contribution bullets** should be specific and falsifiable:
```
We make the following contributions:
• We identify <new observation> through analysis of <X> production traces (§2).
• We design <component>, which <mechanism> to achieve <property> (§3).
• We implement <name> and show it achieves <result> vs. <baseline> (§5).
• We release the implementation and traces at <URL>.
```

Avoid: "We propose a novel framework." (What does it do?) "We show our system is better."
(Better at what, by how much, than whom?)

---

## Motivation / Background section

Goals: (1) convince the reader the problem is real, (2) establish vocabulary and a mental
model, (3) set up the design choices you will make later.

Structure:
1. **Empirical evidence** that the problem exists — a figure, a trace analysis, a
   measurement study. Label it and refer back to it throughout the paper.
2. **Root cause analysis** — why does the problem occur? Identify 2–3 causes.
3. **Requirements** derived from the root causes — these become the criteria against which
   you evaluate your design in §Evaluation.

Rule: every design decision in §Design should map back to a requirement stated here.

---

## Design / System section

Structure each sub-section as: **Challenge → Decision → Justification**.

```
### 3.1 <Component Name>

<One-sentence statement of what this component does.>

**Challenge.** <Why is this hard? What naïve approaches fail and why?>

**Design.** <What you do, in concrete terms. Include a figure.>

**Rationale.** <Why this design satisfies the requirement stated in §Background.>
```

Tips:
- Draw a system architecture diagram as the first figure of this section.
- Annotate the diagram with component names used in prose — labels must match exactly.
- Distinguish *mechanism* (what it does) from *policy* (parameter choices). Put policies
  in §Evaluation or §Implementation, not §Design.

---

## Evaluation section

### Setup sub-section (always first)

Cover in this exact order:
1. **Testbed** — hardware, scale, topology.
2. **Workloads / Datasets** — where they come from, why they are representative.
3. **Baselines** — one sentence per baseline explaining what it is and why it was chosen.
4. **Metrics** — define each metric precisely (e.g., "JCT: wall-clock time from job
   submission to last task completion").
5. **Methodology** — number of runs, seed policy, how variance is reported.

### Main results sub-section

- Lead with the headline number in the first sentence.
- One figure per claim. Do not combine unrelated results into one figure.
- Walk through the figure in prose: "In Figure 5, Seren (blue, solid) reduces median JCT
  by 2.3× over the next-best baseline (Tiresias, orange, dashed) across all load levels."
- Explain *why* the result is what it is — do not just restate the numbers.

### Ablation sub-section

Each ablation disables or replaces one component and measures the impact.
Structure: one row per ablation variant, presented as a table or grouped bar chart.

| Variant | What is disabled | Expected impact | Actual impact |
|---------|-----------------|-----------------|---------------|
| w/o component A | ... | ... | ... |

Rule: the full system must be the best-performing row. If removing a component helps,
either your design is wrong or your ablation is.

### Sensitivity sub-section (optional but valued)

Show how performance varies over key parameters (cluster size, job arrival rate,
model size). Demonstrate the system is robust, not tuned to one sweet spot.

---

## Related Work section

### Structure

Group papers into 3–6 thematic clusters. For each cluster:
1. Name the theme (as a sub-section heading or bold phrase).
2. Cite 3–6 representative papers.
3. State in one sentence what this theme achieves.
4. State in one sentence why it is insufficient for your problem.

End with one paragraph explicitly positioning your work:
> Unlike [X], which does <A>, and [Y], which does <B>, our work addresses <C> by <D>.
> To our knowledge, Seren is the first system to <unique claim>.

### What to avoid

- Citing papers you have not read. Every citation should be defensible in a rebuttal.
- Dismissing related work as "naive" without a technical argument.
- Omitting a closely related concurrent paper to avoid comparison. Reviewers will notice.

---

## LaTeX conventions

### Structure

```latex
% Recommended package set for IEEE / USENIX / ACM papers
\usepackage{booktabs}       % \toprule, \midrule, \bottomrule in tables
\usepackage{microtype}      % better line breaking, fewer overfull hboxes
\usepackage{hyperref}       % clickable cross-refs (load last or near last)
\usepackage{cleveref}       % \cref{fig:foo} → "Figure 1" automatically
\usepackage{xspace}         % \newcommand{\sysname}{Seren\xspace}
\usepackage{subcaption}     % subfigures: \begin{subfigure}
\usepackage{siunitx}        % \SI{2.3}{\times} for consistent number formatting
```

### Cross-references

Always use `\cref` (from `cleveref`), not bare `\ref`:
```latex
% Good
as shown in \cref{fig:jct,fig:util}
% Bad
as shown in Figure~\ref{fig:jct} and Figure~\ref{fig:util}
```

### System name

Define once, use everywhere:
```latex
\newcommand{\sys}{Seren\xspace}
```

### Tables

Use `booktabs` style. Never use vertical lines. Bold the best number per row.
```latex
\begin{table}[t]
  \centering
  \caption{End-to-end JCT comparison (\sys vs. baselines).}
  \label{tab:main}
  \begin{tabular}{lrrr}
    \toprule
    System & Avg JCT (s) & P99 JCT (s) & GPU Util (\%) \\
    \midrule
    Tiresias   & 412 & 1840 & 61 \\
    Gandiva    & 387 & 1710 & 65 \\
    \textbf{\sys} & \textbf{179} & \textbf{830} & \textbf{89} \\
    \bottomrule
  \end{tabular}
\end{table}
```

### Figures

- Place figures at the top of the column with `[t]`.
- Set figure width in column units: `\columnwidth` (single) or `\linewidth` (spanning).
- All fonts in figures must be ≥ 8 pt when printed at column width.
- Use `\vspace{-1em}` *after* captions sparingly to tighten layout — never before.

```latex
\begin{figure}[t]
  \centering
  \includegraphics[width=\columnwidth]{figure/cdf_jct.pdf}
  \caption{CDF of job completion time. \sys (blue) reduces median JCT by
           2.3$\times$ vs. the best baseline (Tiresias, orange).}
  \label{fig:jct}
\end{figure}
```

### Numbers and units

```latex
% Good
achieves \SI{2.3}{\times} lower latency
reduces memory by \SI{40}{\percent}
% Acceptable
achieves 2.3$\times$ lower latency
% Bad (inconsistent, unbreakable space missing)
achieves 2.3x lower latency
```

### Avoid

- `\vspace`, `\hspace`, negative skips to hit page limits — do it with content cuts.
- `[h]` or `[H]` for float placement; use `[t]` or `[b]`.
- Inline `\textbf` for emphasis in running prose; use `\emph` instead.
- Widows and orphans — set `\widowpenalty=10000 \clubpenalty=10000` in the preamble.

---

## Revision process

### Pass 1 — Global structure (read without editing)
- Does each section do exactly one job?
- Is the order of sections the order a reader needs?
- Is every claim in the introduction backed by a result in the evaluation?

### Pass 2 — Section structure
- Does each sub-section have a topic sentence?
- Are there any paragraphs longer than 8 lines? Split them.
- Are all figures and tables referenced in prose before they appear?

### Pass 3 — Paragraph level
- First sentence of each paragraph = topic sentence (states the claim).
- Last sentence of each paragraph = either reinforces the claim or transitions.
- Eliminate: "It is worth noting that", "Interestingly,", "In this paper, we".

### Pass 4 — Sentence level
- Prefer active voice: "Seren reduces JCT" not "JCT is reduced by Seren".
- Kill weasel words: "relatively", "fairly", "quite", "somewhat".
- Every number needs a unit, a baseline, and a workload.
- Spell-check. Then grammar-check.

---

## Submission checklist

### Content
- [ ] Every claim in the abstract is backed by a result in the paper.
- [ ] Every number has a unit, a baseline, and a workload.
- [ ] All baselines are the strongest available, correctly configured, and cited.
- [ ] Ablations cover every non-trivial design decision.
- [ ] The top-level threat to validity is acknowledged in the paper.
- [ ] The system name and all acronyms are defined on first use.

### Figures and tables
- [ ] All font sizes in figures ≥ 8 pt at print size.
- [ ] All figures are vector PDF (`pdf.fonttype = 42`).
- [ ] Every figure has a self-contained caption.
- [ ] Tables use `booktabs`; no vertical lines.
- [ ] Best result per row is bolded.

### LaTeX
- [ ] No overfull `\hbox` warnings (check the `.log`).
- [ ] No undefined references or citations (`?` in the PDF).
- [ ] Bibliography is complete: all venue names, all page numbers where required.
- [ ] Author names, affiliations, and acknowledgements are correct.
- [ ] The compiled PDF is within the page limit (not "almost within").

### Reproducibility
- [ ] All scripts and configs used to produce paper figures are committed.
- [ ] A README documents how to re-run the key experiments.
- [ ] Random seeds are fixed and documented.

### Final
- [ ] PDF opens without errors in Adobe Acrobat (not just a PDF viewer).
- [ ] All fonts are embedded (check with `pdffonts paper.pdf`).
- [ ] Submission system fields (title, abstract, authors, topic areas) match the PDF.
- [ ] Camera-ready: source files compile cleanly on a fresh machine / in the venue's
      Overleaf template.