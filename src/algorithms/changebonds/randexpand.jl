"""
    struct RandExpnd <: Algorithm end

An algorithm that expands the bond dimension by adding random unitary vectors that are
orthogonal to the existing state. This is achieved by performing a truncated SVD on a random
two-site MPS tensor, which is made orthogonal to the existing state.

# Fields
- `trscheme::TruncationScheme = truncdim(1)` : The truncation scheme to use.
"""
@kwdef struct RandExpand <: Algorithm
    trscheme::TruncationScheme = truncdim(1)
end

function changebonds(ψ::InfiniteMPS, alg::RandExpand)
    # determine optimal expansion spaces around bond i
    AL′ = leftnull.(ψ.AL)
    AR′ = circshift(rightnull!.(_transpose_tail.(ψ.AR)), -1)

    for i in 1:length(ψ)
        AC2 = _transpose_front(ψ.AC[i]) * _transpose_tail(ψ.AR[i + 1])
        AC2 = randomize!(AC2)

        # Use the nullspaces and SVD decomposition to determine the optimal expansion space
        intermediate = adjoint(AL′[i]) * AC2 * adjoint(AR′[i])
        U, _, V, = tsvd!(intermediate; trunc=alg.trscheme, alg=SVD())

        AL′[i] = AL′[i] * U
        AR′[i] = V * AR′[i]
    end

    return _expand(ψ, AL′, AR′)
end

function changebonds(Ψ::MPSMultiline, alg::RandExpand)
    return Multiline(map(x -> changebonds(x, alg), Ψ.data))
end

changebonds(ψ::AbstractFiniteMPS, alg::RandExpand) = changebonds!(copy(ψ), alg)
function changebonds!(ψ::AbstractFiniteMPS, alg::RandExpand)
    for i in 1:(length(ψ) - 1)
        AC2 = randomize!(_transpose_front(ψ.AC[i]) * _transpose_tail(ψ.AR[i + 1]))

        #Calculate nullspaces for left and right
        NL = leftnull(ψ.AC[i])
        NR = rightnull!(_transpose_tail(ψ.AR[i + 1]))

        #Use this nullspaces and SVD decomposition to determine the optimal expansion space
        intermediate = adjoint(NL) * AC2 * adjoint(NR)
        _, _, V, = tsvd!(intermediate; trunc=alg.trscheme, alg=SVD())

        ar_re = V * NR
        ar_le = zerovector!(similar(ar_re, codomain(ψ.AC[i]) ← space(V, 1)))

        (nal, nc) = leftorth!(catdomain(ψ.AC[i], ar_le); alg=QRpos())
        nar = _transpose_front(catcodomain(_transpose_tail(ψ.AR[i + 1]), ar_re))

        ψ.AC[i] = (nal, nc)
        ψ.AC[i + 1] = (nc, nar)
    end

    return normalize!(ψ)
end
