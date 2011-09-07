class <%= class_name.pluralize %>Controller < ApplicationController
	respond_to :html,:json
  
	# Don't forget to edit routes.  :create, :update, :destroy should only be
	# present if your jqgrid has add, edit and del actions defined for it.
	# 
	#resources :<%=plural_name%>,:only => [:index, :create, :update, :destroy] do
	#	collection do
	#	  post "post_data"
<%=details.map {|detail| "\t#     post \"#{detail.model.downcase}_post_data\""}.join("\n")%>
<%=details.map {|detail| "\t#     get \"#{detail.model.downcase}_details\""}.join("\n")%>
	#	end
	# end

	GRID_COLUMNS = %w{<%= columns.map {|x| "#{x}"}.join(' ') %>}
	
	def index
		respond_with() do |format|
			format.json { render :json => filter_on_params(<%=class_name%>, GRID_COLUMNS)}  
		end
	end

 	# PUT /<%=class_name.downcase%>/1
	def update
		grid_edit(<%=class_name%>, GRID_COLUMNS)
	end
	
	# DELETE /<%=class_name.downcase%>/1
	def destroy
		grid_del(<%=class_name%>, GRID_COLUMNS)
	end
 
	# POST /<%=class_name.downcase%>
	def create
		grid_add(<%=class_name%>, GRID_COLUMNS)
	end

	
	<% details.each do |detail| %>
	<%=detail.model.upcase%>_GRID_COLUMNS = %w{<%= detail.columns.map {|x| "#{x}"}.join(' ') %>}

	def <%=detail.model.downcase%>_post_data
		grid_add_edit_del(<%=detail.model%>, <%=detail.model.upcase%>_GRID_COLUMNS)
	end

	def <%=detail.model.downcase%>_details
		respond_with() do |format|
			format.json { render :json => filter_details(<%=class_name%>, '<%=detail.foreign_key%>', <%=detail.model%>, <%=detail.model.upcase%>_GRID_COLUMNS)}  
		end
	end
	
	
	<% end %>
end
