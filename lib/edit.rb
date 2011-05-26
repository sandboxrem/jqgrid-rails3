class ActionController::Base

	def grid_add_edit_del (model_class, grid_columns)
		error_message = ""
		model_params = {}
		grid_columns = grid_columns.map(:to_sym)
		grid_columns.each {|c| model_params[c] = params[c] if params[c]}
	 	case params[:oper]
			when 'add'
				if params["id"] == "_empty"
		  			record = model_class.create(model_params)
				end
			when 'edit'
				record = model_class.find(params[:id])
				record.update_attributes(model_params)
				record_data = {}
				grid_columns.each {|c| record_data[c] = record.send(c)}
	  		when 'del'
				model_class.destroy_all(:id => params[:id].split(","))
	  		else
				error_message = 'unknown action'
		end
	  
 		if record && record.errors.empty?
			render :json => [false, error_message, record_data] 
		else
			record.errors.entries.each do |error|
				message << "<strong>#{model_class.human_attribute_name(error[0])}</strong> : #{error[1]}<br/>"
			end
			render :json =>[true, error_message, record_data]
		end
	end

end