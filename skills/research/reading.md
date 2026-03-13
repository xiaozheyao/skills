# Paper Reading & Literature Search

This document covers how to efficiently read papers, find related work, and maintain
a literature library. Read this before tasks involving paper summaries, related work
surveys, or literature gap analysis.

---

## The three-pass method

Never read a paper start-to-finish on the first sitting. Use three passes of increasing
depth, stopping early if the paper is not worth the full investment.

### Pass 1 — Triage (5–10 minutes)

Goal: decide whether the paper is worth a full read.

Read in this order only:
1. Title and abstract
2. Introduction (first and last paragraph)
3. Section headings and sub-headings
4. Conclusion
5. Skim figures and captions without reading surrounding text

After pass 1 you should be able to answer:
- What problem does this paper solve?
- What is the claimed main contribution?
- Is it relevant to my current work?

If the answer to the last question is no, stop here and log it as "skimmed".

### Pass 2 — Understanding (1–2 hours)

Goal: understand the paper's claims, approach, and evidence. Skip proofs and
derivations unless they are the central contribution.

Read carefully:
- Introduction in full
- Every figure and table, reading the caption before looking at the content
- The system design or methodology section
- The evaluation setup and main result tables/plots
- Related work (skim — read more carefully once you know the space)

While reading, actively note:
- The core assumption that the whole design rests on
- What the baselines are and whether any obvious ones are missing
- Which claims are supported by data and which are asserted
- Anything that seems hand-wavy or underspecified

After pass 2 you should be able to explain the paper to someone else in 3 minutes.

### Pass 3 — Deep dive (4–6 hours, only for highly relevant papers)

Goal: understand the paper well enough to re-implement it or build directly on it.

- Read every section in full, including proofs and derivations
- Reconstruct the design from scratch on paper — what would you build if
  you had only the problem statement?
- Identify every place where an engineering decision was made and ask why
- Read the appendix
- Check the artifact / code repository if available
- Read at least 3 of the most important cited papers

---

## What to write down while reading

Keep notes in a format you can search later. At minimum record:

| Field | What to write |
|-------|---------------|
| **Citation key** | BibTeX key you will use (see convention below) |
| **One-line summary** | The single thing the paper achieves |
| **Core idea** | The key insight in 2–3 sentences |
| **Limitations** | What the paper explicitly does not do or does poorly |
| **Relevance** | Why it matters to your current project |
| **Connections** | Other papers this work extends, contradicts, or is compared against |
| **Open questions** | Things the paper leaves unanswered that matter to you |

---

## Literature search strategy

### Starting a new area from scratch

1. **Find 2–3 anchor papers** — ask your advisor or a colleague for the most important
   papers in the area. Use these as seeds, not as the complete picture.
2. **Forward-chase citations** — for each anchor paper, find papers that *cite* it using
   Semantic Scholar or Google Scholar "Cited by". This finds recent work.
3. **Backward-chase citations** — read the related work section of each anchor paper.
   These are the foundational works.
4. **Find the survey** — search for `<topic> survey` or `<topic> taxonomy` on arXiv or
   Google Scholar. A good survey saves days of work.
5. **Iterate** — once you have ~10 papers, new ones should mostly already be in your list.
   Stop when 80 % of cited papers in new reads are already in your library.

### Finding papers on a specific topic

In order of reliability:

1. **Semantic Scholar** (`semanticscholar.org`) — best for influence scores and citation
   graphs. Use "Highly Influential Citations" to find papers the field treats as seminal.
2. **Google Scholar** — best for keyword search, especially across venues. Use
   `"exact phrase"` and `-exclude` operators aggressively.
3. **DBLP** (`dblp.org`) — best for finding all papers by a specific author or at a
   specific venue. Use when you want complete coverage of a venue's proceedings.
4. **arXiv** (`arxiv.org`) — best for preprints before publication. Search at
   `arxiv.org/search` with field filters (`ti:` for title, `abs:` for abstract).
5. **ACL Anthology** (`aclanthology.org`) — use only for NLP/LLM-adjacent work.
6. **Papers With Code** (`paperswithcode.com`) — useful for finding SOTA results and
   associated code, especially for empirical ML work.

### Staying current

Skim new work weekly, not daily — daily checking creates anxiety without proportional return.

- **arXiv email alerts** — subscribe to `cs.DC`, `cs.OS`, `cs.NI`, `cs.LG` (and others
  relevant to your area) at `arxiv.org/user/`. Read titles + abstracts every Monday.
- **Semantic Scholar alerts** — set up alerts for key authors and "similar papers" to
  your own work.
- **Conference proceedings** — when a major conference publishes, read *all* titles and
  abstracts in your area in one sitting, then queue papers for pass 1.
- **Twitter/X and Bluesky** — follow active researchers in your area for pre-prints and
  commentary, but do not use as a primary discovery mechanism.

### Connected Papers

Use `connectedpapers.com` when you have one strong anchor paper and want a visual map
of the immediately surrounding literature. It is not exhaustive but is fast for
orientation in a new sub-area.

---

## Key venues by area

When assessing paper quality, venue matters. This table covers venues relevant to
ML systems, distributed systems, and networking research.

### Systems

| Venue | Tier | Typical topics |
|-------|------|----------------|
| OSDI | A* | OS, distributed systems, storage, ML infra — alternates years with SOSP |
| SOSP | A* | OS, distributed systems — alternates years with OSDI |
| NSDI | A* | Networked systems, distributed systems, datacenter networking |
| EuroSys | A | European systems, broad OS and distributed systems |
| USENIX ATC | A | Broad systems, implementation-heavy work |
| FAST | A | File and storage systems |
| SoCC | A | Cloud computing |

### ML Systems

| Venue | Tier | Typical topics |
|-------|------|----------------|
| MLSys | A | Training systems, inference, compilers, hardware co-design |
| SC | A | Supercomputing, large-scale HPC and ML training |
| ICS | A | Parallel and distributed computing, performance |
| PPoPP | A | Parallel programming, runtime systems |

### Machine Learning

| Venue | Tier | Typical topics |
|-------|------|----------------|
| NeurIPS | A* | General ML, systems papers increasingly common |
| ICML | A* | General ML, optimisation |
| ICLR | A* | Deep learning, representation learning |
| CVPR / ECCV / ICCV | A* | Computer vision |
| ACL / EMNLP / NAACL | A* | NLP |

### Networking

| Venue | Tier | Typical topics |
|-------|------|----------------|
| SIGCOMM | A* | Core networking, datacenter networks |
| IMC | A | Internet measurement, workload analysis |
| INFOCOM | A | Networking, protocols |

---

## Organising your library

### BibTeX key convention

Use the format `<FirstAuthorLastName><Year><FirstNounInTitle>`:

```
vaswani2017attention      # "Attention is All You Need"
dean2012large             # "Large Scale Distributed Deep Networks"
ousterhout2015ramcloud     # "The RAMCloud Storage System"
```

For papers with the same key, append `a`, `b`:  `dean2012largea`, `dean2012largeb`.

Keep a single `references.bib` per project. Do not maintain a "global" BibTeX file —
they diverge from the current project's needs and accumulate junk entries.

### Recommended tooling

- **Zotero** (free, open source) — best overall. Use the browser extension to save
  papers directly from arXiv/ACM/IEEE. Keep one library per research project, not one
  global library.
- **Papers** (macOS) — good PDF annotation and reading experience, weaker BibTeX export.
- At minimum: a flat directory of PDFs named `<key>.pdf` matching the BibTeX key, plus
  a single markdown notes file per paper.

### Related work map

When starting to write a paper, build an explicit taxonomy of related work before
writing the related work section. Create a table:

| Cluster name | Representative papers | What they do | Why insufficient for our problem |
|---|---|---|---|
| <Theme A> | [paper1, paper2] | ... | ... |
| <Theme B> | [paper3] | ... | ... |

This table becomes the skeleton of your related work section and forces you to
articulate the gap precisely before you write a word.