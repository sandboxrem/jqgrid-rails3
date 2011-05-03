class Javascript 
	def initialize (code)
		@code = code
	end
	
	def to_json
		@code
	end
end


module Jqgrid

  	def jqgrid_stylesheets(theme="default")
      stylesheet_link_tag "jqgrid/themes/#{theme}/jquery-ui-1.8.custom.css", 
        'jqgrid/ui.jqgrid.css', 
        :cache => "jqgrid-#{theme}-css"
    end

    def jqgrid_javascripts
      locale = I18n.locale rescue :en
      javascript_include_tag 'jqgrid/jquery-ui-1.8.custom.min.js',
        "jqgrid/i18n/grid.locale-#{locale}.js",
        'jqgrid/jquery.jqGrid.min.js',
        # Don't know if we need it, if smth not working, just uncomment it
        #'jqgrid/grid.tbltogrid',
        'jqgrid/jquery.contextmenu.r2.packed.js', 
        :cache => 'jqgrid-js'
    end

	@@app_grid_options = {}
	def self.jqgrid_app_grid_options (options)
		@@app_grid_options = options
	end

	@@app_pager_options = {}
	def self.jqgrid_app_pager_options (options)
		@@app_pager_options = options
	end
	
	# http://www.trirand.com/jqgridwiki/doku.php?id=wiki:options 
	def jqgrid(caption, id, url, columns = [], options = {})
 		@id = id

     	default_options = 
        { 
          	# Can be nil or false to disregard all errors, :default to show the errors or a
		  	# string holding the js error handler name you want to use (its code is part of the view).
			:error_handler       => :default,  
			
   
			# No searching via the filterbar is done if this is nil or false, otherwise it takes a hash of the filter options.
			# http://www.trirand.net/documentation/php/_2v70waupp.htm
         	:search				 => {:searchOnEnter => false},

			:url				 => "#{url}?q=1",
			:caption			 => caption,
			:datatype			 => :json,


			# Can be :inline to allow inline editing in the table or :form to pop up a form to do the editing in.
			# If it is nil or false then no editing can be done.
			:edit_method		 => :inline,


			# http://www.trirand.com/jqgridwiki/doku.php?id=wiki:navigator
			:add                 => false,
			:delete              => false,
			:view                => false,          
			:edit_options 		=> {:closeOnEscape => true, :modal => true, :recreateForm => true, :width => 300, :closeAfterEdit => true,
										:afterSubmit => Javascript.new("function(r,data) {return ERROR_HANDLER_NAME(r,data,'edit')}")},

			:add_options 		=> {:closeOnEscape => true, :modal => true, :recreateForm => true, :width => 300, :closeAfterAdd => true,
										:afterSubmit => Javascript.new("function(r,data) {return ERROR_HANDLER_NAME(r,data,'add')}")},

			:delete_options 	=> {:closeOnEscape => true, :modal => true,
										:afterSubmit => Javascript.new("function(r,data) {return ERROR_HANDLER_NAME(r,data,'delete')}")},


			:height				=> 500,
			:resizable			=> true,
			
			# :width				=> 600,
			# 		    :viewrecords		=> true,

		   	:rowNum				=> 10,
			:rowTotal			=> 2000,



			:rowlist             => [10,25,50,100],				# not the jqgrid default ???
			:context_menu        => false,
        }.merge(options)

		# Combine all options with default having the lowest priority, then any app level options and finally view specific
		# options.
 		@grid_options = default_options.merge(@@app_grid_options).merge(options)
  		@grid_methods = []

    	# Take out the higher level options and convert to options and jqgrid methods.		
		
		grid_loaded_options (:grid_loaded)
 		master_details_options(:master_details, :details_url, :details_caption)
		context_menu_options(:context_menu)
		selection_options(:selection, :selection_handler)
		error_handler_options (:error_handler)
		pager_options(:pager)	
		inline_edit
		navigator_options
 		search_options(:search)
		resizable
		
		# Generate columns data
		gen_columns(columns)

		@grid_options.delete(:edit_method)
		
    	# Generate required Javascript & html to create the jqgrid
		"<script type = 'text/javascript'>
			var lastsel, lastedit;
			jQuery(document).ready(function()
			{
				jQuery('##{@id}').jqGrid({
					#{grid_options}
				})				

				#{grid_methods}
			})
		</script>

		<div id='flash_alert' style='display:none;padding:0.7em;' class='ui-state-highlight ui-corner-all'></div>
		<table id='#{@id}' class='scroll' cellpadding='0' cellspacing='0'></table>
		<div id='#{@id}_pager' class='scroll' style='text-align:center;'></div>
		"    
    end

    private
 
	# Returns an array of js properties from a hash, i.e. each hash entry is converted to key: value_as_js_type
	def js_properties (hsh)
		hsh ? hsh.map {|key, value|  "#{key}: #{value.to_json}"} : []
	end
	
	# Convert the grid options to js properties.
	def grid_options
		js_properties(@grid_options).join(",\n")
	end
	
	def grid_methods
		@grid_methods.join("\n")
	end
	
	# Enable filtering (by default)
	def search_options (options)
		options = @grid_options.delete(options)
		if options
			@grid_methods << 
			%Q^jQuery("##{@id}").navButtonAdd("##{@id}_pager", {caption: "", title: $.jgrid.nav.searchtitle, buttonicon :'ui-icon-search', onClickButton:function(){ jQuery("##{@id}")[0].toggleToolbar() } })^
		      		@grid_methods << %Q^jQuery("##{@id}").filterToolbar({#{js_properties(options)}}); jQuery("##{@id}")[0].toggleToolbar()^
		end
    end

	# When  options[:error_handler] == nil 		then use the null error handler (it does nothing so ignores any errors)
	# When  options[:error_handler] == :default then use the default error handler and displays the errors.
	# When  options[:error_handler] == a string then the string holds the name of the error handler to use.  The code is provided
	#  									as part of the view.
	def error_handler_options (handler)
	   	handler = @grid_options.delete(handler)
		case handler
			when nil
				# Null error handler - just ignore all errors.
				@error_handler_name = 'null_error_handler'
				 @grid_methods << 
					%Q^function null_error_handler (r, data, action) 
					{
						return true
					}^
			when :default
			    # Construct default error handler code to display the error
				@error_handler_name = 'default_error_handler'
		        @grid_methods <<
		 			%Q^function default_error_handler (r, data, action) 
					{
			       		var resText = JSON.parse (r.responseText)
			          	if (resText[0])
					  	{
			            	$('#flash_alert').html("<span class='ui-icon ui-icon-info' style='float:left; margin-right:.3em;'><\/span>"+resText[1])
			            	$('#flash_alert').slideDown()
			            	window.setTimeout(function() {$('#flash_alert').slideUp()}, 3000)
			              	return false
			         	}
						else
						{
			        		return true
			        	}
					}^			    
			else
				# Custom error handler
				@error_handler_name = handler
		end
	end		
				
	# Enable inline editing with a double click.
	def inline_edit
		if @grid_options[:edit_method] == :inline
			# The code is passed in as a option so must not be converted into a quoted string when
			# converted to json.  After the edit is completed the row is selected again.
			@grid_options[:ondblClickRow] = Javascript.new(
			%Q^function(id){
	        	if (id && id !== lastedit)
				{
	            	jQuery('##{@id}').restoreRow(lastsel)
				}
            	lastedit = id
            	jQuery('##{@id}').editRow(id, true, null, #{@error_handler_name}, null, null, 
					function(id, resp) {
						var response = JSON.parse (resp.responseText)
						jQuery('##{@id}').setRowData(lastedit, response[2])
					}) 
	        }^)
	
			# If we are in the middle of an inline edit and the user selects another row then abandon the edit.
			@grid_options[:onSelectRow] = Javascript.new(
			%Q^function(id){
	        	if (id && id !== lastsel && id != lastedit)
				{
	            	jQuery('##{@id}').restoreRow(lastsel)
	            	lastsel = id
					lastedit = null
	          	} 
	        }^)
			
		end
	end

	# Enable master-details
	def master_details_options (master_details, url, caption)
		url = @grid_options.delete(url)
		caption = @grid_options.delete(caption)
		if @grid_options.delete(master_details)
			@grid_options[:onSelectRow] = Javascript.new(
			%Q^function(ids) { 
					if (ids == null) 
					{ 
						ids = 0; 
						if (jQuery ("##{@id}_details").getGridParam('records') > 0) 
						{ 
							jQuery ("##{@id}_details").setGridParam({url:"#{url}?q=1&id="+ids,page:1})
							.setCaption ("#{caption}: "+ids)
							.trigger('reloadGrid'); 
						} 
					} 
					else 
					{ 
						jQuery("##{id}_details").setGridParam({url:"#{url}?q=1&id="+ids,page:1})
							.setCaption("#{caption} : "+ids)
							.trigger('reloadGrid'); 
					} 
				}^)
		end
	end
	
	# Enable grid_loaded callback
    # When data are loaded into the grid, call the Javascript function options[:grid_loaded] (defined by the user)
	def grid_loaded_options (callback)
		if callback = @grid_options.delete(callback)
			@grid_methods << %Q^	loadComplete: function(){#{callback}();}^
		end
	end

	# Context menu
	# See http://www.trendskitchens.co.nz/jquery/contextmenu/
	# http://www.hard-bit.net/files/jqGrid-3.5/ContextMenu.html
	# http://www.hard-bit.net/blog/?p=171
	# set to {:menu_bindings => xx, :menu_id => yy}, as needed.
	def context_menu_options (option)
		if cm = @grid_options.delete(option)
			@grid_methos <<
			%Q^
				afterInsertRow: function(rowid, rowdata, rowelem){
					$('#' + rowid).contextMenu('#{cm[:menu_id]}', #{cm[:menu_bindings]});
			}^
		end
	end

	def selection_options (mode, handler)
		mode = @grid_options.delete(:selection)
		@selection_handler = @grid_options.delete(:selection_handler)
		case mode
			when nil
			when :multi_selection				# checkboxes
				@grid_options[:multiselect] = true
				@grid_methos <<
				%Q^
		          jQuery("##{@id}_select_button").click(function() { 
		            var s; s = jQuery("##{id}").getGridParam('selarrrow'); 
		            #{handler}(s); 
		            return false;
		          });^

			when :direct_selection
				# Enable direct selection (when a row in the table is clicked)
			    # The javascript function created by the user (options[:selection_handler]) will be called with the selected row id as a parameter
			    @grid_methods <<
			  	%Q^onSelectRow: function(id){ 
			       if(id){ 
			            #{handler}(id); 
			       } 
			    }^
				
			when :button
		      # Enable selection link, button
		      # The javascript function created by the user (options[:selection_handler]) will be called with the selected row id as a parameter
			    @grid_methods <<
		        %Q^
		        jQuery("##{@id}_select_button").click( function(){ 
		          var id = jQuery("##{@id}").getGridParam('selrow'); 
		          if (id) { 
		            #{handler}(id); 
		          } else { 
		            alert("Please select a row");
		          }
		          return false; 
		        });^
			else
				raise "Unknown value for jqGrid option[:selection]: #{mode}"
		end
	end	
	
	# http://www.trirand.com/jqgridwiki/doku.php?id=wiki:pager
	def pager_options (pager)
		# pager = @@app_grid_options.merge(@grid_options.delete(pager))
		# return if pager.empty?
		
		pager_name = "##{@id}_pager"

		# Add in the pager specific options
		@grid_options[:pager] = pager_name
		# rowList
		# viewRecords
	end
	
	# http://www.trirand.com/jqgridwiki/doku.php?id=wiki:navigator
	def navigator_options
		edit 		 = @grid_options[:edit_method] == :form
    	add          = @grid_options.delete(:add)
		delete       = @grid_options.delete(:delete)
		view         = @grid_options.delete(:view)

		edit_options 	= @grid_options.delete(:edit_options)
		add_options 	= @grid_options.delete(:add_options)
		delete_options 	= @grid_options.delete(:delete_options)

		edit_options 	= {} if !edit
		add_options 	= {} if !add
		delete_options 	= {} if !delete

	    js = %Q^jQuery("##{@id}").navGrid('##{@id}_pager',
			{edit: #{edit}, add: #{add}, del: #{delete}, view: #{view}, search: false, refresh: true},
				{#{js_properties(edit_options).join(", ")}},
				{#{js_properties(add_options).join(", ")}},
				{#{js_properties(delete_options).join(", ")}}
		)
		^

		@grid_methods << js.gsub(/ERROR_HANDLER_NAME/, "#{@error_handler_name}") 
	end
	
    # Recalculate width of grid based on parent container.
    # ref: http://www.trirand.com/blog/?page_id=393/feature-request/Resizable%20grid/
	def resizable
		return if !@grid_options.delete(:resizable)
		@grid_methods <<
		%Q^
		function _recalc_width(){
          if (grids = jQuery('"#{@id}".ui-jqgrid-btable:visible')) {
            grids.each(function(index) {
              gridId = jQuery(this).attr('id');
              gridParentWidth = jQuery('#gbox_' + gridId).parent().width();
              jQuery('#' + gridId).setGridWidth(gridParentWidth);
            });
          }
        };

        jQuery(window).bind('resize', _recalc_width);
    	^
	end
	
	def gen_columns (columns)
		# Add in the missing property.
		columns.each {|c| c[:index] = c[:name]}
		
		# Convert each column into the required form.  It is wrapped in a Javascript object to prevent
		# it from being converted to json again.
	 	cols = columns.map {|c| "{" + js_properties(c).join(", ") + "}"}
		@grid_options[:colModel] = Javascript.new("[#{cols.join(', ')}]")		
	end
end


module JqgridJson
  JSON_ESCAPE_MAP = {
    '\\'    => '\\\\',
    '</'    => '<\/',
    "\r\n"  => '\n',
    "\n"    => '\n',
    "\r"    => '\n',
    '"'     => '\\"' }
  
  def to_jqgrid_json(attributes, current_page, per_page, total)
    json = %Q({"page":"#{current_page}","total":#{total/per_page.to_i+1},"records":"#{total}")
    if total > 0
      json << %Q(,"rows":[)
      each do |elem|
        elem.id ||= index(elem)
        json << %Q({"id":"#{elem.id}","cell":[)
        couples = elem.attributes.symbolize_keys
        attributes.each do |atr|
          value = get_atr_value(elem, atr, couples)
          value = escape_json(value) if value and value.is_a? String
          json << %Q("#{value}",)
         end
        json.chop! << "]},"
      end
      json.chop! << "]}"
    else
      json << "}"
    end
  end
  
  private
    
  def escape_json(json)
    if json
      json.gsub(/(\\|<\/|\r\n|[\n\r"])/) { JSON_ESCAPE_MAP[$1] }
    else
      ''
    end
  end

  def get_atr_value(elem, atr, couples)
    if atr.instance_of?(String) && atr.to_s.include?('.')
      value = get_nested_atr_value(elem, atr.to_s.split('.').reverse) 
    else
      value = couples[atr]
      value = _resolve_value(atr, elem)
     # value = elem.send(atr.to_sym) if value.blank? && elem.respond_to?(atr) # Required for virtual attributes
    end
    value
  end
  def _resolve_value(value, record)
    case value
    when Symbol
      if record.respond_to?(value)
        record.send(value) 
      else 
        value.to_s
      end
    when Proc
      value.call(record)
    else
      value
    end
  end
  def get_nested_atr_value(elem, hierarchy)
    return nil if hierarchy.size == 0
    atr = hierarchy.pop
    raise ArgumentError, "#{atr} doesn't exist on #{elem.inspect}" unless elem.respond_to?(atr)
    nested_elem = elem.send(atr)
    return "" if nested_elem.nil?
    value = get_nested_atr_value(nested_elem, hierarchy)
    value.nil? ? nested_elem : value
  end
end


module JqgridFilter
  def filter_by_conditions(columns)
    conditions = ""
    columns.each do |column|
      conditions << "#{column} LIKE '%#{params[column]}%' AND " unless params[column].nil?
    end
    conditions.chomp("AND ")
  end
end


	
=begin      
      # Enable subgrids
      subgrid = ""
      subgrid_enabled = "subGrid:false,"

      if options[:subgrid].present?
        
        subgrid_enabled = "subGrid:true,"
        
        options[:subgrid] = 
          {
            :rows_per_page => 10,
            :sort_column   => 'id',
            :sort_order    => 'asc',
            :add           => false,
            :edit          => false,
            :delete        => false,
            :search        => false,
            :viewrecords   => true,
            :rowlist       => '[10,25,50,100]',
            :shrinkToFit   => false
          }.merge(options[:subgrid])

        # Stringify options values
        options[:subgrid].inject({}) do |suboptions, (key, value)|
          suboptions[key] = value.to_s
          suboptions
        end
        
        subgrid_inline_edit = ""
        if options[:subgrid][:inline_edit] == true
          options[:subgrid][:edit] = false
          subgrid_inline_edit = %Q^
          onSelectRow: function(id){ 
            if(id && id!==lastsel){ 
              jQuery('#'+subgrid_table_id).restoreRow(lastsel);
              jQuery('#'+subgrid_table_id).editRow(id,true); 
              lastsel=id; 
            } 
          },
          ^
        end
          
        if options[:subgrid][:direct_selection] && options[:subgrid][:selection_handler].present?
          subgrid_direct_link = %Q/
          onSelectRow: function(id){ 
            if(id){ 
              #{options[:subgrid][:selection_handler]}(id); 
            } 
          },
          /
        end     
        
        sub_col_names, sub_col_model = gen_columns(options[:subgrid][:columns])
        
        subgrid = %Q(
        subGridRowExpanded: function(subgrid_id, row_id) {
        		var subgrid_table_id, pager_id;
        		subgrid_table_id = subgrid_id+"_t";
        		pager_id = "p_"+subgrid_table_id;
        		$("#"+subgrid_id).html("<table id='"+subgrid_table_id+"' class='scroll'></table><div id='"+pager_id+"' class='scroll'></div>");
        		jQuery("#"+subgrid_table_id).jqGrid({
        			url:"#{options[:subgrid][:url]}?q=2&id="+row_id,
              editurl:'#{options[:subgrid][:edit_url]}?parent_id='+row_id,                            
        			datatype: "json",
        			colNames: #{sub_col_names},
        			colModel: #{sub_col_model},
        		   	rowNum:#{options[:subgrid][:rows_per_page]},
        		   	pager: pager_id,
        		   	imgpath: '/images/jqgrid',
        		   	sortname: '#{options[:subgrid][:sort_column]}',
        		    sortorder: '#{options[:subgrid][:sort_order]}',
                viewrecords: #{options[:subgrid][:viewrecords]},
                rowlist: #{options[:subgrid][:rowlist]},
                shrinkToFit: #{options[:subgrid][:shrinkToFit]},
                toolbar : [true,"top"], 
        		    #{subgrid_inline_edit}
        		    #{subgrid_direct_link}
        		    height: '100%'
        		})
        		.navGrid("#"+pager_id,{edit:#{options[:subgrid][:edit]},add:#{options[:subgrid][:add]},del:#{options[:subgrid][:delete]},search:false})
        		.navButtonAdd("#"+pager_id,{caption:"Search",title:"Toggle Search",buttonimg:'/images/jqgrid/search.png',
            	onClickButton:function(){ 
            		if(jQuery("#t_"+subgrid_table_id).css("display")=="none") {
            			jQuery("#t_"+subgrid_table_id).css("display","");
            		} else {
            			jQuery("#t_"+subgrid_table_id).css("display","none");
            		}
            	} 
            });
            jQuery("#t_"+subgrid_table_id).height(25).hide().filterGrid(""+subgrid_table_id,{gridModel:true,gridToolbar:true});
        	},
        	subGridRowColapsed: function(subgrid_id, row_id) {
        	},
        )
      end




   url:'#{action}?q=1',
      editurl:'#{options[:edit_url]}',
      datatype: "json",
      colNames:#{col_names},
      colModel:#{col_model},
      pager: '##{id}_pager',
      pagerpos:'#{options[:pagerpos]}', 
      rowNum:#{options[:rows_per_page]},
      rowList:#{options[:rowlist]},
      viewrecords:#{options[:viewrecords]},
      height: #{options[:height]},
      #{"sortname: '#{options[:sort_column]}'," unless options[:sort_column].blank?}
      #{"sortorder: '#{options[:sort_order]}'," unless options[:sort_order].blank?}
      gridview: #{options[:gridview]},
      scrollrows: true,
      autowidth: #{options[:autowidth]},
      loadui: '#{options[:loadui]}',
      rownumbers: #{options[:rownumbers]},
      hiddengrid: #{options[:hiddengrid]},
      hidegrid: #{options[:hidegrid]}, 
      shrinkToFit: #{options[:shrinkToFit]}, 
      #{multiselect}
      #{master_details}
      #{grid_loaded}
      #{direct_link}
      #{editable}
      #{context_menu}
      #{subgrid_enabled}
      #{subgrid}
      caption: "#{title}"             

    .navGrid('##{id}_pager',
      {edit:#{edit_button},add:#{options[:add]},del:#{options[:delete]},view:#{options[:view]},search:false,refresh:true},
      // Edit options
      {closeOnEscape:true,modal:true,recreateForm:#{options[:recreateForm]},width:#{options[:form_width]},closeAfterEdit:true,afterSubmit:function(r,data){return #{error_handler_name}(r,data,'edit');}},
      // Add options
      {closeOnEscape:true,modal:true,recreateForm:#{options[:recreateForm]},width:#{options[:form_width]},closeAfterAdd:true,afterSubmit:function(r,data){return #{error_handler_name}(r,data,'add');}},
      // Delete options
      {closeOnEscape:true,modal:true,afterSubmit:function(r,data){return #{error_handler_name}(r,data,'delete');}}
    )
    #{search}
    #{multihandler}
    #{selection_link}
    #{filter_toolbar}
  #{'})' unless options[:omit_ready]};
</script>
<div id="flash_alert" style="display:none;padding:0.7em;" class="ui-state-highlight ui-corner-all"></div>
<table id="#{id}" class="scroll" cellpadding="0" cellspacing="0"></table>
<div id="#{id}_pager" class="scroll" style="text-align:center;"></div>











=end
