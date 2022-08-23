include("../src/MarketModel.jl")
import .MarketModel
using Test, Logging
using Clp
using DataFrames
using JuMP
using Gurobi

# data_dir = pwd()*"\\examples\\de_testing\\"
# data_dir = pwd()*"\\examples\\ses\\"
# data = MarketModel.read_model_data(data_dir);
# pomato = MarketModel.POMATO(MarketModel.Model(), data);

# if pomato.options["timeseries"]["type"] == "da"
#     set_da_timeseries!(data)
# end

# optimizer_package = Clp
# MarketModel.add_optimizer!(pomato)

# @info("Adding Variables and Expressions...")
# MarketModel.add_variables_expressions!(pomato)

# @info("Adding Base Model...")
# MarketModel.add_electricity_generation_constraints!(pomato)
# model = pomato.model
# n = pomato.n
# data = pomato.data
# options = pomato.options
# mapping = pomato.mapping

# @variable(model, G[1:n.t, 1:n.plants] >= 0)

# pomato.model[:g_min] = @constraint(pomato.model, [t=1:pomato.n.t, p=pomato.mapping.g_min],
# 		G[t, p] .>= pomato.data.plants[p].g_min)
# ######
# n = pomato.n
# mapping = pomato.mapping
# gmin = findall(plant -> plant.g_min != zero(plant.g_min), data.plants)


# test = DataFrame(A=1:3, B=5:7, fixed=1)

optimizer_package = Gurobi
data_dir = "C:\\Users\\cw\\Nextcloud\\wip_member\\OR-IM\\2_data\\Pomato\\CH_Adequacy\\data_temp\\julia_files\\data\\"
result_dir = "C:\\Users\\cw\\Nextcloud\\wip_member\\OR-IM\\2_data\\Pomato\\CH_Adequacy\\data_temp\\julia_files\\results\\"
raw = MarketModel.RAW(data_dir)

res_plants = Vector{MarketModel.Renewables}()
if size(raw.availability, 1) > 0
    availability = unstack(raw.availability, :timestep, :plant, :availability)
end
for res in 1:nrow(raw.res_plants)
    index = res
    name = string(raw.res_plants[res, :index])
    node_name = raw.res_plants[res, :node]
    node_idx = raw.nodes[raw.nodes[:, :index] .== node_name, :int_idx][1]
    g_max = raw.res_plants[res, :g_max]*1.
    h_max = raw.res_plants[res, :h_max]*1.
    mc_el = raw.res_plants[res, :mc_el]*1.
    mc_heat = raw.res_plants[res, :mc_heat]*1.
    plant_type = raw.res_plants[res, :plant_type]
    newres = Renewables(
        index, name, g_max, h_max, mc_el, mc_heat, availability[:, name], node_idx, plant_type
    )

    if "availability_da" in string.(names(raw.availability))
        availability_da = filter(col -> col[:plant] == name, raw.availability)[:, :availability_da]
        
        newres.mu_da = availability_da * g_max
        newres.sigma_da = newres.mu_da * newres.sigma_factor 
        newres.mu_heat_da = availability_da * h_max
        newres.sigma_heat_da = newres.mu_heat_da * newres.sigma_factor
    end
    push!(res_plants, newres)
end

nodes = MarketModel.populate_nodes(raw)
zones = MarketModel.populate_zones(raw, nodes)
heatareas = MarketModel.populate_heatareas(raw)
plants = MarketModel.populate_plants(raw)
res_plants = MarketModel.populate_res_plants(raw)

data = MarketModel.read_model_data(data_dir)
result = MarketModel.run_market_model(data_dir, result_dir, optimizer_package, return_result=true)