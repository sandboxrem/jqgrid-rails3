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

	GRID_COLUMNS = %w{<%= columns.map {|x| "#{x}"}.join(' ') %>}
	
	def post_data
		grid_add_edit_del(<%=class_name%>, GRID_COLUMNS)
	end
	
	
	def index
		grid_records, total_entries, current_page, rows_per_page = filter_on_params(<%=class_name%>, GRID_COLUMNS)
		
		respond_with(grid_records) do |format|
			format.json { render :json => jqgrid_json(grid_records, GRID_COLUMNS, current_page, rows_per_page, total_entries)}  
		end
	end
end