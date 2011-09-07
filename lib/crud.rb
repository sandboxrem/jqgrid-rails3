module JqgridCRUD
	private
	
	def grid_add (model_class, grid_columns)
		model_params = {}	
		grid_columns.each {|c| model_params[c] = str_to_column_type(model_class, params[c], c) if params[c]}

		record = model_class.create(model_params)
		grid_response(record)
	end

	def grid_edit (model_class, grid_columns)
		model_params = {}	
		grid_columns.each {|c| model_params[c] = str_to_column_type(model_class, params[c], c) if params[c]}

		record = model_class.find(params[:id])
		record.update_attributes(model_params)

		# Pass back the updated data so any virtual attributes are updated.
		record_data = {}
		grid_columns.each {|c| record_data[c] = get_column_value(record, c).to_s}
		grid_response(record, record_data)
	end
	
	def grid_del (model_class, grid_columns)
		model_class.destroy_all(:id => params[:id].split(","))
		grid_response
	end

	def grid_response (record = nil, record_data = nil)
 		if !record || record.errors.empty?
			render :json => [false, '', record_data] 
		else
			error_message << "<table>"
			record.errors.entries.each do |error|
				error_message << "<tr><td><strong>#{model_class.human_attribute_name(error[0])}</strong></td> <td>: #{error[1]}</td><td>"
			end
			error_message << "</table>"
			render :json =>[true, error_message, record_data]
		end
		
	end
end

class ActionController::Base
	include JqgridCRUD
end