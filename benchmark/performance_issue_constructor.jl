using NFFT

N = 1024 
M = N*N 
m = 4 
σ = 2.0
pre=NFFT.LINEAR 
T=Float64 
storeDeconvolutionIdx=false
fftflags=NFFT.FFTW.ESTIMATE

x = T.(rand(2,M) .- 0.5)
  
@time p = NFFTPlan(x, (N,N); m, σ, window=:kaiser_bessel, 
             precompute=pre, fftflags, storeDeconvolutionIdx)
