using Documenter
using DocumenterPlantUML
using Project4

# Doctests run in a bare module, so the package has to be brought into scope
# for them. Without this, every jldoctest fails with UndefVarError.
DocMeta.setdocmeta!(Project4, :DocTestSetup, :(using Project4); recursive = true)

makedocs(
    sitename = "Project4.jl",
    modules  = [Project4],
    # Write design.html rather than design/index.html, so that the built pages
    # can be opened from the file system. With the pretty form the links
    # between pages point at directories, which a browser cannot follow over
    # file://, and reading the documentation locally would need a web server.
    format   = Documenter.HTML(prettyurls = false),
    pages = [
        "Home"           => "index.md",
        "Project design" => "design.md",
        "Reference manual"  => "manual.md",
    ],
    # Fail the build if an exported function has no docstring.
    checkdocs = :exports,
)

# Deployment is handled by the GitHub Actions workflow in .github/workflows/docs.yml,
# which uploads docs/build directly to GitHub Pages.
