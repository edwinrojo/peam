PEAM-Registry course project paper (MITS-006, IEEE two-column IMRAD)
University of the Immaculate Conception, College of Computer Studies

Files
  main.tex          Paper content
  references.bib    IEEE references (biblatex + Biber)
  concept.png       Conceptual framework (input - process - output)
  userjourney.png   Employee user journey
  wireframe.png     Wireframes of the eight employee screens
  tools/make_figures.py
                    Redraws concept.png and wireframe.png
                    (python3 tools/make_figures.py; needs Pillow)

Compile on Overleaf
  Menu -> Compiler: pdfLaTeX. Bibliography is processed with Biber.
  Recompile once more if references show as [?].

Before submission
  Usability results are still open. Search main.tex for \pending and
  replace each value after the sessions (Table "Usability Results").
  Also update the abstract, Objective 4, and the conclusion once the
  SUS score is known.

  Guide questions are hidden (\studentguidefalse). Change to
  \studentguidetrue to show them again while editing.
