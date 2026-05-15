local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local isn = ls.indent_snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local events = require("luasnip.util.events")
local ai = require("luasnip.nodes.absolute_indexer")
local extras = require("luasnip.extras")
local l = extras.lambda
local rep = extras.rep
local p = extras.partial
local m = extras.match
local n = extras.nonempty
local dl = extras.dynamic_lambda
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local conds = require("luasnip.extras.expand_conditions")
local postfix = require("luasnip.extras.postfix").postfix
local types = require("luasnip.util.types")
local parse = require("luasnip.util.parser").parse_snippet
local ms = ls.multi_snippet
local k = require("luasnip.nodes.key_indexer").new_key
local line_begin = require("luasnip.extras.expand_conditions").line_begin

ls.filetype_extend("plaintex", {"tex"})

local get_visual = function(args, parent)
  if (#parent.snippet.env.LS_SELECT_RAW > 0) then
    return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
  else  -- If LS_SELECT_RAW is empty, return a blank insert node
    return sn(nil, i(1))
  end
end

local in_mathzone = function()
  -- The `in_mathzone` function requires the VimTeX plugin
  return vim.fn['vimtex#syntax#in_mathzone']() == 1
end

-- exampe of a multiline snippet

-- ls.add_snippets("tex", {
  -- s("template", fmta([[
  -- <> <>
  -- ]], {i(1), i(0)}, {
    -- indent_string = ""
  -- }))
-- })


ls.add_snippets("tex", {
  s("template", fmta([[
\documentclass[11pt]{article}
\usepackage{amssymb}
\usepackage{amsmath}
\usepackage{listings}
\usepackage[utf8]{inputenc}
\usepackage{parskip}
\usepackage{hyperref}
\usepackage{bookmark}
\usepackage[linguistics]{forest}
\usepackage{tikz}
\usepackage{float}

\usepackage{amsmath}
\usepackage{amsthm}
\usepackage{amssymb}
\usepackage{enumitem}

\usepackage{import}
\usepackage{pdfpages}
\usepackage{transparent}
\usepackage{xcolor}

\newtheorem{all}{Theorem}[section]
\newtheorem{corollary}[all]{Corollary}
\newtheorem{lemma}[all]{Lemma}
\newtheorem{definition}[all]{Definition}
\newtheorem{exercise}[all]{Exercise}
\newtheorem{proposition}[all]{Proposition}
\newtheorem{example}[all]{Example}
\newtheorem{theorem}{Theorem}

\newenvironment{lecture}[1]{
\t\section{\MakeUppercase{#1}}
\t\vspace{-0.5em}
\t\hrule
\t\vspace{1em}
\t\begin{list}{}{
\t\t\setlength{\leftmargin}{1.5em}
\t}
\t\item[]
}{
\t\end{list}
}

\title{<>}
\author{Jake Ginesin}
\date{}

\begin{document}
\maketitle
<>
\end{document}
  ]], {i(1), i(0)}, {
    indent_string = ""
  }))
})

ls.add_snippets("tex", {
  s("template-math", fmta([[
\documentclass[11pt]{article}
\usepackage{amssymb}
\usepackage{amsmath}
\usepackage{amsthm} 
\usepackage{fullpage}
\usepackage{listings}
\usepackage[utf8]{inputenc}
\usepackage{parskip}
\usepackage{hyperref}
\usepackage{bookmark}
\usepackage[linguistics]{forest}
\usepackage{tikz}
\usepackage{float}

\usepackage{enumitem}
\usepackage{euler}
\usepackage{libertine}

\usepackage{import}
\usepackage{pdfpages}
\usepackage{transparent}
\usepackage{xcolor}

\newtheoremstyle{definitionstyle}
{}
{}
{\normalfont}
{}
{\bfseries}
{:}
{0.5em}
{}

\theoremstyle{definitionstyle}
\newtheorem{definition}{Definition}[section]

\newtheorem{all}{Theorem}[section]
\newtheorem{corollary}[all]{Corollary}
\newtheorem{lemma}[all]{Lemma}
\newtheorem{exercise}[all]{Exercise}
\newtheorem{proposition}[all]{Proposition}
\newtheorem{example}[all]{Example}
\newtheorem{theorem}{Theorem}

\title{<>}
\author{Jake Ginesin}
\date{}

\begin{document}
\maketitle
	<>
\end{document}
  ]], {i(1), i(0)}, {
    indent_string = ""
  }))
})

ls.add_snippets("tex", {
  s("template-report", fmta([[
\documentclass[10pt]{article}
\usepackage{graphicx} % Required for inserting images
\usepackage[margin=1in]{geometry}
\usepackage[dvipsnames]{xcolor}	
\usepackage{url}
\usepackage{amssymb}
\usepackage{amsmath}
\usepackage{amsthm} 
\usepackage{fullpage}
\usepackage{listings}
\usepackage[utf8]{inputenc}
\usepackage{parskip}
\usepackage{hyperref}
\usepackage{bookmark}
\usepackage[linguistics]{forest}
\usepackage{tikz}
\usepackage{float}

\usepackage[minted,skins]{tcolorbox} % 'skins' needed for shadows

% Define a new command \rustshadowfile that replaces \rustfile
\newtcbinputlisting{\rustshadowfile}[2][]{%
  listing engine=minted,
  minted language=rust,
  minted options={linenos, numbersep=5pt, fontsize=\footnotesize, baselinestretch=1.05},
  listing file={#2},       % The file to read
  enhanced,                % Enable skins for shadows
  drop shadow,             % Add the shadow
  colback=white,           % Background color
  colframe=black!70,       % Border color
  boxrule=0.5pt,           % Border width
  arc=2pt,                 % Rounded corners (optional)
  listing only,            % Display code only (no title bar inside box)
  #1                       % Pass extra options like labels
}

\newtcblisting{rustcode}[1][]{
  listing engine=minted,
  minted language=rust,
  minted options={linenos, numbersep=5pt, fontsize=\footnotesize, baselinestretch=1.05},
  enhanced,
  drop shadow,      % Adds the shadow
  colback=white,    % Background color
  colframe=black!70,% Border color
  boxrule=0.5pt,    % Border width
  arc=2pt,          % Rounded corners
  listing only,     % Hides the internal tcolorbox title bar
  #1                % Allows passing extra options
}

% \usepackage{enumitem}
% \usepackage{euler}
% \usepackage{libertine}

\usepackage{import}
\usepackage{pdfpages}
\usepackage{transparent}

\newtheoremstyle{definitionstyle}
{}
{}
{\normalfont}
{}
{\bfseries}
{:}
{0.5em}
{}

\theoremstyle{definitionstyle}
\newtheorem{definition}{Definition}[section]

\newtheorem{all}{Theorem}[section]
\newtheorem{corollary}[all]{Corollary}
\newtheorem{lemma}[all]{Lemma}
\newtheorem{exercise}[all]{Exercise}
\newtheorem{proposition}[all]{Proposition}
\newtheorem{example}[all]{Example}
\newtheorem{theorem}{Theorem}

\newcommand{\namedcomment}[3]{{\sf \scriptsize \color{#2} #1: #3}}
\newcommand{\jake}[1]{\namedcomment{jake}{red}{#1}}
\title{<>}
\author{Jake Ginesin \and <>}
\date{December 5th, 1999}

\begin{document}
\maketitle

\end{document}
  ]], {i(1), i(0)}, {
    indent_string = ""
  }))
})


ls.add_snippets("tex", {
  s("beamer", fmta([[
\documentclass{beamer}
\usetheme{metropolis}           % Use metropolis theme
\title{<>}
\date{\today}
\author{Jacob Ginesin}
\institute{<>}
\begin{document}
  \maketitle
  \section{First Section}
  \begin{frame}{First Frame}
    Hello, world!
  \end{frame}
\end{document}

  ]], {i(1), i(0)}, {
    indent_string = ""
  }))
})

ls.add_snippets("tex", {
  s("beamer", fmta([[
\documentclass{beamer}
\usetheme{metropolis}           % Use metropolis theme
\title{<>}
\date{\today}
\author{Jacob Ginesin}
\institute{<>}
\begin{document}
  \maketitle
  \section{First Section}
  \begin{frame}{First Frame}
    Hello, world!
  \end{frame}
\end{document}

  ]], {i(1), i(0)}, {
    indent_string = ""
  }))
})

ls.add_snippets("tex", {
  s("bib", fmta([[
\bibliographystyle{plain} 
\bibliography{<>}
  ]], {i(0)}, {
    indent_string = ""
  }))
})


-- ----


ls.add_snippets("tex", {
  s({trig = "ita", dscr = "Expands 'tii' into LaTeX's textit{} command."},
    fmta("\\textit{<>}",
      {
        d(1, get_visual),
      }
    )
  ),

  s({trig = "isc"},
    fmta("\\textsc{<>}",
      {
        d(1, get_visual),
      }
    )
  ),


  s({trig = "frac"},
    fmta(
      "\\frac{<>}{<>}",
      {
        i(1),
        i(2),
      }
    ),
    {condition = in_mathzone}  -- `condition` option passed in the snippet `opts` table 
  ),

  s({trig = "it"},
    fmta(
      "\\item ",
      {}
    ), {}  -- `condition` option passed in the snippet `opts` table 
  ),

  s({trig="eq", dscr="Expands 'eq' into an equation environment"},
    fmta(
       [[
         \begin{equation*}
             <>
         \end{equation*}
       ]],
       { i(1) }
    )
  ),

  s({trig="align", dscr="Expands 'eq' into an equation environment"},
    fmta(
       [[
         \begin{align*}
             <>
         \end{align*}
       ]],
       { i(1) }
    )
  ),


  s({trig="beg", 
    -- snippetType="autosnippet"
  },
    fmta(
      [[
        \begin{<>}
            <>
        \end{<>}
      ]],
      {
        i(1),
        i(2),
        rep(1),  -- this node repeats insert node i(1)
      }
    )
  ),


  s({trig="href", dscr="The hyperref package's href{}{} command (for url links)"},
    fmta(
      [[\href{<>}{<>}]],
      {
        i(1, "url"),
        i(2, "display name"),
      }
    )
  ),

  s({trig="([^%a])mk", 
    snippetType="autosnippet",
    wordTrig = false,
    regTrig = true
  },
    fmta(
      "<>$<>$",
      {
        f( function(_, snip) return snip.captures[1] end ),
        d(1, get_visual),
      }
    )
  ),

  s({trig="mk", 
    snippetType="autosnippet",
    wordTrig = false,
    regTrig = true
  },
    fmta(
      "<>$<>$",
      {
        f( function(_, snip) return snip.captures[1] end ),
        d(1, get_visual),
      }
    ),
    {condition = line_begin}
  ),

  s({trig="([^%a])dm", 
    snippetType="autosnippet",
    wordTrig = false,
    regTrig = true
  },
    fmta(
      [[
      \[
        <>
      \]
      ]],
      {
        -- f( function(_, snip) return snip.captures[1] end ),
        d(1, get_visual),
      }
    )
  ),

  s({trig="dm", 
    snippetType="autosnippet",
    wordTrig = false,
    regTrig = true
  },
    fmta(
      [[
      \[
        <>
      \]
      <>
      ]],
      {
        -- f( function(_, snip) return snip.captures[1] end ),
        d(1, get_visual),
        i(0)
      }
    ),
    {condition = line_begin}
  ),

  s({
    trig = "^^",
    snippetType="autosnippet",
  },
    fmta(
      "^{<>}",
      {
        i(1),
      }
    ),
    {condition = in_mathzone}  
  ),

  s({
    trig = "__",
    snippetType="autosnippet",
  },
    fmta(
      "_{<>}",
      {
        i(1),
      }
    ),
    {condition = in_mathzone}  
  ),

  s({
    trig = "sec",
  },
    fmta(
      [[
      \section{<>}
      \label{sec:<>}
      <>
      ]],
      {
        i(1, "section name"),
        i(2, "section label"),
        i(3),
      }
    ),
    {}  
  ),

  s({
    trig = "sub",
  },
    fmta(
      [[
      \subsection{<>}
      \label{sec:<>}
      <>
      ]],
      {
        i(1, "section name"),
        i(2, "section label"),
        i(0),
      }
    ),
    {}  
  ),

  ms({
    common = {snippetType = "autosnippet"},
    "!=",
    {trig = "neq", snippetType = "snippet"},
  },
    fmta(
      "\\neq ",
      {}
    ),
    {condition = in_mathzone} 
  ),

  ms({
    common = {snippetType = "autosnippet"},
    "<=",
    {trig = "leq", snippetType = "snippet"},
  },
    fmta(
      "\\leq ",
      {}
    ),
    {condition = in_mathzone} 
  ),

  ms({
    common = {snippetType = "autosnippet"},
    ">=",
    {trig = "geq", snippetType = "snippet"},
    {trig = "ge", snippetType = "snippet"},
  },
    fmta(
      "\\ge ",
      {}
    ),
    {condition = in_mathzone} 
  ),

  s({
    trig = "**",
    snippetType="autosnippet",
  },
    fmta(
      "\\cdot ",
      { }
    ),
    {condition = in_mathzone}  
  ),

  s({
    trig = "->",
    snippetType="autosnippet",
  },
    fmta(
      "\\to ",
      { }
    ),
    {condition = in_mathzone}  
  ),

  s({
    trig = "<->",
    snippetType="autosnippet",
  },
    fmta(
      "\\leftrightarrow ",
      { }
    ),
    {condition = in_mathzone}  
  ),

  s({trig = "rustcode"},
    fmta(
      [[
  \begin{listing}[H]
  \begin{rustcode}
  <>
  \end{rustcode}
  \end{listing}
      ]],
      { i(1) }
    )
  ),

  s({
    trig = "notin",
    snippetType="autosnippet",
  },
    fmta(
      "\\not\\in ",
      { }
    ),
    {condition = in_mathzone}  
  ),

  s({
    trig = "notin",
    snippetType="autosnippet",
  },
    fmta(
      "\\not\\in ",
      { }
    ),
    {condition = in_mathzone}  
  ),

  s({trig="lemma"},
    fmta(
       [[
         \begin{lemma}
             <>
         \end{lemma}
       ]],
       { i(1) }
    )
  ),

  s({trig="proof"},
    fmta(
       [[
         \begin{proof}
             <>
         \end{proof}
       ]],
       { i(1) }
    )
  ),

  s({trig = "bf"},
    fmta("\\textbf{<>}",
      {
        d(1, get_visual),
      }
    )
  ),

  s({
    trig = "...",
    snippetType="autosnippet",
  },
    fmta(
      "\\ldots ",
      { }
    ),
    {}  
  ),

  s({
    trig = "image",
  },
    fmta(
      [[
\begin{figure}[h]
    \centering
    \includegraphics[width=0.5\textwidth]{<>}
    \caption{<>}
    \label{fig:<>}
\end{figure}
<>
      ]],
      {
        i(1, "image.png"),
        i(2, "A great image!"),
        i(3, "image"),
        i(0)
      }
    ),
    {}  
  ),

  s({
    trig = "enum",
  },
    fmta(
      [[
\begin{enumerate}
  \item <>
\end{enumerate}
      ]],
      {
        i(0)
      }
    ),
    {}  
  ),

  s({
    trig = "item",
  },
    fmta(
      [[
\begin{itemize}
  \item <>
\end{itemize}
      ]],
      {
        i(0)
      }
    ),
    {}  
  ),


  -- s({ trig = "!=", snippetType="autosnippet" }, fmta("\\neq ", {}), {condition = in_mathzone}),
  -- s({ trig = "<=", snippetType="autosnippet" }, fmta("\\leq ", {}), {condition = in_mathzone}),
  -- s({ trig = ">=", snippetType="autosnippet" }, fmta("\\geq ", {}), {condition = in_mathzone}),
  s({ trig = "<<", snippetType="autosnippet" }, fmta("\\ll ", {}), {condition = in_mathzone}),
  s({ trig = ">>", snippetType="autosnippet" }, fmta("\\gg ", {}), {condition = in_mathzone}),
  s({ trig = "~~", snippetType="autosnippet" }, fmta("\\sim ", {}), {condition = in_mathzone}),
  s({ trig = "~=", snippetType="autosnippet" }, fmta("\\approx ", {}), {condition = in_mathzone}),
  s({ trig = "~-", snippetType="autosnippet" }, fmta("\\simeq ", {}), {condition = in_mathzone}),
  s({ trig = "-~", snippetType="autosnippet" }, fmta("\\backsimeq ", {}), {condition = in_mathzone}),
  s({ trig = "-=", snippetType="autosnippet" }, fmta("\\equiv ", {}), {condition = in_mathzone}),
  s({ trig = "=~", snippetType="autosnippet" }, fmta("\\cong ", {}), {condition = in_mathzone}),
  s({ trig = ":=", snippetType="autosnippet" }, fmta("\\definedas ", {}), {condition = in_mathzone}),
  -- s({ trig = "**", snippetType="autosnippet" }, fmta("\\cdot ", {}), {condition = in_mathzone}),
  s({ trig = "xx", snippetType="autosnippet" }, fmta("\\times ", {}), {condition = in_mathzone}),
  s({ trig = "!+", snippetType="autosnippet" }, fmta("\\oplus ", {}), {condition = in_mathzone}),
  s({ trig = "!*", snippetType="autosnippet" }, fmta("\\otimes ", {}), {condition = in_mathzone}),
  s({ trig = "NN", snippetType="autosnippet" }, fmta("\\mathbb{N} ", {}), {condition = in_mathzone}),
  s({ trig = "ZZ", snippetType="autosnippet" }, fmta("\\mathbb{Z} ", {}), {condition = in_mathzone}),
  s({ trig = "QQ", snippetType="autosnippet" }, fmta("\\mathbb{Q} ", {}), {condition = in_mathzone}),
  s({ trig = "RR", snippetType="autosnippet" }, fmta("\\mathbb{R} ", {}), {condition = in_mathzone}),
  s({ trig = "CC", snippetType="autosnippet" }, fmta("\\mathbb{C} ", {}), {condition = in_mathzone}),
  s({ trig = "OO", snippetType="autosnippet" }, fmta("\\emptyset ", {}), {condition = in_mathzone}),
  s({ trig = "pwr", snippetType="autosnippet" }, fmta("\\powerset ", {}), {condition = in_mathzone}),
  s({ trig = "cc", snippetType="autosnippet" }, fmta("\\subset ", {}), {condition = in_mathzone}),
  s({ trig = "cq", snippetType="autosnippet" }, fmta("\\subseteq ", {}), {condition = in_mathzone}),
  s({ trig = "qq", snippetType="autosnippet" }, fmta("\\supset ", {}), {condition = in_mathzone}),
  s({ trig = "qc", snippetType="autosnippet" }, fmta("\\supseteq ", {}), {condition = in_mathzone}),
  s({ trig = "Nn", snippetType="autosnippet" }, fmta("\\cap ", {}), {condition = in_mathzone}),
  s({ trig = "UU", snippetType="autosnippet" }, fmta("\\cup ", {}), {condition = in_mathzone}),
  s({ trig = "::", snippetType="autosnippet" }, fmta("\\colon ", {}), {condition = in_mathzone}),
  s({ trig = "AA", snippetType="autosnippet" }, fmta("\\forall ", {}), {condition = in_mathzone}),
  s({ trig = "EE", snippetType="autosnippet" }, fmta("\\exists ", {}), {condition = in_mathzone}),
  s({ trig = "inn", snippetType="autosnippet" }, fmta("\\in ", {}), {condition = in_mathzone}),
  -- s({ trig = "notin", snippetType="autosnippet" }, fmta("\\not\\in ", {}), {condition = in_mathzone}),
  s({ trig = "!-", snippetType="autosnippet" }, fmta("\\lnot ", {}), {condition = in_mathzone}),
  s({ trig = "VV", snippetType="autosnippet" }, fmta("\\lor ", {}), {condition = in_mathzone}),
  s({ trig = "WW", snippetType="autosnippet" }, fmta("\\land ", {}), {condition = in_mathzone}),
  s({ trig = "!W", snippetType="autosnippet" }, fmta("\\bigwedge ", {}), {condition = in_mathzone}),
  s({ trig = "=>", snippetType="autosnippet" }, fmta("\\implies ", {}), {condition = in_mathzone}),
  s({ trig = "=<", snippetType="autosnippet" }, fmta("\\impliedby ", {}), {condition = in_mathzone}),
  s({ trig = "iff", snippetType="autosnippet" }, fmta("\\iff ", {}), {condition = in_mathzone}),
  s({ trig = "->", snippetType="autosnippet" }, fmta("\\to ", {}), {condition = in_mathzone}),
  s({ trig = "!>", snippetType="autosnippet" }, fmta("\\mapsto ", {}), {condition = in_mathzone}),
  s({ trig = "<-", snippetType="autosnippet" }, fmta("\\gets ", {}), {condition = in_mathzone}),
  s({ trig = "dp", snippetType="autosnippet" }, fmta("\\partial ", {}), {condition = in_mathzone}),
  s({ trig = "-->", snippetType="autosnippet" }, fmta("\\longrightarrow ", {}), {condition = in_mathzone}),
  s({ trig = "<->", snippetType="autosnippet" }, fmta("\\leftrightarrow ", {}), {condition = in_mathzone}),
  s({ trig = "2>", snippetType="autosnippet" }, fmta("\\rightrightarrows ", {}), {condition = in_mathzone}),
  s({ trig = "upar", snippetType="autosnippet" }, fmta("\\uparrow ", {}), {condition = in_mathzone}),
  s({ trig = "dnar", snippetType="autosnippet" }, fmta("\\downarrow ", {}), {condition = in_mathzone}),
  s({ trig = "ooo", snippetType="autosnippet" }, fmta("\\infty ", {}), {condition = in_mathzone}),
  s({ trig = "lll", snippetType="autosnippet" }, fmta("\\ell ", {}), {condition = in_mathzone}),
  s({ trig = "dag", snippetType="autosnippet" }, fmta("\\dagger ", {}), {condition = in_mathzone}),
  s({ trig = "+-", snippetType="autosnippet" }, fmta("\\pm ", {}), {condition = in_mathzone}),
  s({ trig = "-+", snippetType="autosnippet" }, fmta("\\mp ", {}), {condition = in_mathzone}),

})
