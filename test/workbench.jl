include("../src/MarketModel.jl")
import .MarketModel
using Test, Logging
using Clp
using DataFrames
using JuMP

# data_dir = pwd()*"\\examples\\de_testing\\"
data_dir = pwd()*"\\examples\\ses\\"
data = MarketModel.read_model_data(data_dir);
pomato = MarketModel.POMATO(MarketModel.Model(), data);

if pomato.options["timeseries"]["type"] == "da"
    set_da_timeseries!(data)
end

optimizer_package = Clp
# MarketModel.add_optimizer!(pomato)

# @info("Adding Variables and Expressions...")
# MarketModel.add_variables_expressions!(pomato)

# @info("Adding Base Model...")
# MarketModel.add_electricity_generation_constraints!(pomato)
model = pomato.model
n = pomato.n
data = pomato.data
options = pomato.options
mapping = pomato.mapping

@variable(model, G[1:n.t, 1:n.plants] >= 0)

pomato.model[:g_min] = @constraint(pomato.model, [t=1:pomato.n.t, p=pomato.mapping.g_min],
		G[t, p] .>= pomato.data.plants[p].g_min)
######
n = pomato.n
mapping = pomato.mapping
gmin = findall(plant -> plant.g_min != zero(plant.g_min), data.plants)


# test = DataFrame(A=1:3, B=5:7, fixed=1)