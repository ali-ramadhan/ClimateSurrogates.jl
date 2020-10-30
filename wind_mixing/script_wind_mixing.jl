using Statistics
using NCDatasets
using Plots
using Flux, DiffEqFlux, Optim
# using ClimateSurrogates
using Oceananigans.Grids

##
PATH = joinpath(pwd(), "wind_mixing")
DATA_PATH = joinpath(PATH, "Data", "wind_mixing_horizontal_averages_0.02Nm2_8days.nc")

ds = NCDataset(DATA_PATH)
keys(ds)


xC = Array(ds["xC"])
xF = Array(ds["xF"])
yC = Array(ds["yC"])
yF = Array(ds["yF"])
zC = Array(ds["zC"])
zF = Array(ds["zF"])

uT = Array(ds["uT"])
vT = Array(ds["vT"])
wT = Array(ds["wT"])

uu = Array(ds["uu"])
vv = Array(ds["vv"])
ww = Array(ds["ww"])
uv = Array(ds["uv"])
uw = Array(ds["uw"])
vw = Array(ds["vw"])

u = Array(ds["u"])
v = Array(ds["v"])

T = Array(ds["T"])
t = Array(ds["time"])
##
plot(T[:,end], zC)

function animate_gif(xs, y, t, x_str, x_label=["" for i in length(xs)], filename=x_str)
    PATH = joinpath(pwd(), "wind_mixing")
    anim = @animate for n in 1:size(xs[1],2)
    x_max = maximum(maximum(x) for x in xs)
    x_min = minimum(minimum(x) for x in xs)
        @info "$x_str frame of $n/$(size(uw,2))"
        fig = plot(xlim=(x_min, x_max), ylim=(minimum(y), maximum(y)))
        for i in 1:length(xs)
            plot!(fig, xs[i][:,n], y, label=x_label[i], title="t = $(round(t[n]/86400, digits=2)) days")
        end
        xlabel!(fig, "$x_str")
        ylabel!(fig, "z")
    end
    gif(anim, joinpath(PATH, "Output", "$(x_str).gif"), fps=30)
end

animate_gif([uw], zC, t, "uw")
animate_gif([vw], zC, t, "vw")
animate_gif([wT], zF, t, "wT")
animate_gif([u], zC, t, "u")
animate_gif([v], zC, t, "v")
animate_gif([T], zC, t, "T")

function coarse_grain(Φ, n, ::Type{Cell})
    N = length(Φ)
    Δ = Int(N / n)
    Φ̅ = similar(Φ, n)
    for i in 1:n
        Φ̅[i] = mean(Φ[Δ*(i-1)+1:Δ*i])
    end
    return Φ̅
end

function coarse_grain(Φ, n, ::Type{Face})
    N = length(Φ)
    Φ̅ = similar(Φ, n)
    Δ = (N-2) / (n-2)
    if isinteger(Δ)
        Φ̅[1], Φ̅[n] = Φ[1], Φ[N]
        Φ̅[2:n-1] .= coarse_grain(Φ[2:N-1], n-2, Cell)
    else
        Φ̅[1], Φ̅[n] = Φ[1], Φ[N]
        for i in 2:n-1
            i1 = round(Int, 2 + (i-2)*Δ)
            i2 = round(Int, 2 + (i-1)*Δ)
            Φ̅[i] = mean(Φ[i1:i2])
        end
    end
    return Φ̅
end

function feature_scaling(x, mean, std)
    (x .- mean) ./ std
end

##
u_coarse = cat((coarse_grain(u[:,i], 32, Cell) for i in 1:size(u,2))..., dims=2)
v_coarse = cat((coarse_grain(v[:,i], 32, Cell) for i in 1:size(v,2))..., dims=2)
T_coarse = cat((coarse_grain(T[:,i], 32, Cell) for i in 1:size(T,2))..., dims=2)
uw_coarse = cat((coarse_grain(uw[:,i], 32, Cell) for i in 1:size(uw,2))..., dims=2)
vw_coarse = cat((coarse_grain(vw[:,i], 32, Cell) for i in 1:size(vw,2))..., dims=2)
wT_coarse = cat((coarse_grain(wT[:,i], 32, Face) for i in 1:size(wT,2))..., dims=2)
zC_coarse = cat((coarse_grain(zC[:,i], 32, Cell) for i in 1:size(zC,2))..., dims=2)

uw_mean = mean(uw_coarse)
uw_std = std(uw_coarse)
vw_mean = mean(vw_coarse)
vw_std = std(vw_coarse)
wT_mean = mean(wT_coarse)
wT_std = std(wT_coarse)

uw_scaled = feature_scaling.(uw_coarse, uw_mean, uw_std)
vw_scaled = feature_scaling.(vw_coarse, vw_mean, vw_std)
wT_scaled = feature_scaling.(wT_coarse, wT_mean, wT_std)
##
uw_train_scaled = [(u_coarse[:,i], uw_scaled[:,i]) for i in 1:size(u_coarse,2)]
uw_train = [(u_coarse[:,i], uw_coarse[:,i]) for i in 1:size(u_coarse,2)]

model_uw = Chain(Dense(32,30, relu), Dense(30,32))
loss_uw(x, y) = Flux.Losses.mse(model_uw(x), y)
loss_uw_scaled(x, y) = Flux.Losses.mse(feature_scaling.(model_uw(x), uw_mean, uw_std), y)
p_uw = params(model_uw)

# function cb()
#     @info mean([loss_uw_scaled(uw_train[i][1], uw_train[i][2]) for i in 1:length(uw_train)])
# end

function cb()
    @info mean([loss_uw(uw_train[i][1], uw_train[i][2]) for i in 1:length(uw_train)])
    false
end

# Flux.train!(loss_uw_scaled, params(model_uw), uw_train, Descent(), cb = cb, maxiters=5)
optimizers = [Descent(), Descent(), Descent(), ADAM(0.01)]

for opt in optimizers
    Flux.train!(loss_uw, params(model_uw), uw_train, opt, cb = cb)
end
# Flux.train!(loss_uw_scaled, params(model_uw), uw_train_scaled, Descent(), cb = cb)


params(model_uw)


uw_NN = (cat((model_uw(uw_train[i][1]) for i in 1:length(uw_train))...,dims=2), uw_coarse)

animate_gif(uw_NN, zC_coarse, t, "uw_train", ["NN", "truth"])


model_uw_uvT = Chain(Dense(96,30, relu), Dense(30,32))
loss_uw(x, y) = Flux.Losses.mse(model_uw_uvT(x), y)
loss_uw_scaled(x, y) = Flux.Losses.mse(feature_scaling.(model_uw_uvT(x), uw_mean, uw_std), y)
p_uw_uvT = params(model_uw_uvT)

uvT_coarse = cat(u_coarse, v_coarse, T_coarse, dims=1)

uw_train_uvT = [(uvT_coarse[:,i], uw_coarse[:,i]) for i in 1:size(uvT_coarse,2)]

optimizers_uw_uvT = [Descent(), Descent(), Descent()]

function cb_uvT()
    @info mean([loss_uw(uw_train_uvT[i][1], uw_train_uvT[i][2]) for i in 1:length(uw_train_uvT)])
    false
end


for opt in optimizers_uw_uvT
    Flux.train!(loss_uw, params(model_uw_uvT), uw_train_uvT, opt, cb = cb_uvT)
end

uw_NN_uvT = (cat((model_uw_uvT(uw_train_uvT[i][1]) for i in 1:length(uw_train_uvT))...,dims=2), uw_coarse)

animate_gif(uw_NN_uvT, zC_coarse, t, "uw", ["NN(u,v,T)", "truth"], "uw_uvT")



model_vw = Chain(Dense(96,30, relu), Dense(30,32))
loss_vw(x, y) = Flux.Losses.mse(model_vw(x), y)
# loss_uw_scaled(x, y) = Flux.Losses.mse(feature_scaling.(model_uw_uvT(x), uw_mean, uw_std), y)
p_vw = params(model_vw)

vw_train = [(uvT_coarse[:,i], vw_coarse[:,i]) for i in 1:size(uvT_coarse,2)]

function cb_vw()
    @info mean([loss_vw(vw_train[i][1], vw_train[i][2]) for i in 1:length(vw_train)])
    false
end

optimizers_vw = [Descent(), Descent(), Descent(), Descent()]
for opt in optimizers_vw
    Flux.train!(loss_vw, params(model_vw), vw_train, opt, cb = cb_vw)
end

vw_NN = (cat((model_vw(vw_train[i][1]) for i in 1:length(vw_train))...,dims=2), vw_coarse)

animate_gif(vw_NN, zC_coarse, t, "vw", ["NN(u,v,T)", "truth"], "vw_uvT")

model_wT = Chain(Dense(96,30, relu), Dense(30,32))
loss_wT(x, y) = Flux.Losses.mse(model_wT(x), y)
# loss_uw_scaled(x, y) = Flux.Losses.mse(feature_scaling.(model_uw_uvT(x), uw_mean, uw_std), y)
p_wT = params(model_wT)

wT_train = [(uvT_coarse[:,i], wT_coarse[:,i]) for i in 1:size(uvT_coarse,2)]

function cb_wT()
    @info mean([loss_wT(wT_train[i][1], wT_train[i][2]) for i in 1:length(wT_train)])
    false
end

optimizers_wT = [Descent(), Descent(), Descent(), Descent()]
for opt in optimizers_wT
    Flux.train!(loss_wT, params(model_wT), wT_train, opt, cb = cb_wT)
end

wT_NN = (cat((model_wT(wT_train[i][1]) for i in 1:length(wT_train))...,dims=2), wT_coarse)

animate_gif(wT_NN, zC_coarse, t, "wT", ["NN(u,v,T)", "truth"], "wT_uvT")