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
# result = MarketModel.run_market_model(data_dir, result_dir, optimizer_package, return_result=true)

# %% results analysis
# res_n3303_sb = res.D_es[in.(res.D_es.p, Ref(["n3303_electricity/solar battery"])), :]
# res_n3303_sb[1:15, "D_es"]

# %% Data read in analysis

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

# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

m = MarketModel.POMATO()
m.model = MarketModel.Model()
m.data = data
m.options = options

## Plant Mappings
# mapping heat index to G index
mapping_he = findall(plant -> plant.h_max > 0, data.plants)
mapping_sbs = findall(plant -> plant.plant_type in ["solar battery"], data.plants)

slack = findall(node -> node.slack, data.nodes)
he = mapping_he
chp = findall(plant -> ((plant.h_max > 0)&(plant.g_max > 0)), data.plants[mapping_he])
es = findall(plant -> plant.plant_type in options["plant_types"]["es"], data.plants)
hs = findall(plant -> plant.plant_type in options["plant_types"]["hs"], data.plants[mapping_he])
ph = findall(plant -> plant.plant_type in options["plant_types"]["ph"], data.plants[mapping_he])
alpha = findall(plant -> ((plant.g_max > options["chance_constrained"]["alpha_plants_mw"])&(plant.mc_el <= options["chance_constrained"]["alpha_plants_mc"])), data.plants)
cc_res = findall(res_plants -> res_plants.g_max > options["chance_constrained"]["cc_res_mw"], data.renewables)
sbs = mapping_sbs,
#  srt = [keys(data.renewables[(data.renewables.node.==sb.node)&(data.renewables.plant_type.=="solar rooftop")]) for sb in data.plants[mapping_sbs]]
srt = [findall(res_plants -> (res_plants.node==sb.node)&(res_plants.plant_type=="solar rooftop"), data.renewables)[1] for sb in data.plants[mapping_sbs]]

m.mapping = (slack = findall(node -> node.slack, data.nodes),
            he = mapping_he,
            chp = findall(plant -> ((plant.h_max > 0)&(plant.g_max > 0)), data.plants[mapping_he]),
            es = findall(plant -> plant.plant_type in options["plant_types"]["es"], data.plants),
            hs = findall(plant -> plant.plant_type in options["plant_types"]["hs"], data.plants[mapping_he]),
            ph = findall(plant -> plant.plant_type in options["plant_types"]["ph"], data.plants[mapping_he]),
            alpha = findall(plant -> ((plant.g_max > options["chance_constrained"]["alpha_plants_mw"])&(plant.mc_el <= options["chance_constrained"]["alpha_plants_mc"])), data.plants),
            cc_res = findall(res_plants -> res_plants.g_max > options["chance_constrained"]["cc_res_mw"], data.renewables),
            sbs = mapping_sbs,
        #  srt = [keys(data.renewables[(data.renewables.node.==sb.node)&(data.renewables.plant_type.=="solar rooftop")]) for sb in data.plants[mapping_sbs]]
            srt = [findall(res_plants -> (res_plants.node==sb.node)&(res_plants.plant_type=="solar rooftop"), data.renewables)[1] for sb in data.plants[mapping_sbs]]
            )

m.n = (t = size(data.t, 1),
        zones = size(data.zones, 1),
        nodes = size(data.nodes, 1),
        heatareas = size(data.heatareas, 1),
        plants = size(data.plants, 1),
        res = size(data.renewables, 1),
        dc = size(data.dc_lines, 1),
        lines = size(data.lines, 1),
        contingencies = size(data.contingencies, 1),
        he = size(m.mapping.he, 1),
        chp = size(m.mapping.chp, 1),
        es = size(m.mapping.es, 1),
        hs = size(m.mapping.hs, 1),
        ph = size(m.mapping.ph, 1),
        alpha = size(m.mapping.alpha, 1),
        cc_res = size(m.mapping.cc_res, 1),
        sbs = size(m.mapping.sbs, 1),
        srt = size(m.mapping.srt, 1)
        )
# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pomato = MarketModel.POMATO(MarketModel.Model(), data, options)

model = pomato.model
n = pomato.n
data = pomato.data
options = pomato.options
mapping = pomato.mapping



