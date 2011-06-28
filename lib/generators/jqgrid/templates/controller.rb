class <%= class_name.pluralize %>Controller < ApplicationController
	respond_to :html,:json
  
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
		respond_with() do |format|
			format.json { render :json => filter_on_params(<%=class_name%>, GRID_COLUMNS)}  
		end
	end
end