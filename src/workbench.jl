include("../src/MarketModel.jl")
import .MarketModel
using Clp
using JSON

# %% NREL 118
# optimizer_package = Clp
# data_dir = (pwd()*"\\examples\\nrel_118\\")
# result_dir = (pwd()*"\\examples\\results\\")
# result = MarketModel.run_market_model(data_dir, result_dir, optimizer_package, return_result=true)

# %% MODEZEEN PomatoData
# data_dir = ("C:/Users/cw/repositories/MODEZEEN_AP4/data_temp/julia_files/data/")
# result_dir = ("C:/Users/cw/repositories/MODEZEEN_AP4/data_temp/julia_files/results/")
data_dir = (pwd()*"\\examples\\modezeen_ap4_price_forecast\\")
result_dir = (pwd()*"\\examples\\results\\")
optimizer_package = Clp
result = MarketModel.run_market_model(data_dir, result_dir, optimizer_package, return_result=true)

# options = JSON.parsefile(data_dir*"options.json"; dicttype=Dict)
raw = MarketModel.RAW(data_dir)

zones = MarketModel.populate_zones(raw)
nodes = MarketModel.populate_nodes(raw)
heatareas = MarketModel.populate_heatareas(raw)
plants = MarketModel.populate_plants(raw)
res_plants = MarketModel.populate_res_plants(raw)
dc_lines = MarketModel.populate_dclines(raw)

lines = MarketModel.populate_lines(raw, nodes)
contingencies, redispatch_contingencies = MarketModel.populate_network(raw, lines, nodes, zones)

timesteps = MarketModel.populate_timesteps(raw)
data = MarketModel.Data(nodes, zones, heatareas, plants, res_plants, lines, 
            contingencies, redispatch_contingencies, dc_lines, timesteps)
data.folders = Dict("data_dir" => data_dir)
options = raw.options


# %%
# mapping_sbs = findall(plant -> plant.plant_type in ["solar battery"], data.plants)
# sb = data.plants[mapping_sbs][1]
# findall(res_plants -> (res_plants.node==sb.node)&(res_plants.plant_type=="solar rooftop"), data.renewables)
# srt = [findall(res_plants -> (res_plants.node==sb.node)&(res_plants.plant_type=="solar rooftop"), data.renewables)[1] for sb in data.plants[mapping_sbs]]

# %%

pomato = MarketModel.POMATO(MarketModel.Model(), data, options)

model = pomato.model
n = pomato.n
data = pomato.data
options = pomato.options
mapping = pomato.mapping



