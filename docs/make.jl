using Documenter
using Gensimo

makedocs( sitename = "Gensimo"
        , format = Documenter.HTML( prettyurls = get(ENV, "CI", nothing)
                                    == "true" )
        , modules = [Gensimo]
        , pages = [ "Overview" => "index.md"
                  , "Context" => "index.md"
                  , "API" => "api.md"
                  ]
        )

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(repo = "github.com/gensimo/Gensimo.git")
