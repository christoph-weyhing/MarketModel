"""Data input processing"""

function read_model_data(data_dir::String)
    @info("Reading Model Data from: $(data_dir)")
    raw = RAW(data_dir)

    task_zones = Threads.@spawn populate_zones(raw)
    task_nodes = Threads.@spawn populate_nodes(raw)
    task_heatareas = Threads.@spawn populate_heatareas(raw)
    task_plants = Threads.@spawn populate_plants(raw)
    task_res_plants = Threads.@spawn populate_res_plants(raw)
    task_dc_lines = Threads.@spawn populate_dclines(raw)
    task_grid = Threads.@spawn populate_grid(raw)

    zones = fetch(task_zones)
    nodes = fetch(task_nodes)
    heatareas = fetch(task_heatareas)
    plants = fetch(task_plants)
    res_plants = fetch(task_res_plants)
    dc_lines = fetch(task_dc_lines)
    grid = fetch(task_grid)

    timesteps = populate_timesteps(raw)
    data = Data(nodes, zones, heatareas, plants, res_plants, grid, dc_lines, timesteps)
    data.folders = Dict("data_dir" => data_dir)
    options = raw.options
    raw = nothing
    @info("Data Prepared")
    return options, data
end # end of function

function populate_timesteps(raw::RAW)
    timesteps = Vector{Timestep}()
    for t in 1:nrow(raw.model_horizon)
        index = t
        name = raw.model_horizon[t, :timesteps]
        push!(timesteps, Timestep(index, name))
    end
    return timesteps
end

function populate_zones(raw::RAW)
    zones = Vector{Zone}()
    for z in 1:nrow(raw.zones)
        index = z
        name = raw.zones[z, :index]
        nodes_idx = raw.nodes[raw.nodes[:, :zone] .== name, :int_idx]
        nodes_name = raw.nodes[raw.nodes[:, :zone] .== name, :index]
        plants = filter(row -> row[:node] in nodes_name, raw.plants)[:, :int_idx]
        res_plants = filter(row -> row[:node] in nodes_name, raw.res_plants)[:, :int_idx]
        demand = combine(groupby(filter(col -> col[:node] in nodes_name, raw.demand_el), :timestep, sort=true), :demand_el => sum)
        newz = Zone(index, name, demand[:, :demand_el_sum], nodes_idx, plants, res_plants)
        if (size(raw.ntc, 2) > 1)
            ntc = filter(row -> row[:zone_i] == name, raw.ntc)
            newz.ntc = [zone in ntc[:, :zone_j] ?
                        ntc[ntc[:, :zone_j] .== zone, :ntc][1] :
                        0 for zone in raw.zones[:, :index]]
        end

        net_export = combine(groupby(filter(col -> col[:node] in nodes_name, raw.net_export), :timestep, sort=true), :net_export => sum)
        newz.net_export = net_export[:, :net_export_sum]

        net_position = combine(groupby(filter(col -> col[:zone] == name, raw.net_position), :timestep, sort=true), :net_position => sum)
        if size(net_position, 1) > 0
            newz.net_position = net_position[:, :net_position_sum]
        end
        push!(zones, newz)
    end
    return zones
end

function populate_nodes(raw::RAW)
    nodes = Vector{Node}()
    for n in 1:nrow(raw.nodes)
        index = n
        name = raw.nodes[n, :index]
        slack = raw.nodes[n, :slack]
        zone_name = raw.nodes[n, :zone]
        zone_idx = raw.zones[raw.zones[:, :index] .== zone_name, :int_idx][1]
        plants = raw.plants[raw.plants[:, :node] .== name, :int_idx]
        res_plants = raw.res_plants[raw.res_plants[:, :node] .== name, :int_idx]
        demand = combine(groupby(filter(col -> col[:node] == name, raw.demand_el), :timestep, sort=true), :demand_el => sum)
        newn = Node(index, name, zone_idx, demand[:, :demand_el_sum], slack, plants, res_plants)
        if slack
            # newn.slack_zone = slack_zones[index]
            slack_zone = raw.slack_zones[:, :index][raw.slack_zones[:, Symbol(name)] .== 1]
            newn.slack_zone = filter(col -> col[:index] in slack_zone, raw.nodes)[:, :int_idx]
        end
        net_export = combine(groupby(filter(col -> col[:node] == name, raw.net_export), :timestep, sort=true), :net_export => sum)
        newn.net_export = net_export[:, :net_export_sum]
        push!(nodes, newn)
    end
    return nodes
end

function populate_heatareas(raw::RAW)
    heatareas = Vector{Heatarea}()
    for h in 1:nrow(raw.heatareas)
        index = h
        name = raw.heatareas[h, :index]
        demand = combine(groupby(filter(col -> col[:heatarea] == name, raw.demand_h), :timestep, sort=true), :demand_h => sum)
        plants = raw.plants[(raw.plants[:, :heatarea] .=== name).&(raw.plants[:, :h_max] .> 0), :int_idx]
        res_plants = raw.res_plants[(raw.res_plants[:, :heatarea] .=== name).&(raw.res_plants[:, :h_max] .> 0), :int_idx]
        newh = Heatarea(index, name, demand[:, :demand_h_sum], plants, res_plants)
        push!(heatareas, newh)
    end
    return heatareas
end

function populate_plants(raw::RAW)
    plants =  Vector{Plant}()
    for p in 1:nrow(raw.plants)
        index = p
        name = string(raw.plants[p, :index])
        node_name = raw.plants[p, :node]
        node_idx = raw.nodes[raw.nodes[:, :index] .== node_name, :int_idx][1]
        eta = raw.plants[p, :eta]*1.
        g_max = raw.plants[p, :g_max]*1.
        h_max = raw.plants[p, :h_max]*1.
        mc_el = raw.plants[p, :mc_el]*1.
        mc_heat = raw.plants[p, :mc_heat]*1.
        plant_type = raw.plants[p, :plant_type]
        newp = Plant(index, name, node_idx, mc_el,
                     mc_heat, eta, g_max, h_max, plant_type)
        if plant_type in union(raw.plant_types["hs"], raw.plant_types["es"])
            newp.inflow = raw.inflows[raw.inflows[:, :plant] .== name, :inflow]
            newp.storage_capacity = raw.plants[p, :storage_capacity]
        end
        push!(plants, newp)
    end
    return plants
end

function populate_res_plants(raw::RAW)
    res_plants = Vector{Renewables}()
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
        availability = combine(groupby(filter(col -> col[:plant] == name, raw.availability),
                                       :timestep, sort=true), :availability => sum)
        newres = Renewables(index, name, g_max, h_max, mc_el, mc_heat,
                            availability[:, :availability_sum],
                            node_idx, plant_type)
        push!(res_plants, newres)
    end
    return res_plants
end

function populate_dclines(raw::RAW)
    dc_lines = Vector{DC_Line}()
    for dc in 1:nrow(raw.dc_lines)
        index = dc
        name = raw.dc_lines[dc, :index]
        node_i = raw.dc_lines[dc, :node_i]
        node_j = raw.dc_lines[dc, :node_j]
        node_i_idx = raw.nodes[raw.nodes[:, :index] .== node_i, :int_idx][1]
        node_j_idx = raw.nodes[raw.nodes[:, :index] .== node_j, :int_idx][1]
        maxflow = raw.dc_lines[dc, :maxflow]*1.
        newdc = DC_Line(index, name, node_i_idx, node_j_idx, maxflow)
        push!(dc_lines, newdc)
    end
    return dc_lines
end

function populate_grid(raw::RAW)
    grid = Vector{Grid}()
    for cbco in 1:nrow(raw.grid)
        index = cbco
        name = raw.grid[cbco, :index]
        if in(raw.options["type"], ["cbco_zonal", "zonal"])
            ptdf = [x for x in raw.grid[cbco, Symbol.(collect(raw.zones[:,:index]))]]
        else
            ptdf = [x for x in raw.grid[cbco, Symbol.(collect(raw.nodes[:,:index]))]]
        end
        ram = raw.grid[cbco, :ram]*1.
        newcbco = Grid(index, name, ptdf, ram)
        if in(raw.options["type"], ["d2cf"])
            newcbco.reference_flow = Dict(collect(zip(raw.reference_flows[:, :index],
                                                      raw.reference_flows[:, Symbol(index)])))
        end
        if "zone" in string.(names(raw.grid))
            newcbco.zone_i = coalesce(raw.grid[cbco, :zone_i], nothing)
            newcbco.zone_j = coalesce(raw.grid[cbco, :zone_j], nothing)
        end
        if "timestep" in string.(names(raw.grid))
            newcbco.timestep = raw.grid[cbco, :timestep]
        end
        push!(grid, newcbco)
    end
    return grid
end

function set_model_horizon!(data)
	timesteps = [t.index for t in data.t]
	for n in data.nodes
		n.demand = n.demand[timesteps]
		n.net_export = n.net_export[timesteps]
	end
	for z in data.zones
		z.demand = z.demand[timesteps]
		if any([isdefined(z, :net_position) for z in data.zones])
			z.net_position = z.net_position[timesteps]
		end
		z.net_export = z.net_export[timesteps]
	end

	for res in data.renewables
		res.mu = res.mu[timesteps]
		res.mu_heat = res.mu_heat[timesteps]
		res.sigma = res.sigma[timesteps]
		res.sigma_heat = res.sigma_heat[timesteps]
	end
end
