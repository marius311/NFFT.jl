using Documenter, NFFT

# Updating doctests:
# 
# julia> using Documenter, NFFT
# julia> DocMeta.setdocmeta!(NFFT, :DocTestSetup, :(using NFFT); recursive=true)
# julia> doctest(NFFT, fix=true)

DocMeta.setdocmeta!(NFFT, :DocTestSetup, :(using NFFT); recursive=true)

makedocs(;
    doctest = true,
    #strict = :doctest,
    modules = [NFFT],
    sitename = "NFFT",
    authors = "Tobias Knopp and contributors",
    repo="https://github.com/JuliaMath/NFFT.jl/blob/{commit}{path}#{line}",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://tknopp.github.io/NFFT.jl",
        assets=String[],
    ),
    pages = [
        "Home" => "index.md",
        "Background" => "background.md",
        "Overview" => "overview.md",
        "AbstractNFFTs" => "abstract.md",
        "Performance" => "performance.md",
        "Tools" => "tools.md",
        #"Implementation" => "implementation.md",
        "API" => "api.md",
    ]
)

deploydocs(repo   = "github.com/JuliaMath/NFFT.jl.git")
