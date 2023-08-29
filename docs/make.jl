using Documenter
using Gensimo

makedocs( sitename = "Gensimo"
        , format = Documenter.HTML()
        , modules = [Gensimo]
        , pages = [ "Overview" => "index.md"
                  , "Context" => "index.md"
                  ]
        )

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(repo = "github.com/gensimo/Gensimo.git")
