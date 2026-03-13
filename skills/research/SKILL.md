---
name: research
description: Skills and conventions for academic research in systems and ML. Use whenever the user needs to find or read papers, design experiments, analyse results, write or edit a paper, prepare a rebuttal, or make a submission.
---

# Research Skill

This skill covers the end-to-end research process for systems and ML research.
Detailed how-tos live in the sub-documents below.

| Task | Document |
|------|----------|
| Finding and reading papers, managing a library | `${CLAUDE_PLUGIN_ROOT}/skills/research/reading.md` |
| Designing experiments, baselines, ablations, reproducibility | `${CLAUDE_PLUGIN_ROOT}/skills/research/experiments.md` |
| Writing and submitting a paper, LaTeX conventions | `${CLAUDE_PLUGIN_ROOT}/skills/research/writing.md` |

---

## Critical rules (read before anything else)

1. **Figures before prose.** Never start writing a section before knowing exactly
   what the figures and tables will show. The narrative is built around the data,
   not the other way around.

2. **Never cherry-pick baselines.** Always include the strongest published
   baseline, even if it narrows the margin. Reviewers notice absent baselines
   immediately and it damages credibility more than a smaller improvement would.

3. **Always fix random seeds** and log the full experiment config alongside every
   result. A result you cannot reproduce six months later is worthless.

4. **One key message per figure.** If a figure caption needs more than two
   sentences to state the takeaway, simplify the figure or split it.

5. **Write for the impatient reviewer.** Abstract, introduction, and figure
   captions must be self-contained. A reviewer who reads only those four things
   should understand the entire paper: problem, approach, and key result.

6. **Related work is not a citation dump.** Group prior work into themes, explain
   what each theme achieves and why it falls short, then position your work
   precisely in that landscape.

7. **Separate mechanism from policy claims.** Be precise about what your system
   does vs. what the evaluation shows. Overclaiming in the text is the fastest
   way to collect rejection meta-reviews.

---

## What to read for each task

### Finding papers / building a reading list
Read: `${CLAUDE_PLUGIN_ROOT}/skills/research/reading.md`
- Three-pass reading method (skim → understand → critique)
- Search workflow: arXiv, Semantic Scholar, DBLP, citation chasing
- Staying current: arXiv alerts, daily digests
- Organising papers and BibTeX key conventions

### Designing and running experiments
Read: `${CLAUDE_PLUGIN_ROOT}/skills/research/experiments.md`
- Experiment design checklist (hypothesis, baselines, metrics, budget)
- Ablation study structure and scope
- Reproducibility requirements: seeds, config logging, environment capture
- Naming and organising experiment runs and result directories
- Statistical rigour: multiple seeds, error bars, significance

### Writing a paper
Read: `${CLAUDE_PLUGIN_ROOT}/skills/research/writing.md`
- Writing order: figures → outline → prose
- Abstract and introduction formulas
- Evaluation section structure (setup → metrics → main results → ablations)
- LaTeX conventions for systems/ML papers
- Revision process and submission checklist

---

## Quick reference: research venues

### Systems

| Venue | Tier | Typical focus |
|-------|------|---------------|
| OSDI | A* | OS, distributed systems, storage — biennial with SOSP |
| SOSP | A* | OS, distributed systems — biennial with OSDI |
| NSDI | A* | Networked systems, data-centre infrastructure |
| EuroSys | A | Broad systems, strong on cloud and OS |
| USENIX ATC | A | Applied systems, broader scope than OSDI/SOSP |
| FAST | A | Storage systems, file systems |
| SoCC | A | Cloud computing |

### ML Systems

| Venue | Tier | Typical focus |
|-------|------|---------------|
| MLSys | A | Training systems, inference, compilers, hardware-SW co-design |
| SC | A | HPC, large-scale ML, parallel computing |
| ICS / PPoPP | A | Parallel and distributed computing |

### Machine Learning

| Venue | Tier | Typical focus |
|-------|------|---------------|
| NeurIPS | A* | General ML, large and broad |
| ICML | A* | General ML |
| ICLR | A* | Deep learning, representation learning |
| TMLR | A | Journal-style, rolling submission, no deadlines |

### Networking

| Venue | Tier | Typical focus |
|-------|------|---------------|
| SIGCOMM | A* | Core networking protocols and architecture |
| NSDI | A* | (also listed above) |
| IMC | A | Internet measurement and analysis |

---

## Quick reference: deadlines and review timelines

| Venue | Typical submission | Notification | Cycle |
|-------|--------------------|--------------|-------|
| OSDI / SOSP | ~November / ~April | ~3 months later | Annual (alternating) |
| NSDI | Spring + Fall rounds | ~3 months later | Two rounds/year |
| EuroSys | ~October | ~January | Annual |
| USENIX ATC | ~January | ~April | Annual |
| MLSys | ~November | ~February | Annual |
| NeurIPS | ~May | ~September | Annual |
| ICML | ~February | ~May | Annual |
| ICLR | ~October | ~January | Annual |

> **NOTE:** Deadlines shift year to year. Always verify at the venue's official site
> before planning. Use [aideadlin.es](https://aideadlin.es) or
> [paperswithcode/venues](https://paperswithcode.com/rc) for a live overview.