# Dissertation Requirements and Writing Checklist

This file records the durable dissertation constraints supplied by the user on 22 August 2026. Future dissertation writing and revision must check this file before editing the thesis.

## Authoritative local sources

1. `E:\course pdf\project\格式\Games_Engineering_Dissertation_Template.zip`
2. `E:\course pdf\project\格式\MScGEDissertation (1).pdf`

The ZIP is the University of Warwick thesis template. The PDF is the complete 45-page MSc Games Engineering dissertation workshop presented by Kurt Debattista. If this checklist conflicts with a later official University or module document, verify the current official requirement with the supervisor before changing the thesis.

## Mandatory scope and structure

- Maximum dissertation length: 15,000 words.
- Treat the dissertation as a major individual 60-CAT project representing approximately 600 hours of work.
- Use the following main sequence:
  1. Abstract
  2. Introduction
  3. Literature Review
  4. Research Methodology/Outline
  5. Method
  6. Results and Analysis
  7. Discussion
  8. Conclusions
  9. Appendices, kept brief and used only for supporting detail
- The literature review must cover background, related work, critical comparison and a clearly stated research gap.
- The Introduction must provide context, motivation, rationale, an explicit research question or problem, scope, and a chapter outline. It should remain accessible to a non-expert reader while demonstrating subject expertise.
- Research Methodology must state the rationale, research aim/question, objectives, overall experimental design, methods and their justification, data source/access, measures of success, metrics and analysis method.
- Method must contain sufficient technical detail to reproduce the work, including algorithms, formulae where relevant, software architecture, implementation decisions and experimental procedure.
- Results and Analysis must present experimental outputs, baseline comparisons, tables/graphs, patterns and qualitative evidence where useful. Results must be separated from unsupported interpretation.
- Discussion must answer what the results mean for the research question, compare against relevant alternatives, and report impact, opportunities, limitations and validity threats.
- Conclusions must summarise the contribution and completed work, answer the research question at the level supported by evidence, state limitations and identify future work.

## Required front matter and submission details

- Provide an accurate title, author, submission month/year, full qualification, department and student number.
- Include the title page, table of contents, list of figures and list of tables when tables are used.
- Include a personalised declaration, acknowledgements and a concise abstract.
- Define abbreviations and technical terms. Print a list of abbreviations if abbreviations are used sufficiently to justify it.
- Confirm the current Tabula deadline and exact submission instructions rather than relying on the workshop's non-specific “early September” wording.
- Send drafts to the supervisor well before submission and allow time for review and amendments.
- Follow the current University guidance on Turnitin, academic integrity and generative AI. Do not invent the required disclosure wording; verify it before final submission.

## Template layout that must be preserved

- LaTeX `memoir` class, `11pt`, `a4paper`, `oneside`, `extrafontsizes`.
- `uwthesis` package with 4 cm left and right margins.
- 3 cm upper and lower margins as defined by `uwthesis.sty`.
- One-and-a-half line spacing and 1.5 em paragraph indentation.
- Number section levels and include them in the table of contents as configured by the template.
- Centre figures and tables by default. Use numbered captions and cross-references for every figure and table discussed in the text.
- Keep the template's title-page and page-numbering conventions: roman-numbered front matter followed by Arabic-numbered main matter.
- The supplied template uses `biblatex` with Biber and the `nature` style. The current draft uses a manual `thebibliography`/`natbib` compatibility path; this is a known deviation that must either be migrated or explicitly checked with the supervisor before final submission. Whichever route is approved must be applied consistently.

## Academic writing rules

- Use clear, precise and formal language. Avoid unnecessary complexity.
- Prefer objective, evidence-based wording and generally avoid first-person plural unless disciplinary convention makes it appropriate.
- State contributions explicitly, for example: “The main contributions of this work are …”. A concise bullet list is acceptable.
- Use citations for factual, methodological and comparative claims.
- Signpost chapter and section flow.
- Define every acronym, technical term and equation variable before relying on it.
- Report datasets/workloads, sample counts, conditions, metrics, baselines and analysis methods explicitly.
- Report negative, mixed and edge-case results rather than selecting only favourable observations.
- Do not write that a method “works well” merely because a graph looks better. Quantify the difference and limit the conclusion to what the metric measures.

## Project-specific evidence rules

- Separate implementation correctness, geometric/display evidence, interaction-performance evidence and human-usability evidence.
- Card area, visible-node ratio, information-field count, overlap count and dimmed-node ratio are interface measures; they do not directly prove readability or reduced cognitive load.
- Timing results must state hardware, Godot version, renderer, viewport, tree size, warm-up, repetitions and aggregation statistic.
- Prefer medians, interquartile ranges and 95th percentiles for noisy editor timings; retain raw observations.
- Use fixed deterministic trees for controlled comparisons and the playable 241-node tree as an ecological/real-use validation case.
- Never fabricate participant data. Until the prepared human study is run, state that human usability remains unverified.
- Every table, figure and percentage in the thesis must be traceable to a committed raw data file and reproducible script.

## Mandatory dissertation source and generation sequence

- After every dissertation text revision, first generate a complete editable DOCX and give it to the author for correction or confirmation. Only after the author returns or confirms that DOCX should the accepted text be synchronized to LaTeX and compiled to PDF.
- Never reconstruct the dissertation DOCX by converting or extracting text from a PDF. Use the recorded authoritative text source for that version, such as the accepted DOCX, tracked Markdown, or tracked LaTeX snapshot.
- Unless the user explicitly requests an omission, the DOCX must preserve the title, front matter, every heading and body paragraph, citations, bibliography, footnotes and appendices. A request for a text-only version may omit tables, images and their captions, but it must not silently shorten or rewrite the surrounding prose.
- DOCX, LaTeX and PDF must represent the same accepted text. Before delivery, compare their chapter and section structure, paragraph content, citations, references and key numbers. Do not deliver a version when a mismatch or unexplained omission remains.
- Keep each accepted DOCX as a named version checkpoint. Do not overwrite an author-edited DOCX when generating a later LaTeX or PDF version.

## Final pre-submission audit

- Word count is at or below 15,000.
- Required chapter and front-matter sequence is present.
- Research question, objectives, measures of success and contributions agree across Abstract, Introduction, Methodology and Conclusion.
- Method describes enough detail to reproduce each reported result.
- Results, figures, tables and raw CSV files agree numerically.
- Discussion distinguishes evidence from inference and includes limitations.
- All citations resolve and use one approved style consistently.
- Figures and tables are referenced, legible and listed.
- Placeholders for author, student number, acknowledgements, declaration and AI disclosure have been resolved by the author.
- The final PDF is visually inspected page by page before submission.
