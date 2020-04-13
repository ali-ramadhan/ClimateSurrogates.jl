using LinearAlgebra
using Dates
using Printf
using Gen
using OceanTurb
using JLD2
using Plots

# For quick headless plotting without warnings.
# See: https://github.com/jheinen/GR.jl/issues/278
ENV["GKSwstype"] = "100"

#####
##### Load Oceananigans free convection data from JLD2 file
#####

file = jldopen("free_convection_profiles.jld2")

Is = keys(file["timeseries/t"])

Nz = file["grid/Nz"]
Lz = file["grid/Lz"]
Nt = length(Is)

t = zeros(Nt)
T = T_data = zeros(Nt, Nz)
wT = zeros(Nt, Nz)

for (i, I) in enumerate(Is)
    t[i] = file["timeseries/t/$I"]
    T[i, :] = file["timeseries/T/$I"][1, 1, 2:Nz+1]
end

#####
##### Plot animation of T(z,t) from data
#####

zC = file["grid/zC"]

anim = @animate for n=1:10:Nt
    title = @sprintf("Deepening mixed layer: %.2f days", t[n] / 86400)
    plot(T[n, :], zC, linewidth=2,
         xlim=(19, 20), ylim=(-100, 0), label="",
         xlabel="Temperature (C)", ylabel="Depth (z)",
         title=title, show=false)
end

gif(anim, "deepening_mixed_layer.gif", fps=15)

# Code credit: https://github.com/sandreza/OceanConvectionUQSupplementaryMaterials/blob/master/src/utils.jl

"""
avg(Φ, n)
# Description
- Average a field down by n.
- Requires field to have evenly spaced points. Size of N leq length(Φ).
- Furthermore requires
# Arguments
- `Φ` :(vector) The field, an array
- `n` :(Int) number of grid points to average down to.
# Return
- `Φ2` :(vector) The field with values averaged, an array
"""
function avg(Φ, n)
    m = length(Φ)
    scale = Int(floor(m/n))
    if ( abs(Int(floor(m/n)) - m/n) > eps(1.0))
        return error
    end
    Φ2 = zeros(n)
    for i in 1:n
        Φ2[i] = 0
            for j in 1:scale
                Φ2[i] += Φ[scale*(i-1) + j] / scale
            end
    end
    return Φ2
end

# Modified from: https://github.com/sandreza/OceanConvectionUQSupplementaryMaterials/blob/master/src/ForwardMap/fm.jl

"""
Generative model for free convection.
"""
@gen function free_convection_model(ℂ, constants, N, L, Δt, times, T₀, FT, ∂T∂z)
    # Uniform priors on all four KPP parameters.
    CSL  ~ uniform(0, 1)
    CNL  ~ uniform(0, 8)
    Cb_T ~ uniform(0, 6)
    CKE  ~ uniform(0, 5)

    parameters = KPP.Parameters(CSL=CSL, CNL=CNL, Cb_T=Cb_T, CKE=CKE)

    model = KPP.Model(N=N, H=L, stepper=:BackwardEuler, constants=constants, parameters=parameters)

    # Coarse grain initial condition from LES and set equal
    # to initial condition of parameterization.
    model.solution.T.data[1:N] .= avg(T₀, N)

    # Set boundary conditions
    model.bcs.T.top = FluxBoundaryCondition(FT)
    model.bcs.T.bottom = GradientBoundaryCondition(∂T∂z)

    Nt = length(times)
    solution = zeros(N, Nt)

    # loop the model
    for n in 1:Nt
        run_until!(model, Δt, times[n])
        @. solution[:, n] = model.solution.T[1:N]
    end

    # Put prior distributions on the temperature at every
    # grid point at every time step with a tiny bit of noise.
    for n in 1:Nt, i in 1:N
        {(:T, i, n)} ~ normal(solution[i, n], 0.01)
    end

    return solution, model.grid.zc
end

# Physical constants
ρ₀ = file["parameters/density"]
cₚ = file["parameters/specific_heat_capacity"]
f  = file["parameters/coriolis_parameter"]
α  = file["buoyancy/equation_of_state/α"]
β  = file["buoyancy/equation_of_state/β"]
g  = file["buoyancy/gravitational_acceleration"]

constants = Constants(Float64, ρ₀=ρ₀, cP=cₚ, f=f, α=α, β=β, g=g)

# OceanTurb parameters
N = 16
L = file["grid/Lz"]
Δt = 60

Q = parse(Float64, file["parameters/surface_cooling"])
FT = -Q / (ρ₀*cₚ)
∂T∂z = file["parameters/temperature_gradient"]

ℂ = (1.0, 1.0, 1.0, 1.0)
Nt = 600
times = t[1:Nt]
T₀ = T[1, :]

trace = Gen.simulate(free_convection_model, (ℂ, constants, N, L, Δt, times, T₀, FT, ∂T∂z))

choices = Gen.get_choices(trace)
@sprintf("Choices made: CSL=%.5f, CNL=%.5f, Cb_T=%.5f, CKE=%.5f",
         choices[:CSL], choices[:CNL], choices[:Cb_T], choices[:CKE])

KPP_solution, KPP_zC = trace.retval

anim = @animate for n=1:Nt
    title = @sprintf("Deepening mixed layer: %.2f days", t[n] / 86400)
    plot(T[n, :], zC, linewidth=2,
         xlim=(19, 20), ylim=(-100, 0), label="LES",
         xlabel="Temperature (C)", ylabel="Depth (z)",
         title=title, legend=:bottomright, show=false)

    plot!(KPP_solution[:, n], KPP_zC, linewidth=2, label="KPP")
end

gif(anim, "deepening_mixed_layer_random_KPP_parameters.gif", fps=15)

T_cs = T_coarse_grained = zeros(Nt, N)
for n in 1:Nt
    T_cs[n, :] .= avg(T[n, :], N)
end

@gen function kpp_proposal(trace)
    CSL  ~ normal(trace[:CSL],  0.1)
    CNL  ~ normal(trace[:CNL],  0.1)
    Cb_T ~ normal(trace[:Cb_T], 0.1)
    CKE  ~ normal(trace[:CKE],  0.1)
    return nothing
end

function do_inference(model, model_args, data; n_samples, max_iters=10n_samples)
    # Create a choice map that maps model addresses (:T, i, n)
    # to observed data T[i, n]. We leave the four KPP parameters
    # (:CSL, :CNL, :Cb_T, :CKE) unconstrained, because we want them
    # to be inferred.
    observations = Gen.choicemap()

    Nt, N = size(data)
    for n in 1:Nt, i in 1:N
        observations[(:T, i, n)] = data[n, i]
    end

    traces = []
    CSL_samples = zeros(n_samples)
    CNL_samples = zeros(n_samples)
    CbT_samples = zeros(n_samples)
    CKE_samples = zeros(n_samples)

    n_steps = 0
    n_accepted_steps = 0

    μ, Σ = 0.0, 1.0

    trace, _ = Gen.generate(model, model_args, observations)
    while n_accepted_steps < n_samples
        trace = Gen.elliptical_slice(trace, :CSL,  trace[:CSL],  Σ, observations=observations)
        trace = Gen.elliptical_slice(trace, :CNL,  trace[:CNL],  Σ, observations=observations)
        trace = Gen.elliptical_slice(trace, :Cb_T, trace[:Cb_T], Σ, observations=observations)
        trace = Gen.elliptical_slice(trace, :CKE,  trace[:CKE],  Σ, observations=observations)
        n_accepted_steps = n_accepted_steps + 1
        @show trace[:CSL], trace[:CNL], trace[:Cb_T], trace[:CKE]

        push!(traces, trace)
        choices = Gen.get_choices(trace)
        CSL_samples[n_accepted_steps] = choices[:CSL]
        CNL_samples[n_accepted_steps] = choices[:CNL]
        CbT_samples[n_accepted_steps] = choices[:Cb_T]
        CKE_samples[n_accepted_steps] = choices[:CKE]

        n_steps = n_steps + 1
        @show n_steps, n_accepted_steps
        n_steps >= max_iters && break
    end

    println("# of accepted steps: $n_accepted_steps")
    println("# of steps: $n_steps")
    println("Acceptence ratio: $(n_accepted_steps/n_steps)")

    return traces, CSL_samples, CNL_samples, CbT_samples, CKE_samples
end

model_args = (ℂ, constants, N, L, Δt, times, T₀, FT, ∂T∂z)
traces, CSL, CNL, Cb_T, CKE = do_inference(free_convection_model, model_args, T_coarse_grained, n_samples=100)

CSL_hist = histogram(CSL,  bins=range(0, 1, length=10), xlabel="CSL",  label="")
CNL_hist = histogram(CNL,  bins=range(0, 8, length=10), xlabel="CNL",  label="")
CbT_hist = histogram(Cb_T, bins=range(0, 6, length=10), xlabel="Cb_T", label="")
CKE_hist = histogram(CKE,  bins=range(0, 5, length=10), xlabel="CKE",  label="")

p = plot(CSL_hist, CNL_hist, CbT_hist, CKE_hist, layout=(2,2), dpi=200)
savefig(p, "KPP_parameters_marginal_posteriors.png")

anim = @animate for n=1:5:Nt
    title = @sprintf("Little KPP ensemble: %.2f days", t[n] / 86400)

    KPP_solution, KPP_zC = traces[1].retval
    p = plot(KPP_solution[:, n], KPP_zC, linewidth=2,
         xlim=(19, 20), ylim=(-100, 0), label="",
         xlabel="Temperature (C)", ylabel="Depth (z)",
         title=title, dpi=200, show=false)

    for i in 2:length(traces)
        KPP_solution, KPP_zC = traces[i].retval
        plot!(p, KPP_solution[:, n], KPP_zC, linewidth=2, label="")
    end

    plot!(p, T[n, :], zC, linewidth=2, label="LES data", legend=:bottomright)
end

gif(anim, "deepening_mixed_layer_KPP_ensemble.gif", fps=15)