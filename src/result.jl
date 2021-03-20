"""Result related functions."""

function get_result_info(pomato::POMATO)
	n, mapping = pomato.n, pomato.mapping
	var_info(x) = NamedTuple{(:sets, :indices, :columns, :dual), Tuple{Vector{Symbol}, Vector{AbstractArray{Int, 1}}, Vector{Symbol}, Bool}}(x)
	return Dict(:G => var_info(([:t, :plants], [1:n.t, 1:n.plants], [:t, :p, :G], false)),
			    :H => var_info(([:t, :plants], [1:n.t, mapping.he], [:t, :p, :H], false)),
			    :INJ => var_info(([:t, :nodes], [1:n.t, 1:n.nodes], [:t, :n, :INJ], false)),
			    :F_DC => var_info(([:t, :dc_lines], [1:n.t, 1:n.dc], [:t, :dc, :F_DC], false)),
			    :EX => var_info(([:t, :zones, :zones], [1:n.t, 1:n.zones, 1:n.zones], [:t, :z, :zz, :EX], false)),
			    :D_es => var_info(([:t, :plants], [1:n.t, mapping.es], [:t, :p, :D_es], false)),
			    :L_es => var_info(([:t, :plants], [1:n.t, mapping.es], [:t, :p, :L_es], false)),
			    :D_hs => var_info(([:t, :plants], [1:n.t, mapping.he[mapping.hs]], [:t, :p, :D_hs], false)),
			    :L_hs => var_info(([:t, :plants], [1:n.t, mapping.he[mapping.hs]], [:t, :p, :L_hs], false)),
			    :D_ph => var_info(([:t, :plants], [1:n.t, mapping.he[mapping.ph]], [:t, :p, :D_ph], false)),
			    :INFEASIBILITY_H_POS => var_info(([:t, :heatareas], [1:n.t, 1:n.heatareas], [:t, :ha, :INFEASIBILITY_H_POS], false)),
			    :INFEASIBILITY_H_NEG => var_info(([:t, :heatareas], [1:n.t, 1:n.heatareas], [:t, :ha, :INFEASIBILITY_H_NEG], false)),
			    :INFEASIBILITY_EL_POS => var_info(([:t, :nodes], [1:n.t, 1:n.nodes], [:t, :n, :INFEASIBILITY_EL_POS], false)),
			    :INFEASIBILITY_EL_NEG => var_info(([:t, :nodes], [1:n.t, 1:n.nodes], [:t, :n, :INFEASIBILITY_EL_NEG], false)),
			    :EB_nodal => var_info(([:t, :nodes], [1:n.t, 1:n.nodes], [:t, :n, :EB_nodal], true)),
			    :EB_zonal => var_info(([:t, :zones], [1:n.t, 1:n.zones], [:t, :z, :EB_zonal], true)),
			    :CURT => var_info(([:t, :renewables], [1:n.t, 1:n.res], [:t, :p, :CURT], false)),
			    :Alpha => var_info(([:t, :plants], [1:n.t, mapping.alpha], [:t, :p, :Alpha], false)),
			    :G_RES => var_info(([:t, :renewables], [1:n.t, 1:n.res], [:t, :p, :G_RES], false)),
			    :H_RES => var_info(([:t, :renewables], [1:n.t, 1:n.res], [:t, :p, :H_RES], false)),
			    :COST_G => var_info(([:t], [1:n.t], [:t, :COST_G], false)),
			    :COST_H => var_info(([:t], [1:n.t], [:t, :COST_H], false)),
			    :COST_EX => var_info(([:t], [1:n.t], [:t, :COST_EX], false)),
			    :COST_CURT => var_info(([:t], [1:n.t], [:t, :COST_CURT], false)),
			    :COST_REDISPATCH => var_info(([:t], [1:n.t], [:t, :COST_REDISPATCH], false)),
			    :COST_INFEASIBILITY_EL => var_info(([:t], [1:n.t], [:t, :COST_INFEASIBILITY_EL], false)),
			    :COST_INFEASIBILITY_H => var_info(([:t], [1:n.t], [:t, :COST_INFEASIBILITY_H], false)),
				)
end

function Result(pomato::POMATO)
	result_info = get_result_info(pomato)
	result = Result()
	for v in keys(result_info)
		setfield!(result, v, model_symbol_to_df(v, result_info, pomato))
	end

	setfield!(result, :G, vcat(result.G, rename!(result.G_RES, names(result.G))))
	setfield!(result, :H, vcat(result.H, rename!(result.H_RES, names(result.H))))
	# Misc Results or Data
	result.misc_results = Dict()
	result.misc_results["Objective Value"] = JuMP.objective_value(pomato.model)
	for cost in ["COST_G", "COST_H", "COST_EX", "COST_CURT", "COST_REDISPATCH", 
				 "COST_INFEASIBILITY_EL", "COST_INFEASIBILITY_H"]
		result.misc_results[cost] = sum(JuMP.value.(pomato.model[Symbol(cost)]))
	end
	result.misc_results["Solve Status"] = JuMP.termination_status(pomato.model)
	return result
end

function concat_results(results::Dict{String, Result})
	r = Result()
	for (field, field_type) in zip(fieldnames(Result), fieldtypes(Result))
		if field_type == DataFrame
			setfield!(r, field, vcat([getfield(results[k], field) for k in keys(results)]...))
		end
	end
	r.misc_results = Dict()
	r.misc_results["Objective Value"] = sum([results[k].misc_results["Objective Value"] for k in keys(results)])
	for cost in ["COST_G", "COST_H", "COST_EX", "COST_CURT", "COST_REDISPATCH", "COST_INFEASIBILITY_EL", "COST_INFEASIBILITY_H"]
		r.misc_results[cost] = sum([results[k].misc_results[cost] for k in keys(results)])
	end
	solved_to_opt = [results[k].misc_results["Solve Status"] != MOI.INFEASIBLE for k in keys(results)]
	if all(solved_to_opt)
		r.misc_results["Solve Status"] = MOI.OPTIMAL
	else
		@warn("Not all timesteps solved to optimality!")
		@warn("Suboptimal Timesteps: $(join(filter((k,v) -> v.misc_results["Solve Status"] == MOI.OPTIMAL, pomato_results) |> keys |> collect, ", "))")
	end
	return r
end

function model_symbol_to_df(v, result_info, pomato)
	if !(v in keys(pomato.model.obj_dict))
		arr = zeros(Int, 0, size(result_info[v].sets, 1))
	elseif result_info[v].dual
		arr = dual.(pomato.model[v])
	elseif typeof(pomato.model[v]) == Matrix{Float64}
		arr = pomato.model[v]
	else
		arr = value.(pomato.model[v])
	end
	dim_arr = [map(x -> x.name, getfield(pomato.data, s))[i] for (s,i) in zip(result_info[v].sets, result_info[v].indices)]
	dims = size(dim_arr, 1)
	rows = []
	for ind in CartesianIndices(size(arr))
		row_ind = [dim_arr[dim][ind.I[dim]] for dim in 1:dims]
		push!(rows, (row_ind..., arr[ind]))
	end
	dim_names = result_info[v].columns
	df = DataFrame([dim_names[i] => [row[i] for row in rows] for i in 1:length(dim_names)])
	return df
end
