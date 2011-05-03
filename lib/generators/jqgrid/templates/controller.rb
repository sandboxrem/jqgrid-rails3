class <%= class_name.pluralize %>Controller < ApplicationController
	respond_to :html,:json
  
	protect_from_forgery :except => [:post_data]
  
	# Don't forget to edit routes if you're using RESTful routing
	# 
	#resources :<%=plural_name%>,:only => [:index] do
	#	collection do
	#	  post "post_data"
	#	end
	# end

	GRID_COLUMNS = [<%= columns.map {|x| ":#{x}"}.join(', ') %>]
	
	def post_data
		error_message = ""
		payment_params = {}
		GRID_COLUMNS.each {|c| <%= model_name %>_params[c] = params[c] if params[c]}
	 	case params[:oper]
			when 'add'
				if params["id"] == "_empty"
		  			<%= model_name %> = <%= camel %>.create(<%= model_name %>_params)
				end
			when 'edit'
				<%= model_name %> = <%= camel %>.find(params[:id])
				<%= model_name %>.update_attributes(<%= model_name %>_params)
				record_data = {}
				GRID_COLUMNS.each {|c| record_data[c] = <%= model_name %>.send(c)}
	  		when 'del'
				<%= camel %>.destroy_all(:id => params[:id].split(","))
	  		when 'sort'
				<%=plural_name%> = <%= camel %>.all
				<%=plural_name%>.each do |<%= model_name %>|
					<%= model_name %>.position = params['ids'].index(<%= model_name %>.id.to_s) + 1 if params['ids'].index(<%= model_name %>.id.to_s) 
		  			<%= model_name %>.save
				end
	  		else
				error_message = 'unknown action'
		end
	  
 		if <%= model_name %> && <%= model_name %>.errors.empty?
			render :json => [false, error_message, record_data] 
		else
			<%= model_name %>.errors.entries.each do |error|
				message << "<strong>#{<%= camel %>.human_attribute_name(error[0])}</strong> : #{error[1]}<br/>"
			end
			render :json =>[true, error_message, record_data]
		end
	end
	
	
	def index
	  current_page = params[:page] ? params[:page].to_i : 1
	  rows_per_page = params[:rows] ? params[:rows].to_i : 10
	
	  conditions={:page => current_page, :per_page => rows_per_page}
	  conditions[:order] = params["sidx"] + " " + params["sord"] unless (params[:sidx].blank? || params[:sord].blank?)
	  
	  if params[:_search] == "true"
		conditions[:conditions]=filter_by_conditions(GRID_COLUMNS)
	  end
	  
	  @<%= plural_name %>=<%= camel %>.paginate(conditions)
	  total_entries=@<%= plural_name %>.total_entries
	  
	  respond_with(@<%= plural_name %>) do |format|
		format.json { render :json => @<%= plural_name %>.to_jqgrid_json(GRID_COLUMNS, current_page, rows_per_page, total_entries)}  
	  end
	end

end