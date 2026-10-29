// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#set page(binding: auto)

#set bibliography(title: [References], style: "apa")

#show bibliography: it => {
  counter(heading).update(0)
  pagebreak()
  it
}
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a4",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Doing Psychological and Brain Science Research: A Field Report On Scientific Workflows],
  author: "Rich Ramsey",
  date: "2026-10-29",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Preface]
<preface>
This book has one fundamental premise. The foundations of scientific claims should be easy to access and verify. This is not just about promoting trust between scientists to help build on past research effectively. It also stems from a moral obligation. Most modern science is publicly funded, and therefore it should be available to serve the public.

Of course, the need to verify the foundations for other scientist's claims is far from a new problem. For centuries (or longer) scientists have been confronted with this problem. This book just takes a snapshot of how modern tools can be arranged into a workflow to address it.

What follows is not a suggestion that this workflow is "correct" in any meaningful way. It is just one concrete template of a workflow that gets closer to a reality where we can meet the fundamental challenge that our work can be easy to access and verify. As such, this book is a field report on current scientific workflows from an active cognitive neuroscience lab. It is not a manifesto for change or a best-practice manual.

#heading(level: 2, numbering: none)[Who is this book for]
<who-is-this-book-for>
This book is primarily written for future me (so I don't forget), as well as for people in my group and for collaborators. The hope is that it replaces conversations that tend to happen repeatedly as new people join a project. Such conversations are necessary but hard to scale, and people cannot reasonably retain everything instantly.

Of course, other psychology or brain science researchers may find it useful too. At the broadest level, given that the fundamentals apply to #strong[#emph[any]] quantitative project, folks in wider domains of behavioural science, medicine, biology, and neuroscience might be interested too. Ultimately, the book is situated in psychological and brain science research, since that is what I am familiar with.

#heading(level: 2, numbering: none)[Prerequisites]
<prerequisites>
- No prior material understanding of psychology or cognitive neuroscience is required: it is the principles and infrastructure that matters most, rather than domain-specific topics or methods.
- Basic programming skills in R (or another language).
- Familiarity with the basic aims of common data analysis and statistical approaches.
- Some basic sense of common research designs, such as experimental vs.~cross-sectional designs.
- An understanding that much of psychology and cognitive neuroscience research involves data collected from human participants.

#heading(level: 2, numbering: none)[Basic structure]
<basic-structure>
After introductory chapters, which provide relevant historical context and general aims and scope, the book follows the rough chronology of a research project --- from the initial commitment to make your work findable and reusable, through planning, data management, processing, visualisation, and analysis, to dissemination. The infrastructure that holds all of this together (code, version control, reproducible pipelines) gets its own chapter early on, because without it the rest is harder. Each chapter is short by design. The goal is to be clear about what we do and not to be comprehensive. Where others have written better and more technical accounts of a particular topic, I point to them and move on.

#heading(level: 2, numbering: none)[Themes]
<themes>
There are two broad themes that intersect across the book.

#strong[Theme 1:] Domain-general software tools that are likely to be relevant for #strong[#emph[any]] scientific project.

#strong[Theme 2:] A scienfitic workflow for research projects in psychology, neuroscience and related disciplines.

#heading(level: 2, numbering: none)[What this book is not]
<what-this-book-is-not>
This book is not:

- A psychology or cognitive neuroscience textbook. Therefore, it does not cover core topics, methods or controversies in cognitive neuroscience.
- An attempt to describe or prescribe "best-practice" in any sense. Instead, the book just reflects current and ongoing practice in one lab. Therefore, it reflects a specific stack of tools, practices, and choices that have accumulated in one lab over one particular period. Other labs may have made different choices for good and/or bad reasons.
- A manifesto for "open science" in the sense of supporting or advocating for an organised movement associated with open science practices.
- A "how-to" guide with tutorials on specific implementation.

#heading(level: 2, numbering: none)[A note on tools]
<a-note-on-tools>
Where specific tools are mentioned (e.g., R, brms, Stan, Git, OSF, Docker, Zenodo), keep in mind that these reflect what we currently use, not what we think everyone should use. The underlying principles of reproducibility, transparency, and clear uncertainty quantification are the point. The tools are one implementation of those principles.

#heading(level: 2, numbering: none)[How should you read this book?]
<how-should-you-read-this-book>
Ideally, the book is intended to be read linearly, as the chapters do build on each other. And the later chapters may be easier to digest and understand if you understand the basic aims and setup. However, each chapter is largely self-contained and can be read in isolation. Therefore, if there is a particular topic that you want to focus on, then just go straight to that chapter.

#heading(level: 2, numbering: none)[Living document and updates]
<living-document-and-updates>
The book is intended to be a living document, which changes as things change in scientific workflows. Therefore, substantial updates will be released and versioned accordingly.

#heading(level: 2, numbering: none)[Disclaimers]
<disclaimers>
I am not a software engineer and I have no formal training in this domain. My training is in experimental psychology and cognitive neuroscience. The purpose of this book is to provide a practical example of a current scientific workflow based on my training and perspective as an active researcher. Therefore, in the sections on infrastructure and software, I will discuss tools that I use, rather than develop myself. This means that I am very much a beginner in the software space and I use these tools out of what I perceive to be a necessary condition of doing modern science.

#heading(level: 2, numbering: none)[Acknowledgements]
<acknowledgements>
#heading(level: 2, numbering: none)[License and citation]
<license-and-citation>
© Rich Ramsey, ETH Zürich. Licensed under #link("https://creativecommons.org/licenses/by/4.0/")[CC BY 4.0].

#part[Introduction]
= What's in your head?
<sec-mind-brain>
#block[
#callout(
body: 
[
Psychological and brain science research holds the potential for wide-ranging societal impact, but to realise that potential research materials need to be available and routinely verified.

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
I remember taking a final year undergraduate class on neuropsychology and being utterly fascinated. The brain controlled movements, breathing, social interactions, disease, disorder, rehabilitation, expertise, and on and on. How could one #strong[#emph[not]] be fascinated?

The potential seemed enormous. It immediately made me want to do a PhD in a related field. If only we could understand cognitive and brain "mechanisms" better, then all manner of possibilities and opportunities might open up to understand how humans experience in the world. And that genuine level of excitement about the #strong[#emph[potential]] of psychological and brain science research feels about as right today as it did back then in 2003.

== Research materials are #strong[#emph[not]] routinely verified
<research-materials-are-not-routinely-verified>
But, how are research findings in relation to mental processes verified? How would we know if conclusions and subsequent societal decisions were based on solid foundations? A layperson may expect that a dispassionate, sober, professional, careful and "scientific" process exists for verifying scientific research. And they would be wrong. And that is a big problem.

For the vast majority of research reports in academic journals, the underlying research materials, such as data and code, are not available to #strong[#emph[anyone else]] to verify. This is because they were simply never shared in the first place. Even the academics who peer-review the work at the request of a journal, and who make a formal recommendation about the quality of the research, do not typically get access to these materials. Instead, all the reviewers see is a static pdf document and nothing else.

Sometimes data and code are made "available on request". But, when these materials are formally requested they are often not provided @husseyDataNotAvailable2025. And in many cases, the written report is hidden behind paywalls and only available via subscription, which excludes many institutions and the public from access. In response, there have been some recent changes in culture and expectations that have led to more sharing of data and code @wilkinsonFAIRGuidingPrinciples2016, but this comes from a very low base and without widespread formal training or standardisation.

== Towards realising potential
<towards-realising-potential>
If we want to realise the potential of cognitive and brain science, one that seeks credibility and legitimacy to impact society, then a more professional approach to the fundamental importance of verification is required. If these fundamentals are not achieved (or even strived for in a meaningful manner) then one might ask: What's the point of doing the research in the first place? For example, if research cannot be accessed or used by other professional scientists easily and reliably, then what chance is there of making genuine societal impact in the domains of health, education or public policy? I agree with others that the chances are close to zero @arslanScienceNeedsDownvotes2026.

= Historical context
<sec-history>
#block[
#callout(
body: 
[
Verifying other's research findings is an old endeavour, which has always been costly, and largely undervalued in recent times.

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
The desire to check others' research is an old endeavour. And it is not easy to do. Producing trustworthy scientific material is hard in any domain. Making that material easily accessible and verifiable complicates matters further. And widespread access to tools that make this easier are relatively new. Indeed, the notion of #link("https://www.youtube.com/watch?v=8qzVV7eEiaI")[science as practicing amateur software development] is a reasonably new possibility in the scheme of the history of science. To make this concrete, let's look at a few moments in history.

== The emergence of the Royal Society (1600s)
<the-emergence-of-the-royal-society-1600s>
The motto of the UK's #link("https://royalsociety.org/about-us/who-we-are/history/")[Royal Society] (founded in 1662), is 'nullius in verba', which means 'take nobody's word for it'. And indeed, in 1679, Edmond Halley travelled to Poland along with his own equipment to verify the observations made by Johannes Hevelius @jonesHalleyAstronomer1957. This would have been costly, in terms of time and money, but clearly underscores the value placed on verification. But the world and science was not as widespread or as interconnected as it is now.

== The Industrial Publishing Complex (1950s onwards)
<the-industrial-publishing-complex-1950s-onwards>
From at least the 1950s onwards, academic publishing changed dramatically in pace, scale and reach with a proliferation of journals, institutions and people working as professional academics all over the world. But, prior to the mass availability of the internet, sharing research materials would have remained difficult and expensive. And responsibilities were unclear and/or unspecified. For example, should the journal host all raw materials and share them upon request from others? And who would pay for any or all of this? As such, before the internet revolution changed things, there were legitimate practical barriers to sharing materials.

== My PhD days (2004-2007)
<my-phd-days-2004-2007>
Even when I did my PhD, in an era when the internet was very much widespread, the idea that raw data or code would be submitted alongside a journal submission was largely unheard of in disciplines associated with psychology and neuroscience. As an illustrative example of the times, as I prepared my very first journal article submission, I burned the raw data to a DVD (young people, see #link("https://en.wikipedia.org/wiki/Optical_disc_authoring")[here]). In the next meeting with my supervisors, I placed the DVD in a jiffy bag and asked: do I address this to the Editor-in-Chief and send it to the journal's mailing address? My supervisors laughed out loud. They then mentioned that they had heard about journals doing "data audits" before, but they didn't happen very often, and they had never been audited yet.

As a young trainee scientist, I was genuinely shocked that nobody else, other than my coauthors, would check the data. And even then, it was certainly not routine for co-authors to go through the data and analysis steps with a fine tooth comb. To be clear, I was very lucky to have such supportive, involved and generous supervisors. My observation is simply that there was a complete absence of industry standard on sharing research materials. Even in my naive researcher state, it was clear to me that this was not how science should be conducted. And it was also obvious that this was not how the public expected science to operate when spending taxpayer's money.

== Towards "born open" science (2015 onwards)
<towards-born-open-science-2015-onwards>
As we move towards the present day, attitudes are slowly shifting. Instead of a static pdf document being the sole "product" of a scientific project, more and more actors - spanning individuals, journals, funding agencies and learned societies - recognise that the written report is merely window dressing for everything else that supports the claims being made, such as data, code and experimental materials @buckheitWaveLabReproducibleResearch1995@donohoInvitationReproducibleComputational2010. The challenge now is to build workflows that can deliver in response to this challenge. What might that such a workflow look like, in terms of infrastructure in general and in terms of research workflows in cognitive neuroscience? That is what this book addresses, but from the perspective of one lab.

= What Done Looks Like
<sec-done>
#block[
#callout(
body: 
[
Science is #strong[much] more than a static pdf article.

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
Before getting into the details, it is worth being clear about what we are working towards.

At the end of any research project involving data, there are a few things that, whenever possible, should exist in a usable state: the data, the code used to analyse it, and any other research materials that are needed to understand and reproduce what was done. This is not a scientific argument. It is closer to a basic obligation.

Most psychological and brain science research is publicly funded. The data collected, the analyses run, the findings reported were paid for by public money in the expectation that they would produce knowledge that is available to the public, to future researchers, to clinicians, to anyone with a legitimate interest. Keeping those materials locked in a lab drive, or failing to document them well enough for anyone else to use them, is a failure of that obligation. There can be legitimate exceptions to this obligation, such as in relation to participant privacy, commercial sensitivity, or genuine practical constraints, but they are fewer and further between than current practice implies @chambersSevenDeadlySins2017.

== Towards FAIRness
<towards-fairness>
The FAIR principles --- Findable, Accessible, Interoperable, Reusable --- provide a useful shorthand for what "done" looks like @wilkinsonFAIRGuidingPrinciples2016. They were developed initially for research data but apply equally to code and materials.

- #strong[Findable]: data and materials have persistent identifiers (DOIs), are deposited in searchable repositories, and are described with sufficient metadata that someone could locate them without already knowing they exist.
- #strong[Accessible]: they can actually be retrieved without being behind a login, or on a personal hard drive, or "available on request" in a footnote.
- #strong[Interoperable]: they use open, standard formats where possible. A #NormalTok(".csv"); rather than a proprietary spreadsheet format. Plain text rather than a binary file. Code that does not require a paid licence to run.
- #strong[Reusable]: they are documented well enough that someone who was not involved in the project could understand what they are, what they represent, and how to use them.

FAIR principles are not binary. Research materials can be more or less FAIR. The goal is not about obtaining instant perfection, but being clear-eyed about the target vision. Every decision about how to structure a dataset, name a variable, or document a pipeline should be made with FAIR in mind as the endpoint. In that sense, FAIR acts as a destination that can guide behaviour.

The rest of this book represents one practical answer to the question that FAIR raises: how do you actually get there? Version control, data management plans, reproducible analysis pipelines are not ends in themselves. They are the infrastructure that makes FAIR more easily achievable without heroic effort at the end of a project.

The common mistake is to treat data sharing and documentation as a final step, which is done after the paper is accepted for publications at a journal. By that point, the data are messy in ways that are hard to unpick, the code is undocumented, the decisions that were made along the way have been forgotten. FAIR has to be baked in from the start, not retrofitted at the end.

You can think about it like baking a cake. The cake you want is a FAIR, documented, reproducible record of what you did and found. Everything that follows in this book is about how to bake it. And after baking it once, you can more easily adapt and improve the recipe for future use.

== "Done" can be fluid, rather than static
<done-can-be-fluid-rather-than-static>
There is a tempting but mistaken idea that making your work open and reproducible is something you do at the end of a project as a final administrative step before moving on. Upload the data, share the code, tick the box. This framing treats a research output as a static artifact, like a paper in print. Once it exists, you cannot update it.

The infrastructure described in the chapters that follow makes a different model possible. A dataset lives in a version-controlled repository. A codebook is a text file with a commit history. A Zenodo deposit can have multiple versions, each with its own DOI, each traceable to a specific state of the project at a specific point in time. When someone finds a typo in a variable label, you fix it and commit. When a preprocessing error is identified after publication, you correct it, document what changed and why, and release a new version. The record of what happened is preserved. The current best version is available.

This is closer to how software is maintained than how academic papers are typically published. It requires a shift in how you think about a research output. Rather than a document that is finished, it is a project that is responsibly maintained. The overhead is low if the infrastructure is in place from the start. It is considerable if you are trying to retrofit it two years after data collection ended. None of this means a research project has no natural endpoint. It means that an endpoint is better understood as "in good enough shape that someone else could take it from here", rather than as "submitted and never touched again."

== Practical starting points
<practical-starting-points>
A few concrete steps that cost relatively little but move significantly towards FAIR:

- Choose a repository before you start collecting data (GitHub, OSF, Zenodo, institutional repository) and create a project there.
- Write a brief data management plan before data collection begins.
- Use open file formats from the start.
- Supply data dictionaries alongside data files.
- Write a comprehensive README file for every project.
- Decide on a licence for your data and code (e.g., CC-BY, MIT).

None of these are technically demanding. They are habits. The chapters that follow describe how we have tried to build those habits into the normal rhythm of running a project.

= Infrastructure
<sec-infrastructure>
#block[
#callout(
body: 
[
Watch this #link("https://www.youtube.com/watch?v=8qzVV7eEiaI")[talk] by #link("https://www.eva.mpg.de/ecology/staff/richard-mcelreath/")[Richard McElreath] titled "Science as amateur software development".

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
This chapter covers the general-purpose tools that make everything else in the workflow possible. These tools are taken from software engineering practices and turn a collection of scripts into something that works reliably and that someone else (or future you) can understand.

== Why borrow from software engineering?
<why-borrow-from-software-engineering>
The tools described here were not developed for science. They were developed by software engineers to solve related problems: how do you write code that works, that can be modified without breaking everything, that multiple people can work on simultaneously, and that you can return to six months later and still understand? These are exactly the problems a research lab faces with data and analysis code. The solutions transfer almost directly. This is a big area, which I do not attempt to cover in any great detail. Instead, in #ref(<sec-basic-infrastructure>, supplement: [Section]) below, I highlight three key aspects of infrastructure.

== What if you don't feel like a software developer?
<what-if-you-dont-feel-like-a-software-developer>
I certainly don't feel like a software developer, and I have no credentials as one either. At the same time, in the process of doing science, I write code that analyses data, produces visualisations and builds models that #strong[DIRECTLY] substantiate the scientific conclusions that I make in published work. \
If the materials used to make scientific claims should be routinely accessible and verifiable, then scientists have an obligation to make all computer code available. And such an obligation is orthogonal to your level of experience in programming and software development. Thus, I think we have to recognise a hard truth: if your code is not ready for public scrutiny, then your science is not ready for public consumption.

== Basic infrastructure
<sec-basic-infrastructure>
In the following subsections, I outline three key themes regarding infrastructure.

=== Project organisation
<project-organisation>
There are several useful resources that outline general principles of good project organisation, such as this textbook on data management @lewisDataManagementLargeScale2024 and this journal article on code development @rothTenPrinciplesReliable2025. More details can also be found in the #ref(<sec-data-management>, supplement: [Chapter]) section of this book.

Some key themes in summary are as follows. Start the project with the intention of it being a public facing resource in the end. Only things that absolutely must be kept private should be inaccessible. Each project has one folder, which adopts a consistent structure across different projects, such as using consistent folder and filename conventions. There is a #link("https://www.makeareadme.com/")[README file] at the project root folder, which outlines details of the repository. Then whenever you land on a project, you consult the README file for an orientation. There is clear separation between raw and processed data, as well as a clear description of datasets in a data dictionary.

=== Version control, backup and collaboration
<version-control-backup-and-collaboration>
We use Git to version control all projects, and we use GitHub for an online backup of code and to collaborate on projects. If you are unfamiliar with version control software, such as Git, then there are many helpful tutorials online (see #link("https://happygitwithr.com/")[here] and #link("https://www.atlassian.com/git/tutorials")[here]). And if you use R and R Studio (or Positron), then this paper is particularly helpful @vuorreCuratingResearchAssets2018.

Git is designed primarily for code and limited to relatively small file sizes, but larger files (e.g., data and model objects) can be stored in other data repositories. We work within an Integrated Development Environment (IDE) that is designed for data science, such as Positron (previously RStudio), as this can make working with data and code so much easier, as well as more efficient and enjoyable. We connect local projects to an online repo, in order to iterate and collaborate with colleagues. The online repo can remain private during development, before being made public at a suitable point.

=== Reproducible pipelines
<reproducible-pipelines>
The goal here is that you can reproduce your own work easily and efficiently, and others can reproduce it too. We use #link("https://quarto.org/")[#NormalTok("Quarto");] documents for everything that we possibly can from data analysis files to written manuscripts and presentations. Quarto docs mix prose, as well as code from multiple languages (Python, R, Julia), and output to a wide range of document types (.html, pdf, word, presentation slides etc.).

Within the R ecosystem we use #link("https://rstudio.github.io/renv/articles/renv.html")[#NormalTok("renv");] for package management. #NormalTok("renv"); tracks the specific R package versions that you used per project and, in theory, allows other to use the same package versions when attempting to reproduce your analyses.

But #NormalTok("renv"); is not perfect, and there can still be problems reproducing work across time and system settings, which this #link("https://www.youtube.com/watch?v=l01u7Ue9pIQ")[talk] outlines. A more comprehensive solution is to use a container, such as #link("https://www.docker.com/")[#NormalTok("Docker");], to reproduce the entire system. Containers can be a bit off-putting initially, but this tutorial paper is an excellent starting point @wiebelsLeveragingContainersReproducible2021b. A container is a shareable Linux environment with the appropriate package and system versions that anyone else can use or create. For instance, if you use a different Operating System, or typically use different programming language, such as a Python user inspecting R code, then you can run and verify the code in a container. To see and work with a minimal test example that uses my group's typical data science workflow using Positron, then go #link("https://github.com/rich-ramsey/positron-test")[here].

== The basic rule
<the-basic-rule>
Write everything as if someone else will need to run it without you present. That someone is usually you, eight months from now, having forgotten everything.

#part[Project workflow]
= Workflow overview
<sec-overview>
#block[
#callout(
body: 
[
Follow the fantastic #link("https://vuorre.com/posts/workflow/")[workflow] of the amazing #link("https://vuorre.com/")[Matti Vuorre].

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
In this chapter, I want to summarise my group's current scientific workflow. I use the term "scientific workflow" as a bridge to link general software tools, such as git and containers, with more specific data science tools and choices regarding various things, such as research design, data wrangling, visualisation and model building. For instance, one may change the coding language from R to Python or make different data wrangling, visualisation or modelling choices, whilst still using git and container for version control and reproducibility. The aim of the chapter is to provide a clear and coherent overview that can act as a roadmap for subsequent chapters.

== Guiding principles
<guiding-principles>
- We aim to use software that is open source and free whenever possible.

- We want the default workflow to be general enough for most use-cases that we encounter in psychology and neuroscience #footnote[There will be exceptions, of course. For example, specialised human neuroscience measurements might be one such exception. But the basic set of steps and tools should be useful in most cases as they are, whilst also serving as an excellent starting point to depart from when necessary.].

  - As such, the workflow should embody what we consider "sensible defaults".

== Benefits of using "sensible defaults"
<benefits-of-using-sensible-defaults>
There are several benefits to establishing "sensible defaults" within a workflow:

- A workflow document can be written and circulated, which is versioned and timestamped, but also dynamic such that it can be updated as approaches, tools and software change.
- Staff and students starting new projects have a template to follow that requires minimal input from others to get started. There are a host of resources, including textbooks, journal articles, blog posts, recorded lectures and tutorials, that new folks can follow.
- There is a common frame of reference between team members, which can aid collaboration and pre-submission peer-review. For instance, it becomes far easier to perform code review and give feedback, if the overarching data science workflow is familiar.
- By design, the default workflow generalises to most projects in your lab. Therefore, the main time cost is setting up the first project. Once the workflow is established, the setup and basic structure can just be copied to other projects. And by doing so, one would hope to make the steps more habitual and routine in nature and therefore less effortful.
- It becomes easier to see when departures from a default workflow are required and what might justify such departures. For instance, if the data are flat or cross-sectional in nature and devoid of repeat observations then it will become clear very quickly that a multi-level model is not possible.

== Science stack
<science-stack>
Here I build on the #ref(<sec-infrastructure>, supplement: [Chapter]) section, by including other tools that form part of our scientific workflow.

- #strong[Literature]: #link("https://www.zotero.org/")[Zotero]
  - We store all literature sources in Zotero.
- #strong[IDE]: #link("https://positron.posit.co")[Positron] (VS Code-based, R/Python)
  - We use Positron as the primary IDE (previously RStudio).
- #strong[Version control/Collaboration/Backup/Sharing]: Git and GitHub (see #link("https://happygitwithr.com/")[here] and #link("https://www.atlassian.com/git/tutorials")[here])
  - We use git for version control and GitHub for collaboration, backup and sharing.
- #strong[Language]: #link("https://www.r-project.org/")[R]
  - We try to use R for everything.
- #strong[Pre-registration]: #link("https://osf.io")[OSF] & #link("https://aspredicted.org/")[AsPredicted.org]
  - We pre-register all confirmatory studies via the OSF or aspredicted.
- #strong[Data wrangling and visualisation]: #link("https://tidyverse.org/")[Tidyverse]
  - We use the Tidyverse tools to make "tidy", long format dataframes and data visualisations.
- #strong[Modelling]: #link("https://paul-buerkner.github.io/brms/")[brms] + #link("https://mc-stan.org/cmdstanr/")[cmdstanr] + #link("https://mc-stan.org/docs/cmdstan-guide/")[CmdStan]
  - We use brms to fit Bayesian regression models, which uses stan on the backend.
- #strong[Package management]: #link("https://rstudio.github.io/renv/")[renv]
  - We use renv to manage and track the exact package versions used in each specific project.
- #strong[Manuscript]: #link("https://quarto.org")[Quarto] + #link("https://github.com/mvuorre/quarto-preprint")[quarto-preprint] (Typst PDF + HTML)
  - We write manuscripts in quarto and output to .html, .pdf and even MS Word (if forced).
- #strong[Reproducible environment]: #link("https://www.docker.com")[Docker] + #link("https://rocker-project.org")[rocker]
  - We have recently started using Docker to containerise our work.
- #strong[Data and model storage]: #link("https://osf.io")[OSF] / #link("https://zenodo.org")[Zenodo] (for large files)
  - We #emph[previously] used the OSF to store large files and model objects.
  - But things are changing - see #link("https://zenodo.org/records/23063981")[here], #link("https://daniellakens.blogspot.com/2026/08/which-data-repository-should-you-use.html")[here], and #link("https://bettercode-book.org/book-sharing.html")[here] for a summary of useful alternatives.
- #strong[Permanent archive]: #link("https://zenodo.org")[Zenodo] (DOI on journal acceptance)
  - We have recently started using Zenodo for long-term archival purposes.

== Workflow in practice
<workflow-in-practice>
Although the above may seem like a long list, I think a worked example of the main phases may help contextualise the workflow. More specifically, it will hopefully highlight a set of practices that we have developed in an attempt to make them habitual and thus easier to use in a routine and cognitively efficient manner.

+ #strong[Setup.] We always start by pointing the IDE (Positron) to the project folder and initialising git and renv. From then on, we are working in a self-contained project, which is version controlled and uses project-specific R package versions. And we only ever use a handful of commands from git and renv, so it is not overly cumbersome.

+ #strong[Project development.] We use quarto docs for everything that we possibly can. They can combine prose and code and are therefore suitable for programmatic data analysis pipelines, as well as technical reports such as journal articles. We collaborate in teams at this point via GitHub.

+ #strong[Dissemination.] We publish a pre-print that includes links to the GitHub repo, as well as any other relevant links, such as OSF pages and any records of pre-registrations.

+ #strong[Archive.] In addition to the GitHub repo, which is publically available, once the paper is accepted at a journal and/or we feel that we have enough peer-review feedback, we have started linking GitHub repos to Zenodo. Zenodo provides an independent and versioned archive via a DOI and can be easily linked to existing GitHub repos with minimal setup.

== What comes next?
<what-comes-next>
Now that we have a birds eye view of the basic workflow, it is time to fill in a few more details. In the following six chapters, I briefly unpack some of the key themes that arise in almost any research project. I do this in the rough chronology of a research project, which starts from planning and runs to dissemination.

= Planning
<sec-planning>
#block[
#callout(
body: 
[
Spend more time planning, and run fewer experiments @scheelWhyHypothesisTesters2021@gelman2024before.

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
Planning is the part of the research process that gets surprisingly little attention in methods training in my view, given the impact that it has on everything else that follows. It is more common for methods classes to focus on what to do once you have the data in hand. This is unfortunate because the decisions made before data collection regarding such things as research design, theory, hypotheses, methodology, sampling and analysis strategy constrain what can be reasonably claimed afterwards.

And there's no need to take my word for it. Andrew Gelman is a statistician who knows a fair bit about sophisticated statistical analyses, and yet he has this to say:

"once the data have been collected, the most important decisions have already been done".

--- Andrew Gelman (#cite(<gelman2024before>, form: "year")).

Compared to the other chapters in this section, this chapter on planning feels the most diffuse, wide-ranging and impactful. The sheer number, depth and complexity of themes that seem like reasonable considerations could constitute a book in their own right. Set within this context, the best I can offer at this stage is to stress the importance of planning and the myriad forms that such planning might take @scheelWhyHypothesisTesters2021. To this end, below I highlight some themes and decision spaces that we find ourselves in on a regular basis. These decision spaces are supposed to highlight the difficulties that we often face in planning studies, rather than to provide a neat set of solutions.

Set within this context, each decision space outlined below typically prompts the recognition that much more reading is required before making any final decisions. Wider and deeper reading often also makes it clear that a collaboration with other colleagues may also be necessary. The planning process is not linear, but better represented as a cycle of many different conversations and considerations. It is also an iterative process, where each section can feed into and help inform other sections. A decision on whether to start a project, as well as how it should be designed, requires an overall assessment and integration of many different factors. I highlight some of these factors and associated questions in the subsections that follows.

== Aims
<aims>
Aims and objectives should be clear and honest #footnote[What I mean by honest is that a particular theory is not retro-fitted onto the paper once the study has been completed, just because journal editors and reviewers demand "theory-driven research".].

Here are some questions that we routinely ask ourselves:

- What kind of research is being conducted, or what "mode" of science are you operating in? And what literature is being used to determine this?
- Is it helpful to consider a continuum between exploratory and confirmatory research, and how is the distinction being operationalised @feestMoreAccurateNotion2025?
- Are there particular parts of the project that are more or less exploratory or confirmatory?
- Is the work trying to generate hypotheses that can be tested in future research, or confirm clearly specified hypotheses?
- Is the work theory-driven or more focussed on observing and detecting phenomena?

== Expectations
<expectations>
We have conversations about likely expectations, given our current background knowledge of the literature and from running prior studies.

- What is the "Hollywood result" or best outcome that we could expect?
- Are we happy if the results are suggestive at best, or inconclusive?
- Can we run a simulation study to calibrate likely expectations @heathcoteDynamicModelsChoice2019@stevensonEMC2PackageCognitive2025?
- Can a multi-experiment approach mitigate the limits of a single experimental approach?

== Feasibility
<feasibility>
We also routinely ask these questions about feasibility.

- What resources are available, in terms of money, people, equipment and time, to support the project?
- Do we think the cost-benefit is worthwhile?
- In terms of opportunity cost, what other projects could we run instead?
- Can we afford to run multi-method or multi-experiment projects?
- Do we need to setup formal collaborations to deepen and broaden the scope of expertise in the project?

== Theory
<theory>
There is a lot to read about theory building in psychology and human neuroscience. Good starting points include classics by Paul Meehl and Douglas Hintzman @meehlTheoryTestingPsychologyPhysics1967@meehlWhySummariesResearch1990@meehlAppraisingAmendingTheories1990@hintzmanWhyAreFormal1991. More recently, there was a special issue on theory @proulxStatisticalRitualTheory2021 and many calls for how and why to build better theories in psychology @oberauerAddressingTheoryCrisis2019@devezerCaseFormalMethodology2021@navarroIfMathematicalPsychology2020@guestHowComputationalModeling2021@guestWhatMakesGood2024.

But, should all research be theory-driven? Certainly not. Keep in mind that non-theory driven research is fine too, and may actually be more suitable to the current research environment in psychology @debrouwereConceptualCunningConclusive2022.

If research is theory-driven, then some questions we routinely ask are:

- What kind of theory is being used?
- What are the features that make it a "good" theory?
- Where do hypotheses come from?
- Does the theory make distinct predictions compared to other theories?
- Do formal, mathematical models of the theory exist that quantitative predictions can be derived from?
- Are the predictions ordinal, such that the prediction is that condition A \> B, but the size of that difference is unspecified and irrelevant to the theoretical prediction? And does this matter?
- Can the research design distinguish between predictions form different theories?
- What are the current limits to theory?
- Is there non-human animal evidence that supports the theory?

== Design
<design>
This introductory textbook is a fantastic resource for anyone who uses an experimental design in their research #link("https://experimentology.io/")[experimtentology.io] @frankExperimentology2025. I strongly recommend reading it from cover to cover before running your next experiment.

== Measurement
<measurement>
What evidence is there available that the measures that you intend to use are both reliable and valid? There is a surprising lack of effort spent on addressing these questions before running experiments @scheelWhyHypothesisTesters2021@flakeMeasurementSchmeasurementQuestionable2020. And many highly cited papers and associated tasks appear uninterpretable due to a lack validity and/or reliability @higginsReadingMindEyes2022@higginsReadingMindEyes2026@husseyHiddenInvalidity152020@kulpmannMethodologicalFlexibilityIowa2026. This state of affairs should be a concern for anyone and everyone who cares about research being useful. Therefore, before running a study, ask yourself one question: what evidence do you have to demonstrate that the measures you are using are reliable and valid?

== Sampling
<sampling>
There are many different ways to determine a sample size @lakensSampleSizeJustification2022. And this table from Daniel Laken's paper nicely summarises some of the options (#ref(<tbl-lakens-justification>, supplement: [Table])).

#figure([
#table(
  columns: (14.36%, 85.64%),
  align: (left,left,),
  table.header([Type of Justification], [When is this justification applicable?],),
  table.hline(),
  [Measure entire population], [A researcher can specify the entire population, it is finite, and it is possible to measure (almost) every entity in the population.],
  [Resource constraints], [Limited resources are the primary reason for the choice of the sample size a researcher can collect.],
  [Accuracy], [The research question focusses on the size of a parameter, and a researcher collects sufficient data to have an estimate with a desired level of accuracy.],
  [A-priori power analysis], [The research question has the aim to test whether certain effect sizes can be statistically rejected with a desired statistical power.],
  [Heuristics], [A researcher decides upon the sample size based on a heuristic, general rule or norm that is described in the literature, or communicated orally.],
  [No justification], [A researcher has no reason to choose a specific sample size, or does not have a clearly specified inferential goal and wants to communicate this honestly.],
)
], caption: figure.caption(
position: top, 
[
Types of justification for sample size decisions, and when each applies. Adapted from Lakens (2022).
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-lakens-justification>


Such considerations do not solely rely on determining the number of participants to test. They can also rely on the number of data points per participant @bakerPowerContoursOptimising2021. Therefore, it is the number of observations in relation to your research design that matters.

Given that we typically use multi-level models, which account for the nested structure within the data, off the shelf tools like #link("https://www.psychologie.hhu.de/arbeitsgruppen/allgemeine-psychologie-und-arbeitspsychologie/gpower")[G\*Power] can only really be useful for a quick-and-dirty estimate. But they have limited value if a more realistic appreciation of data is desired. Instead, most often we find that simulation-based approaches are required.

=== Simulation
<simulation>
I have found the recent rise in popularity of data simulation approaches to be one of the biggest advantages to psychology and brain science research. I think it should become a core component of graduate training.

There are many reasons to simulate data throughout different phases of a scientific project @gelman2024before@debruineUnderstandingMixedEffectsModels2021. Lisa DeBruine summarises these reasons in this #link("https://debruine.github.io/talks/EMPSEB-fake-it-2023/#/title-slide")[talk]. When planning a project, one may use simulation to determine a sample size. Good examples include Solomon Kurz's blog #link("https://solomonkurz.netlify.app/tags/power/")[posts], and Lisa Debruine's R package #link("https://www.scienceverse.org/faux/")[faux{}] @debruineUnderstandingMixedEffectsModels2021. In particular, the faux package #link("https://www.scienceverse.org/faux/articles/")[vignettes] are excellent resources to get a foothold in the world of data simulation for planning purposes. I have also written up a worked example of planning via simulation in the context of education research, which outlines some key steps in the process (see this book #link("https://rich-ramsey.github.io/li-lab-workflow/01-planning.html")[chapter]\; #cite(<RamseyliLabworkflow2026>, form: "prose")).

== Pre-registration
<pre-registration>
Lots has been written about the pros and cons of pre-registration @krypotosPreregistrationDefinitionAdvantages2022@p.simmonsPreregistrationWhyHow2021@nosekPreregistrationHardWorthwhile2019. For instance, preregistation has several benefits built-in by design as it prevents p-hacking, HARKing, and publication bias, whilst also placing constraints on underpowered studies @scheelExcessPositiveResults2021@lakensBenefitsPreregistrationRegistered2024. But it is just one tool, and therefore it has a restrictive use case, which does not apply to all forms of science.

My group has been routinely pre-registering experiments since 2017. In our experience, it fundamentally changes the conversation that team members have before running the study. The depth of discussion is qualitatively different if you have to address concrete and hard questions before you run the study, and you know that you will be accountable to those decisions after you get the data.

It often forces a reckoning about the actual aims of the research and/or the resources available. In many situations, during the process of drafting a pre-registration, it made us realise that we were not ready or able to run the experiment that we had initially conceived. So, we changed the project in substantial ways, or we simply didn't run the study at all. Overall, the process has been really beneficial in using resources more efficiently in our view. For more of my thoughts on pre-registration, see this book #link("https://rich-ramsey.github.io/li-lab-workflow/02-prereg.html")[chapter] @RamseyliLabworkflow2026.

= Data Management
<sec-data-management>
#block[
#callout(
body: 
[
Read this book by #link("https://cghlewis.com/")[Chrystal Lewis] from cover to cover @lewisDataManagementLargeScale2024, and check out here fabulous #link("https://cghlewis.com/blog")[blog posts].

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
Data management is the least glamorous part of the research workflow and probably one of the most foundational. The decisions made about how to structure, name, and document data before and during collection determine how smoothly everything downstream goes, as well as the degree to which FAIR principles are satisfied. Retrofitting good data management onto a badly organised dataset is painful. Starting with it costs very little. And it is something that my team and I could very much improve upon.

This is another big topic, one that fills an entire book @lewisDataManagementLargeScale2024. Here, I just highlight five aspects that do not cost too much time or effort, but really add value in our experience.

+ A data management plan.
+ A project-level README file.
+ Data dictionaries.
+ A style guide.
+ Open file formats.

And once you set these up for one project, many of the basic features generalise to other similar projects. This means that you can benefit form efficiency savings since they do not need to be created from scratch for every project.

== The data management plan
<the-data-management-plan>
Data management plans typically consist of a short document (\< 5 pages), which is written before the data are collected, and that details the key aspects of how the data will be managed. Use the data management plan to focus your team's efforts on setting up a roadmap to achieving FAIR data. And keep it in the project repository so that team members can see it and others can see it once the project is made public. Data management plans are becoming more common as funders and ethical committees seek assurance that the data will be managed safely and efficiently.

== A project-level README file
<a-project-level-readme-file>
As already mentioned in the #ref(<sec-infrastructure>, supplement: [Chapter]) section, each project has a #link("https://www.makeareadme.com/")[README file] at the root directory. A README file outlines details of the repository, such as folder and file structures, as well as requirements for using the data and code. When anyone lands on a project folder, including future you, then they would immediately be directed to the README file to be oriented to what the repository contains. In our experience, the information in a README file is typically already known and written down somewhere, such as in a lab notes document. Therefore, routinely writing a README file just encourages the team to write these notes in a more consistent way and in one place. In our experience, if baked on from the start of a project, it does not create "extra work", it just forces you to work more consistently.

== Data dictionaries
<data-dictionaries>
A data dictionary is a standardised way of reporting features of all variables in a dataset. Every person who has worked with behavioural data has at some point encountered a dataset where it is unclear which way round the coding goes. A data dictionary makes that unambiguous. To make this concrete, consider a typical reaction time dataset with five variables. First, we simulate the data and take a look at the first few rows.

#figure([
#table(
  columns: 5,
  align: (left,left,left,right,right,),
  table.header([subj], [item], [condition], [rt], [acc],),
  table.hline(),
  [01], [01], [congruent], [475], [1],
  [01], [01], [incongruent], [738], [1],
  [01], [02], [congruent], [645], [1],
  [01], [02], [incongruent], [669], [0],
  [01], [03], [congruent], [530], [1],
  [01], [03], [incongruent], [577], [1],
)
], caption: figure.caption(
position: top, 
[
First six rows of a simulated reaction time dataset.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-rt-head>


The dataset has 200 rows (10 participants × 10 items × 2 conditions) and 5 variables. Notice that #NormalTok("subj"); and #NormalTok("item"); are zero-padded strings rather than integers. This is a small but important choice that ensures correct alphabetical sorting and avoids accidental arithmetic on ID variables.

Now here is the corresponding data dictionary. Every variable is documented with its name, a plain-language label, type and format, allowable values, units where applicable, and whether it is a primary collected variable or derived from other variables.

#figure([
#table(
  columns: (9.01%, 22.52%, 9.01%, 27.93%, 24.32%, 7.21%),
  align: (left,left,left,left,left,left,),
  table.header([Variable], [Label], [Type], [Format], [Allowable values], [Origin],),
  table.hline(),
  [subj], [Participant identifier], [character], [zero-padded string (e.g.~'01')], [01 -- 10], [primary],
  [item], [Stimulus item identifier], [character], [zero-padded string (e.g.~'01')], [01 -- 10], [primary],
  [condition], [Trial condition], [character], [string], [congruent, incongruent], [primary],
  [rt], [Reaction time], [numeric], [milliseconds (ms)], [positive numeric], [primary],
  [acc], [Response accuracy], [integer], [binary], [0 = incorrect, 1 = correct], [primary],
)
], caption: figure.caption(
position: top, 
[
Data dictionary for the simulated reaction time dataset.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-rt-dictionary>


A few things worth noting about this dictionary:

- The #NormalTok("subj"); and #NormalTok("item"); columns are documented as character strings, not integers, which reflects how they are actually stored.
- The #NormalTok("acc"); column documents the coding explicitly (0 = incorrect, 1 = correct).

The dictionary itself should be stored as a plain CSV file alongside the data. That way it is machine-readable, version-controlled, and readable by anyone without specialist software.

== A style guide
<a-style-guide>
Adopting a style guide within a lab aids in standardisation within and across projects. A style guide simply means consistent and standardised way of doing things, such as naming folder and files. For example, #cite(<lewisDataManagementLargeScale2024>, form: "prose") suggests being consistent in the following processes:

+ Directory structures.
+ File naming.
+ Variable naming.
+ Assigning variable values.
+ Writing code.

Although this seems a bit fussy, it makes your data science life so much easier. And like any other standardisation procedure, it makes it so much easier for collaborators, lab members and anyone else to quickly get on board with your data science workflow.

== Open data formats
<open-data-formats>
Data should be stored in open (non-proprietary) file formats, such as CSV for tabular data, so that they can be accessed by any software.

= Data Processing
<sec-data-processing>
#block[
#callout(
body: 
[
Learn to love #link("https://tidyr.tidyverse.org/articles/tidy-data.html")[tidy data] and the #link("https://tidyverse.org/")[tidyverse] @wickhamDataScience2023

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
Data processing, which typically involves re-shaping and cleaning data, is where most of the actual work happens and where methods sections can fall somewhat silent. A typical paper will describe the design in detail and the statistical model at length, and then dispose of everything in between with a far briefer set of notes and rest on allusions to "standard preprocessing." This is where decisions that can affect the results are made. And it is therefore fundamental that these steps are made explicit via code and easy to reproduce.

Here I do not focus on specific decisions, such as setting exclusion criteria. Instead, I want to focus on the more general aspects of our chosen workflow.

== A reproducible analysis pipeline
<a-reproducible-analysis-pipeline>
Analysis code should be a record of decisions, not just the instructions for a computer. Quarto documents, therefore, by mixing code and prose, can be a useful ally by serving as a processing notebook.

The raw-to-processed pipeline should be fully reproducible from a script. This means that you, or anyone else in theory, could reproduce the analysis steps at any point in time. And it means that any changes to analysis decisions can be easily made with the consequent changes to data and figures easily implemented.

== The "tidy" data format
<the-tidy-data-format>
#link("https://tidyr.tidyverse.org/articles/tidy-data.html")[Tidy data] is long format data rather than wide format data. This means one observation is recorded per row of a data structure. We find this helpful for many reasons:

+ It makes data visualisation easy and natural in ggplot2 #ref(<sec-data-visualisation>, supplement: [see]).
+ The structure is suitable for fitting multi-level regression models, which is our default approach to inferential modelling.
+ Team members (and anyone else) can expect and understand a certain data format, which aids collaboration, peer-review and ease of re-use.
+ If another format is required, we like the idea that one default version is in the tidy, long format.
+ Summary data can easily be calculated in variety of forms.

== The ease of "dplyr" commands
<the-ease-of-dplyr-commands>
My feelings about using R + Tidyverse tools for data science is nicely summarised in this #link("https://borkar.substack.com/p/unlocking-zen-powerful-analytics")[post] by Amol Borkar.

More specifically, I like using dplyr verbs for at least four reasons.

+ The syntax is easy to understand and relies on a small set of verbs.
+ They can be piped into a chain and easily commented.
+ They are designed to naturally integrate with data visualisation via ggplot2.
+ They fit nicely into a functional programming approach, which makes it easy to write compact loops.

In the following subsections, I outline each of these benefits in a little more detail.

#heading(level: 3, numbering: none)[\(1) Syntax for common dplyr verbs]
<syntax-for-common-dplyr-verbs>
#figure([
#table(
  columns: (15.73%, 44.94%, 39.33%),
  align: (left,left,left,),
  table.header([Verb], [Purpose], [Example],),
  table.hline(),
  [#NormalTok("filter()");], [Keep rows matching a condition], [#NormalTok("filter(rt > 200)");],
  [#NormalTok("select()");], [Keep or drop columns by name], [#NormalTok("select(id, condition, rt)");],
  [#NormalTok("mutate()");], [Create or transform columns], [#NormalTok("mutate(log_rt = log(rt))");],
  [#NormalTok("summarise()");], [Collapse rows to summary statistics], [#NormalTok("summarise(mean_rt = mean(rt))");],
  [#NormalTok("arrange()");], [Sort rows by one or more columns], [#NormalTok("arrange(desc(rt))");],
  [#NormalTok("group_by()");], [Define groups for subsequent operations], [#NormalTok("group_by(participant, condition)");],
  [#NormalTok("rename()");], [Rename columns], [#NormalTok("rename(response_time = rt)");],
  [#NormalTok("distinct()");], [Keep unique rows], [#NormalTok("distinct(participant)");],
  [#NormalTok("count()");], [Count observations by group], [#NormalTok("count(condition)");],
  [#NormalTok("left_join()");], [Join two data frames by a key column], [#NormalTok("left_join(data, demo, by = 'id')");],
)
], caption: figure.caption(
position: top, 
[
Core dplyr verbs and their purpose
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-dplyr-verbs>


#heading(level: 3, numbering: none)[\(2) Piping verbs together]
<piping-verbs-together>
The real power of dplyr is chaining verbs with the pipe operator (#NormalTok("|>");). Each step reads as a plain-English instruction, and comments make the intent explicit.

#block[
#Skylighting(([#FunctionTok("library");#NormalTok("(tidyverse)");],
[#FunctionTok("library");#NormalTok("(palmerpenguins)");],
[],
[#CommentTok("# Start with the penguins dataset");],
[#NormalTok("penguins ");#SpecialCharTok("|>");],
[#NormalTok("  ");#CommentTok("# Remove rows with missing values in key columns");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(");#SpecialCharTok("!");#FunctionTok("is.na");#NormalTok("(bill_length_mm), ");#SpecialCharTok("!");#FunctionTok("is.na");#NormalTok("(body_mass_g)) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#CommentTok("# Keep only the columns we need");],
[#NormalTok("  ");#FunctionTok("select");#NormalTok("(species, island, bill_length_mm, body_mass_g, sex) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#CommentTok("# Create a new column: body mass in kg");],
[#NormalTok("  ");#FunctionTok("mutate");#NormalTok("(");#AttributeTok("body_mass_kg =");#NormalTok(" body_mass_g ");#SpecialCharTok("/");#NormalTok(" ");#DecValTok("1000");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#CommentTok("# Group by species and sex");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(species, sex) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#CommentTok("# Summarise to get mean bill length and body mass per group");],
[#NormalTok("  ");#FunctionTok("summarise");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("n =");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("    ");#AttributeTok("mean_bill =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(bill_length_mm),");],
[#NormalTok("    ");#AttributeTok("mean_mass =");#NormalTok(" ");#FunctionTok("mean");#NormalTok("(body_mass_kg),");],
[#NormalTok("    ");#AttributeTok(".groups =");#NormalTok(" ");#StringTok("\"drop\"");],
[#NormalTok("  ) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#CommentTok("# Sort by mean bill length, descending");],
[#NormalTok("  ");#FunctionTok("arrange");#NormalTok("(");#FunctionTok("desc");#NormalTok("(mean_bill))");],));
#block[
#Skylighting(([#NormalTok("# A tibble: 8 × 5");],
[#NormalTok("  species   sex        n mean_bill mean_mass");],
[#NormalTok("  <fct>     <fct>  <int>     <dbl>     <dbl>");],
[#NormalTok("1 Chinstrap male      34      51.1      3.94");],
[#NormalTok("2 Gentoo    male      61      49.5      5.48");],
[#NormalTok("3 Chinstrap female    34      46.6      3.53");],
[#NormalTok("4 Gentoo    <NA>       4      45.6      4.59");],
[#NormalTok("5 Gentoo    female    58      45.6      4.68");],
[#NormalTok("6 Adelie    male      73      40.4      4.04");],
[#NormalTok("7 Adelie    <NA>       5      37.8      3.54");],
[#NormalTok("8 Adelie    female    73      37.3      3.37");],));
]
]
The pipeline above is a readable record of every data transformation decision. Each step is independently understandable, and the comments make it easy to return to six months later.

#heading(level: 3, numbering: none)[\(3) Seamless integration with ggplot2]
<seamless-integration-with-ggplot2>
Because dplyr and ggplot2 share the same data grammar, a pipeline can flow directly into a plot.

#Skylighting(([#CommentTok("# Start with the penguins dataset");],
[#NormalTok("penguins ");#SpecialCharTok("|>");],
[#NormalTok("  ");#CommentTok("# Remove rows where sex is missing");],
[#NormalTok("  ");#FunctionTok("filter");#NormalTok("(");#SpecialCharTok("!");#FunctionTok("is.na");#NormalTok("(sex)) ");#SpecialCharTok("|>");],
[#NormalTok("  ");#CommentTok("# Map species to x-axis, bill length to y-axis, colour by sex");],
[#NormalTok("  ");#FunctionTok("ggplot");#NormalTok("(");#FunctionTok("aes");#NormalTok("(");#AttributeTok("x =");#NormalTok(" species, ");#AttributeTok("y =");#NormalTok(" bill_length_mm, ");#AttributeTok("colour =");#NormalTok(" sex)) ");#SpecialCharTok("+");],
[#NormalTok("  ");#CommentTok("# Plot individual observations, jittered slightly to reduce overplotting");],
[#NormalTok("  ");#FunctionTok("geom_jitter");#NormalTok("(");#AttributeTok("width =");#NormalTok(" ");#FloatTok("0.05");#NormalTok(", ");#AttributeTok("alpha =");#NormalTok(" ");#FloatTok("0.4");#NormalTok(", ");#AttributeTok("size =");#NormalTok(" ");#FloatTok("1.5");#NormalTok(") ");#SpecialCharTok("+");],
[#NormalTok("  ");#CommentTok("# Human-readable axis and legend labels");],
[#NormalTok("  ");#FunctionTok("labs");#NormalTok("(");],
[#NormalTok("    ");#AttributeTok("title =");#NormalTok(" ");#StringTok("\"Penguin bill length by sex and species\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("x =");#NormalTok(" ");#StringTok("\"Species\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("y =");#NormalTok(" ");#StringTok("\"Bill length (mm)\"");#NormalTok(",");],
[#NormalTok("    ");#AttributeTok("colour =");#NormalTok(" ");#StringTok("\"Sex\"");],
[#NormalTok("  ) ");#SpecialCharTok("+");],
[#NormalTok("  ");#CommentTok("# Clean minimal theme with base font size 13");],
[#NormalTok("  ");#FunctionTok("theme_minimal");#NormalTok("(");#AttributeTok("base_size =");#NormalTok(" ");#DecValTok("13");#NormalTok(")");],));
#figure([
#box(image("08-data-processing_files/figure-typst/fig-rt-plot-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Bill length by species and sex in the Palmer Penguins dataset. Points show individual observations; error bars show 95% confidence intervals.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-rt-plot>


The pipeline from raw data to final figure is a single unbroken chain. The wrangling and the visualisation are in one place, which means the figure is always reproducible from the data without any intermediate steps that could be lost or forgotten.

#heading(level: 3, numbering: none)[\(4) Functional programming]
<functional-programming>
Functional programming is a compact way to avoid writing step-by-step loops. For more information, see this #link("https://www.youtube.com/watch?v=rz3_FDVt9eg")[talk] by Hadley Wickham and this #link("https://purrr.tidyverse.org/articles/purrr.html")[vignette] of the tidyverse purrr package. We find it helpful to think about data wrangling in this way, and we suspect it reduces the number of bugs in our code.

= Data Visualisation
<sec-data-visualisation>
#block[
#callout(
body: 
[
Make your data sing with #link("https://ggplot2.tidyverse.org/")[ggplot2] @nordmannDataVisualizationUsing2022@healyDataVisualizationPractical2019.

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
Visualisation is not a final step. It is a practice that runs through the entire research workflow from data simulation, to the first look at raw data to the figures in a paper. Treating it as decoration, something to be polished once the analysis is done, misses most of its value.

We actually do not find the process of data visualisation to be particularly intuitive or easy, and we are always trying to find better ways to plot aspects of our data and models. Fortunately, help is at hand, as there are several excellent resources that have helped develop our thinking and that warrant a close read in our view @healyDataVisualizationPractical2019@nordmannDataVisualizationUsing2022@gabryVisualizationBayesianWorkflow2019@kayGgdistVisualizationsDistributions2024.

== Guiding principles
<guiding-principles-1>
- Visualisation is an essential part of data analysis, rather than a decoration.
  - We of course use it to understand our data and to communicate with others easily.
  - But we also use it in an iterative manner as a code check on data processing steps. For example, when adding a new wrangling step we would typically plot-wrangle-plot, to see that the process worked as intended.
  - Likewise, with model objects, there are many different ways that visualisation can make complex processes easier to understand by adding checks and balances throughout @gabryVisualizationBayesianWorkflow2019.
- We try to show as much of the raw data as possible, and not just the summary data. This is because plots reveal what you don't see in a table of summary statistics, as nicely illustrated by #link("https://en.wikipedia.org/wiki/Anscombe%27s_quartet")[Anscombe's quartet] and the #link("https://en.wikipedia.org/wiki/Datasaurus_dozen")[datasaurus dozen].
- Uncertainty should be made visible via interval estimates and visualisations of posterior distributions.
- Avoid bar charts for continuous data --- raincloud plots, violin plots, dot plots are preferred.
- Use a consistent style or theme across a project.
- Request pre-publication peer-review of figures. Given the vast range of options in terms of aesthetics and layouts, we seek pre-publication feedback on our plots as we work through the analytical process.

== Our current stack
<our-current-stack>
- #link("https://ggplot2.tidyverse.org/")[ggplot2] as the foundation.
- #link("https://mjskay.github.io/ggdist/")[ggdist] for distributional plots and posterior visualisation of model objects.
- #link("https://patchwork.data-imaginist.com/")[patchwork] for multi-panel figures.

== Some examples
<some-examples>
The four plots below illustrate the guiding principles described above, using the #NormalTok("palmerpenguins"); dataset throughout. They are assembled into a single figure using #NormalTok("patchwork");.

We first get some data and fit a model in brms.

And then we show some plots. The top row is raw data. The bottom row is from the fitted model object.

#figure([
#box(image("09-data-visualisation_files/figure-typst/fig-dataviz-examples-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Four visualisation approaches illustrated using the Palmer Penguins dataset. (A) Distribution check: density plots with a rug for spotting outliers after wrangling. (B) Raincloud plot: raw data, distribution, and summary in one panel. (C) Posterior predictive check: observed data density (dark) overlaid with draws from the posterior predictive distribution (light), as a model fit check. (D) Quantile intervals: median with 66%, and 95% intervals to show uncertainty.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-dataviz-examples>


= Inferential Workflow
<sec-inferential-workflow>
#block[
#callout(
body: 
[
Establish a workflow for making inferences, which is general enough that it can be used in a wide range of settings @mcelreathStatisticalRethinkingBayesian2020@gelmanBayesianWorkflow2026.

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
The approach described here follows aspects of Bayesian workflows that have been outlined by several researchers @mcelreathStatisticalRethinkingBayesian2020@kruschkeDoingBayesianData2015@gelmanBayesianWorkflow2020@gelmanBayesianWorkflow2026. We implement the approach in R using #link("https://paulbuerkner.com/brms/")[brms] and #link("https://mc-stan.org/")[Stan]. Of course, this is not the only principled approach to data analysis. It is the one we use, and it is general enough to handle the vast majority of data structures encountered in cognitive and brain science.

A disclaimer: we do not use the entire workflow in every project (although I wish we did). Instead, given that we find the general approach very satisfying, and we borrow from it whenever we can in combination with other tools and approaches. In the subsections that follow, we outline key features of our preferred inferential workflow, along with some cautionary notes and examples.

== Why an inferential workflow?
<why-an-inferential-workflow>
The term "statistical analysis" often implies a single inferential step based on the output of a regression model or statistical test. Instead, we try to embrace a workflow approach to inference, which involves a series of decisions about model structure, prior specification, checking, and interpretation that requires iteration and judgement at every stage @gelmanBayesianWorkflow2020@gelmanStatisticalWorkflow2026. The distinction matters because it changes what you are trying to do. You are not trying to produce a p-value in a ritualistic manner @gigerenzerStatisticalRitualsReplication2018. You are trying to build a model of the process that generated your data, check whether it is a reasonable model, and use it to update your uncertainty about the question you started with. Fully and consistently embracing a worked-up inferential workflow remains an ambition for my group, rather than a consistent reality. But the change in mindset from a testing strategy to a workflow fundamentally changes what you might be able to expect from a research endeavour.

== Caution first, last and always
<caution-first-last-and-always>
A fancy inferential model cannot fix a broken research design or poor measurement practices. In other words, avoid making Champagne inferences on a beer budget. I return to this quote by Andrew Gelman, as I think it is worth repeating:

"once the data have been collected, the most important decisions have already been done".

--- Andrew Gelman (#cite(<gelman2024before>, form: "year")).

And I also note the cautionary conclusion to Richard McElreath's textbook on building statistical models @mcelreathStatisticalRethinkingBayesian2020. He makes it clear that #strong[all] statistical models are fundamentally limited and need to be framed within the wider scientific context, such as:

#block[
#block[
- The importance of theory
- Open data and materials
- Pre-registration
- Meta-analyses

]
#block[
- Computational modelling
- Data science
- Experimental design
- And many more besides

]
]
== Estimation with uncertainty vs hypothesis testing
<estimation-with-uncertainty-vs-hypothesis-testing>
We follow an estimation with uncertainty approach to Bayesian regression. Such approaches aim to quantify plausible values and their associated uncertainty in relation to a research question. Krushcke & Liddell @kruschkeBayesianNewStatistics2018 provide a nice comparison of the difference between estimation with uncertainty and hypothesis testing via the use of p-values or Bayes factors (#ref(<fig-kruschke>, supplement: [Figure])).

#figure([
#box(image("img/kruschke_fig1.png", alt: "Comparison of estimation, hypothesis testing, in frequentist and Bayesian workflows."))
], caption: figure.caption(
position: bottom, 
[
Adapted from Figure 1 in #cite(<kruschkeBayesianNewStatistics2018>, form: "prose").
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-kruschke>


Importantly, both estimation and hypothesis testing approaches can be used to evaluate the evidence for or against hypotheses. The difference is that hypothesis tests require some form of arbitrary cut-off, which can lead to dichotomous thinking. In contrast, estimation approaches have no bright lines to form inferences, and instead require some evaluative thinking to summarise the sign, size and precision of the estimate in the context of the specifics of the research domain @cummingNewStatisticsWhy2014@frankExperimentology2025@kruschkeBayesianNewStatistics2018@mcelreathStatisticalRethinkingBayesian2020. The additional benefit is that the outcome can remain closer to a meaningful value of interest, rather than a p-value statistic or Bayes factor. For a longer treatment of what I like about Bayesian estimation approaches and some practical examples, see this #link("https://rich-ramsey.com/posts/2023-07-14_data_analysis_workflow/")[blog post].

Here I just illustrate the basic idea in a few plots to give you a sense of the general approach. Let's say you ran an experiment measuring reaction times between two experimental conditions. You predict that condition A will lead to longer reaction times that condition B. You calculate the contrast between two conditions and evaluate the outcome. Here are four possibilities based on simulated data, just to illustrate the process.

#figure([
#box(image("10-inferential-workflow_files/figure-typst/fig-estimation-scenarios-1.svg"))
], caption: figure.caption(
position: bottom, 
[
Four possible outcomes when estimating an effect with uncertainty. In each panel the posterior distribution summarises plausible values of the effect (e.g., a difference in reaction time between conditions, in ms). The vertical dashed line marks zero (no effect). The skyblue portion of each distribution is above zero; the grey portion is below. Inner and outer intervals show 66% and 95% quantile intervals respectively.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-estimation-scenarios>


The key point across these four scenarios is that each requires reasoning about the posterior distribution in the context of your research question. What counts as a meaningful effect size in your domain? How much precision do you need before acting on a finding? These are scientific questions, not statistical ones, and they have no universal answer. The advantage of the estimation approach is that it keeps those questions visible rather than collapsing them into a binary decision.

Note also that scenario B, which produces inconclusive evidence, is not a failure. It provides useful information. The data are consistent with a range of values in positive and negative directions, including both meaningful effects and negligible ones, which suggests a follow-up study with better precision is warranted.

This is where the connection to replication and multi-study approaches matters. Rather than asking whether a result "replicated" in a binary sense, the estimation approach asks whether the new posterior, informed by more and better data, narrows the uncertainty enough to draw a clearer conclusion. A pre-registered follow-up with an improved research design and a larger sample is not a test of whether the original finding was "real". It is just the next step in a cumulative process of estimation, each study refining the picture. The tools are the same throughout. Summarise a distribution, evaluate the sign, size, and interval, and reason about what that means for the question at hand. No arbitrary thresholds required.

== Multilevel models as a sensible default
<multilevel-models-as-a-sensible-default>
Richard McElreath's textbook @mcelreathStatisticalRethinkingBayesian2020 suggests that starting with the expectation that your data might be best modelled using a multi-level structure is not a bad idea. If it turns out that a simpler, single level model is most appropriate, then that's fine. In our experience working in cognitive psychology and neuroscience, where data typically spans repeat observations within participants and/or stimulus types, this default expectation is sensible. We also adopt a maximal varying effects structure whenever possible, based on the suggestions by Dale Barr and colleagues @barrRandomEffectsStructure2013. And this is one reason why we use a Bayesian approach to building regression models because frequentist equivalents, such as those built lme4, frequently fail to converge. On a practical level, therefore, we are able to consistently fit fairly complex models, with the cost being that they take more time to setup and they take longer to build.

== The value of posterior predictions
<the-value-of-posterior-predictions>
Posterior predictions are predicted data values that are generated from your model. They can be useful for at least two reasons. First, as part of a model checking procedure, they can be useful to check that your model can create data looks like the original data. Second, to draw inferences, rather than interpret coefficients and model parameters, it can often be more intuitive to take complex models and make predictions in the natural scale that the observations were made in @arel-bundockHowInterpretStatistical2024@arel-bundockModelMeaningHow2025@rohrerModelsPredictionMachines2026. Rather than trying to directly interpret parameters in a regression model, you get values on the natural scale as a function of the research design. This textbook by Vincent Arel-Bundock #link("https://marginaleffects.com/")[Model to meaning] is a really helpful starting point with easy-to-use code and practical examples.

= Dissemination
<sec-dissemination>
#block[
#callout(
body: 
[
Use #link("https://quarto.org/")[#NormalTok("quarto");] for everything. It is magical.

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
Dissemination encapsulates something far broader and more diverse than a static pdf journal article. It includes preprints, talks, posters, blog posts, code releases, data deposits, and the various other ways that work leaves the lab and enters the world. It is also the point at which FAIR stops being a plan and hopefully becomes a reality.

== Why write scientific material in Quarto?
<why-write-scientific-material-in-quarto>
Quarto relies on markdown as a #link("https://plain-text.co/")[plain text format] that was designed to be easy to read and write with (see #link("https://quarto.org/docs/authoring/markdown-basics.html")[markdown basics] for details). Compared to a word processor like MS Word, the main conceptual distinction is that the source content appears in a different format to the appearance of the document that it outputs. The source format is largely plain text and code chunks, whereas the output format depends on what you want to produce (e.g., .html, pdf, presentation slides etc.). So, there is a clear and obvious separation of the content from the formatting.

There are several advantages to writing scientific documents in Quarto:

- it generates fully reproducible documents.
- prose and code (in multiple programming languages) are combined.
- easy integration with version control systems that provide a single source of truth.
- collaboration can easily be coordinated via shared access to a repository.
- one common workflow can output to a variety of formats, such as websites, blogs, books, scientific reports, presentations.
- extensions, like #link("https://github.com/mvuorre/quarto-preprint")[#NormalTok("quarto-preprint");] automate the formatting, so you can focus on the content.
- citations are seamlessly integrated.
- it is free and open source.

And there is one legitimate limitation:

- if your collaborators are not familiar with using Quarto and markdown documents, then it can be less straightforward.

Here is how we approach this issue. We output a pdf or MS word document and send it to collaborators and ask for their written feedback. We then incorporate that feedback into the version-controlled manuscript file with the project repository. This process typically relies on the lead author to request feedback, discuss it with the team, and then implement the changes. In practice, this is not an onerous task, and it is no worse than the torture of using track changes in MS Word. Of course, for very large collaborative teams (maybe those spanning 20 or more individuals), I would suggest that a different format is most suitable, such as a shared document, which anyone can edit.

On balance, for the vast majority of cases in my experience, Quarto is a far superior tool for writing scientific documents when compared to the dominant alternatives.

== The value of preprints
<the-value-of-preprints>
For a variety of reasons @bourneTenSimpleRules2017@AcceleratingScientificProgress2024@OpenScienceWhy2024, we preprint all of our scientific papers before we submit them to peer-review journals. Common preprint servers for psychology, neuroscience and related disciplines include #link("https://www.biorxiv.org/")[BioRxiv], #link("https://www.medrxiv.org/")[MedRxiv], #link("https://blog.psyarxiv.com/about-psyarxiv/")[PsyArXiv].

== Talks and other formats
<talks-and-other-formats>
I started writing talks in Quarto using #link("https://quarto.org/docs/presentations/revealjs/")[Revealjs]. This means that slides for #link("https://rich-ramsey.com/talks/")[talks] and #link("https://rich-ramsey.com/teaching/")[teaching] can be made using a common workflow. You can also write blog posts, websites, and books using the same underlying format.

== Make the repository public
<make-the-repository-public>
If you've followed along with the previous chapters, then this is the point in proceedings that you make the repository public (if it is not already public). This means that you typically turn any private settings to public in GitHub, the OSF or Zenodo, or wherever else you have aspects of your work stored. In practice, however, we find that we work with a public facing repository once we start writing up the paper for submission to a journal @vuorreCuratingResearchAssets2018.

= Limitations
<sec-limitations>
#block[
#callout(
body: 
[
The workflow aims to be general, rather than universal.

]
, 
title: 
[
tl;dr
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
In this chapter, I consider constraints on the generality of the workflow, as well as some potential barriers to uptake.

== Constraints on generality
<constraints-on-generality>
The outlined workflow aims to be general enough for a majority of use cases that we come into contact with. But I'm sure there are exceptions where the workflow may not transfer so effectively, and which represent necessary constraints on the generality of the proposed workflow @simonsConstraintsGeneralityCOG2017. For instance, maybe some research tools, such as MRI, EEG or pupillometry measures, generate specialised data formats and/or require specific software (FSL, SPM, EEGLAB) that may impose its own data processing pipelines. This is to be expected.

This is also where a workflow can be used as a lens to view a data science project through, rather than a toolchain with a handle that gets cranked. A one-size-fits-all workflow is unrealistic anyway, given the complex nature of scientific data and associated materials. Instead, a workflow can be seen as a toolkit, aspects of which can be deployed in a variety of contexts and across distinct projects. And one may not use #strong[any] of the tools that I presented, but instead use another set of tools to satisfy the principle that it should be a minimum expectation and routine that scientific materials are reasonably easy to verify.

== Barriers to uptake
<barriers-to-uptake>
As outlined in the #ref(<sec-overview>, supplement: [Chapter]) section, the workflow that we use spans a number of interconnected tools. And depending on your familiarity with such tools, the sheer volume can be overwhelming. If you do decide to adopt aspects of this workflow, I suggest embracing principles of effective behaviour change @poldrackHardBreakWhy2021. And watch this #link("https://en.wikipedia.org/wiki/The_Weight_of_the_Nation")[documentary] on weight loss programme effectiveness, which is instructive and engaging when it comes to thinking about principles of effective behaviour change.

Some quick starting points would be:

#block[
#set enum(numbering: "1)", start: 1)
+ Don't change everything at once, as it will be overwhelming and exhausting.
+ Take a stepwise approach that builds in new behaviours incrementally.
+ Wait for new behaviours to form habits, before adding new aspects to the workflow.
+ Prioritise low-hanging fruit first to get some easy and enjoyable wins under your belt.
]

#set bibliography(style: "apa.csl")

#bibliography(("references.bib"))

