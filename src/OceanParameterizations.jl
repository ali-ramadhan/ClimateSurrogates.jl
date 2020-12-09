module OceanParameterizations

if VERSION < v"1.5"
    error("OceanParameterizations.jl requires Julia v1.5 or newer.")
end

export
    # Utils
    coarse_grain, Dᶠ, Dᶜ,
    ZeroMeanUnitVarianceScaling, MinMaxScaling, scale, unscale,
    predict, animate_gif,

    # GaussianProcesses
    gp_model, get_kernel, euclidean_distance, derivative_distance, antiderivative_distance,

    # NeuralNetworks
    nn_model,

    # Ocean convection
    nc_constant,
    FreeConvectionTrainingDataInput, rescale,
    FreeConvectionNDE, ConvectiveAdjustmentNDE, FreeConvectionNDEParameters, initial_condition,
    solve_free_convection_nde, solve_convective_adjustment_nde, free_convection_solution,
    animate_variable, convection_training_data, animate_learned_heat_flux,

    # PhysicalParameterizations
    closure_free_convection_kpp_full_evolution,
    closure_free_convection_tke_full_evolution

using LinearAlgebra
using Printf
using Statistics
using Logging

using DifferentialEquations
using Flux
using JLD2
using NCDatasets
using Plots
using Oceananigans.Utils

using Oceananigans: OceananigansLogger
using Oceananigans.Grids: Cell, Face
using DiffEqSensitivity: InterpolatingAdjoint, ZygoteVJP

import Base.inv

include("differentiation_operators.jl")
include("predict.jl")
include("ocean_convection.jl")

# submodules
include("DataWrangling/DataWrangling.jl")
include("GaussianProcesses/GaussianProcesses.jl")
include("NeuralNetworks/NeuralNetworks.jl")
include("PhysicalParameterizations/PhysicalParameterizations.jl")

using .DataWrangling
using .GaussianProcesses
using .NeuralNetworks
using .PhysicalParameterizations

function __init__()
    Logging.global_logger(OceananigansLogger())
end

end # module
