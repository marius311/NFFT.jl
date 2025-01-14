using NFFT, DataFrames, LinearAlgebra, LaTeXStrings, DelimitedFiles
using BenchmarkTools
using Plots; pgfplotsx()
using Plots.Measures

include("../../Wrappers/NFFT3.jl")
include("../../Wrappers/FINUFFT.jl")

const packagesCtor = [NFFTPlan, NFFTPlan, NFFT3Plan, FINUFFTPlan] #, NFFTPlan
const packagesStr = [ "NFFT.jl/TENSOR", "NFFT.jl/POLY", "NFFT3/TENSOR", "FINUFFT"] #"NFFT.jl/LINEAR"
const precomp = [NFFT.TENSOR, NFFT.POLYNOMIAL, NFFT.TENSOR, NFFT.LINEAR] #NFFT.LINEAR
const blocking = [true, true, true, true, true]

const benchmarkTime = [2, 2]

NFFT.FFTW.set_num_threads(Threads.nthreads())
ccall(("omp_set_num_threads",NFFT3.lib_path_nfft),Nothing,(Int64,),convert(Int64,Threads.nthreads()))
@info ccall(("nfft_get_num_threads",NFFT3.lib_path_nfft),Int64,())
NFFT._use_threads[] = (Threads.nthreads() > 1)


const σs = [2.0] 
const ms = 3:8
const NBase = [4*4096, 128, 32]
const Ds = 1:3

function nfft_accuracy_comparison(Ds=1:3)
  println("\n\n ##### nfft_performance vs accuracy ##### \n\n")

  df = DataFrame(Package=String[], D=Int[], M=Int[], N=Int[], m = Int[], σ=Float64[],
                   ErrorTrafo=Float64[], ErrorAdjoint=Float64[], 
                   TimePre=Float64[], TimeTrafo=Float64[], TimeAdjoint=Float64[],  )  

  for D in Ds
    @info "### Dimension D=$D ###"
    N = ntuple(d->NBase[D], D)
    M = prod(N)
    
    x = rand(D,M) .- 0.5
    fHat = randn(ComplexF64, M)
    fApprox = randn(ComplexF64, N)
    gHatApprox = randn(ComplexF64, M)

    # ground truth (numerical)
    pNDFT = NDFTPlan(x, N)
    f = adjoint(pNDFT) * fHat
    gHat = pNDFT * f

    for σ in σs
      for m in ms
        @info "m=$m D=$D σ=$σ "

        for pl = 1:length(packagesStr)
          planner = packagesCtor[pl]
          p = planner(x, N; m, σ, precompute=precomp[pl], blocking=blocking[pl])
          b = @benchmark $planner($x, $N; m=$m, σ=$σ, precompute=$(precomp[pl]), blocking=$(blocking[pl]))
          tpre = minimum(b).time / 1e9

          @info "Adjoint accuracy: $(packagesStr[pl])"
          mul!(fApprox, adjoint(p), fHat)
          eadjoint = norm(f[:] - fApprox[:]) / norm(f[:])

          @info "Adjoint benchmark: $(packagesStr[pl])"
          BenchmarkTools.DEFAULT_PARAMETERS.seconds = benchmarkTime[1] 
          b = @benchmark mul!($fApprox, $(adjoint(p)), $fHat)
          tadjoint = minimum(b).time / 1e9

          @info "Trafo accuracy: $(packagesStr[pl])"
          mul!(gHatApprox, p, f)
          etrafo = norm(gHat[:] - gHatApprox[:]) / norm(gHat[:])

          @info "Trafo benchmark: $(packagesStr[pl])"
          BenchmarkTools.DEFAULT_PARAMETERS.seconds = benchmarkTime[2]
          b = @benchmark mul!($gHatApprox, $p, $f)
          ttrafo = minimum(b).time / 1e9

          push!(df, (packagesStr[pl], D, M, N[D], m, σ, etrafo, eadjoint, tpre, ttrafo, tadjoint))

        end
      end
    end
  end
  return df
end



function plot_accuracy(df, packagesStr, packagesStrShort, filename)


  Plots.scalefontsizes()
  Plots.scalefontsizes(1.5)

  colors = [:black, :orange, :blue, :green, :brown, :gray, :blue, :purple, :yellow ]
  ls = [:solid, :dashdot, :solid, :solid, :solid, :dash, :solid, :dash, :solid]
  shape = [:circle, :circle, :circle, :xcross, :circle, :xcross, :xcross, :circle]

  xlims = [(4e-13,1e-5), (4e-15,1e-4),(4e-15,1e-4)]

  pl = Matrix{Any}(undef, 3, length(Ds))
  for (i,D) in enumerate(Ds)
    titleTrafo = L"\textrm{NFFT}, \textrm{%$(D)D}"
    titleAdjoint = L"\textrm{NFFT}^H, \textrm{%$(D)D}"
    titlePre = L"\textrm{Precompute}, \textrm{%$(D)D}"
    xlabel = (i==length(Ds)) ? "Relative Error" : ""

    df1_ = df[df.σ.==2.0 .&& df.D.==D,:]  
    maxTimeTrafo = maximum( maximum(df1_[df1_.Package.==pStr,:TimeTrafo]) for pStr in packagesStr)
    maxTimeAdjoint = maximum( maximum(df1_[df1_.Package.==pStr,:TimeAdjoint]) for pStr in packagesStr)
    maxTimePre = maximum( maximum(df1_[df1_.Package.==pStr,:TimePre]) for pStr in packagesStr)

    p1 = plot(df1_[df1_.Package.==packagesStr[1],:ErrorTrafo], 
              df1_[df1_.Package.==packagesStr[1],:TimeTrafo], ylims=(0.0,maxTimeTrafo),
              label = packagesStrShort[1],
              xscale = :log10, legend = (i==length(Ds)) ? (:topright) : nothing, 
              lw=2, xlabel = xlabel, ylabel="Runtime / s",
              title=titleTrafo, shape=:circle, c=:black, xlims=xlims[i])

    for p=2:length(packagesStr)      
      plot!(p1, df1_[df1_.Package.==packagesStr[p],:ErrorTrafo], 
            df1_[df1_.Package.==packagesStr[p],:TimeTrafo], 
              xscale = :log10, lw=2, shape=shape[p], ls=ls[p], 
              label =  packagesStrShort[p] ,
              c=colors[p], msc=colors[p], mc=colors[p], ms=4, msw=2)
    end

    p2 = plot(df1_[df1_.Package.==packagesStr[1],:ErrorAdjoint], 
              df1_[df1_.Package.==packagesStr[1],:TimeAdjoint], ylims=(0.0,maxTimeAdjoint),
              xscale = :log10,  lw=2, xlabel = xlabel, #ylabel="Runtime / s", #label=packagesStr[1],
              legend = nothing, title=titleAdjoint, shape=:circle, c=:black, xlims=xlims[i])

    for p=2:length(packagesStr)      
      plot!(p2, df1_[df1_.Package.==packagesStr[p],:ErrorAdjoint], 
            df1_[df1_.Package.==packagesStr[p],:TimeAdjoint], 
              xscale = :log10,  lw=2, shape=shape[p], ls=ls[p], #label=packagesStr[p],
              c=colors[p], msc=colors[p], mc=colors[p], ms=4, msw=2)
    end

    p3 = plot(df1_[df1_.Package.==packagesStr[1],:ErrorAdjoint], 
              df1_[df1_.Package.==packagesStr[1],:TimePre], ylims=(0.0,maxTimePre),
              label = (i==1) ? packagesStrShort[1] : "",
              xscale = :log10,  lw=2, xlabel = xlabel, #ylabel="Runtime / s", #label=packagesStr[1],
              title=titlePre, shape=:circle, c=:black, legend = nothing,
              xlims=xlims[i] )

    for p=2:length(packagesStr)      
      plot!(p3, df1_[df1_.Package.==packagesStr[p],:ErrorAdjoint], 
            df1_[df1_.Package.==packagesStr[p],:TimePre], 
             label = (i==1) ? packagesStrShort[p] : "",
              xscale = :log10,  lw=2, shape=shape[p], ls=ls[p], #label=packagesStr[p],
              c=colors[p], msc=colors[p], mc=colors[p], ms=4, msw=2)
    end
    pl[1,i] = p1; pl[2,i] = p2; pl[3,i] = p3; 
  end

  p = plot(vec(pl)..., layout=(length(Ds),3), size=(1200,800), dpi=200, margin = 1mm)

  mkpath("./img/")
  savefig(p, filename)
  return p
end



#df = nfft_accuracy_comparison(Ds)
#writedlm("data/performanceVsAccuracy.csv", Iterators.flatten(([names(df)], eachrow(df))), ',')

data, header = readdlm("data/performanceVsAccuracy.csv", ',', header=true);
df = DataFrame(data, vec(header))

plot_accuracy(df, [ "NFFT.jl/POLY", "NFFT.jl/TENSOR", "NFFT3/TENSOR", "FINUFFT"],
                  [ "NFFT.jl/POLY", "NFFT.jl/TENSOR", "NFFT3", "FINUFFT"], "./img/performanceVsAccuracy.pdf")

#plot_accuracy(df, [ "NFFT.jl/POLY", "NFFT.jl/TENSOR" ], #"NFFT.jl/LINEAR"  , "LINEAR"
#                  [ "POLYNOMIAL", "TENSOR"], "./img/performanceVsAccuracyPrecomp.pdf")








