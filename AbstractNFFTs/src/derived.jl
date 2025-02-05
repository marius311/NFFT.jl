
##########################
# plan_* constructors
##########################


for op in [:nfft, :nfct, :nfst]
planfunc = Symbol("plan_"*"$op")
@eval begin 

# The following automatically call the plan_* version for type Array

$(planfunc)(x::AbstractArray, N::Union{Integer,NTuple{D,Int}}, args...; kargs...) where {D} =
    $(planfunc)(Array, x, N, args...; kargs...)

$(planfunc)(x::AbstractArray, y::AbstractArray, args...; kargs...) where {D} =
    $(planfunc)(Array, x, y, args...; kargs...)

# The follow convert 1D parameters into the format required by the plan

$(planfunc)(Q::Type, x::AbstractVector, N::Integer, rest...; kwargs...) where {D}  =
    $(planfunc)(Q, collect(reshape(x,1,length(x))), (N,), rest...; kwargs...)

$(planfunc)(Q::Type, x::AbstractVector, N::NTuple{D,Int}, rest...; kwargs...) where {D} =
    $(planfunc)(Q, collect(reshape(x,1,length(x))), N, rest...; kwargs...) 

$(planfunc)(Q::Type, x::AbstractMatrix, N::NTuple{D,Int}, rest...; kwargs...) where {D}  =
    $(planfunc)(Q, collect(x), N, rest...; kwargs...)

end
end

## NNFFT constructor
plan_nnfft(Q::Type, x::AbstractVector, y::AbstractVector, rest...; kwargs...) where {D}  =
    plan_nnfft(Q, collect(reshape(x,1,length(x))), collect(reshape(y,1,length(x))), rest...; kwargs...)



###############################################
# Allocating trafo functions with plan creation
###############################################

for (op,trans) in zip([:nfft, :nfct, :nfst],
                      [:adjoint, :transpose, :transpose])
planfunc = Symbol("plan_$(op)")
tfunc = Symbol("$(op)_$(trans)")
@eval begin 

# TODO fix comments (how?)
"""
nfft(x, f, rest...; kwargs...)

calculates the nfft of the array `f` for the nodes contained in the matrix `x`
The output is a vector of length M=`size(nodes,2)`
"""
function $(op)(x, f::AbstractArray; kargs...) 
  p = $(planfunc)(x, size(f); kargs... )
  return p * f
end

"""
nfft_adjoint(x, N, fHat, rest...; kwargs...)

calculates the adjoint nfft of the vector `fHat` for the nodes contained in the matrix `x`.
The output is an array of size `N`
"""
function $(tfunc)(x, N, fHat;  kargs...) 
  p = $(planfunc)(x, N;  kargs...)
  return $(trans)(p) * fHat
end

end
end

############################
# Allocating trafo functions
############################

"""
        *(p, f) -> fHat

For a **non**-directional `D` dimensional plan `p` this calculates the NFFT/NNFFT of a `D` dimensional array `f` of size `N`.
`fHat` is a vector of length `M`.
(`M` and `N` are defined in the plan creation)

For a **directional** `D` dimensional plan `p` both `f` and `fHat` are `D`
dimensional arrays, and the dimension specified in the plan creation is
affected.
"""
function Base.:*(p::AbstractComplexFTPlan{T}, f::AbstractArray{Complex{U},D}; kargs...) where {T,U,D}
  fHat = similar(f, Complex{T}, size_out(p))
  mul!(fHat, p, f; kargs...)
  return fHat
end

"""
        *(p::Adjoint{T,<:AbstractFTPlan{T}}, fHat) -> f

For a **non**-directional `D` dimensional plan `p` this calculates the adjoint NFFT/NNFFT of a length `M` vector `fHat`
`f` is a `D` dimensional array of size `N`.
(`M` and `N` are defined in the plan creation)

For a **directional** `D` dimensional plan `p` both `f` and `fHat` are `D`
dimensional arrays, and the dimension specified in the plan creation is
affected.
"""

function Base.:*(p::Adjoint{Complex{T},<:AbstractComplexFTPlan{T}}, fHat::AbstractArray{Complex{U},D}; kargs...) where {T,U,D}
  f = similar(fHat, Complex{T}, size_out(p))
  mul!(f, p, fHat; kargs...)
  return f
end

# The following two methods are redundant but need to be defined because of a method ambiguity with Julia Base
function Base.:*(p::Adjoint{Complex{T},<:AbstractComplexFTPlan{T}}, fHat::AbstractVector{Complex{U}}; kargs...) where {T,U}
  f = similar(fHat, Complex{T}, size_out(p))
  mul!(f, p, fHat; kargs...)
  return f
end
function Base.:*(p::Adjoint{Complex{T},<:AbstractComplexFTPlan{T}}, fHat::AbstractArray{Complex{U},2}; kargs...) where {T,U}
  f = similar(fHat, Complex{T}, size_out(p))
  mul!(f, p, fHat; kargs...)
  return f
end



"""
        *(p, f) -> fHat

For a **non**-directional `D` dimensional plan `p` this calculates the NFCT/NFST of a `D` dimensional array `f` of size `N`.
`fHat` is a vector of length `M`.
(`M` and `N` are defined in the plan creation)

For a **directional** `D` dimensional plan `p` both `f` and `fHat` are `D`
dimensional arrays, and the dimension specified in the plan creation is
affected.
"""
function Base.:*(p::AbstractRealFTPlan{T}, f::AbstractArray{U,D}; kargs...) where {T,U,D}
  fHat = similar(f, T, size_out(p))
  mul!(fHat, p, f; kargs...)
  return fHat
end

"""
        *(p::Transpose{T,AbstractRealFTPlan{T}}, fHat) -> f

For a **non**-directional `D` dimensional plan `p` this calculates the adjoint NFCT/NFST of a length `M` vector `fHat`
`f` is a `D` dimensional array of size `N`.
(`M` and `N` are defined in the plan creation)

For a **directional** `D` dimensional plan `p` both `f` and `fHat` are `D`
dimensional arrays, and the dimension specified in the plan creation is
affected.
"""

function Base.:*(p::Transpose{T,<:AbstractRealFTPlan{T}}, fHat::AbstractArray{U,D}; kargs...) where {T,U,D}
  f = similar(fHat, T, size_out(p))
  mul!(f, p, fHat; kargs...)
  return f
end

# The following two methods are redundant but need to be defined because of a method ambiguity with Julia Base
function Base.:*(p::Transpose{T,<:AbstractRealFTPlan{T}}, fHat::AbstractVector{U}; kargs...) where {T,U}
  f = similar(fHat, T, size_out(p))
  mul!(f, p, fHat; kargs...)
  return f
end
function Base.:*(p::Transpose{T,<:AbstractRealFTPlan{T}}, fHat::AbstractArray{U,2}; kargs...) where {T,U}
  f = similar(fHat, T, size_out(p))
  mul!(f, p, fHat; kargs...)
  return f
end
