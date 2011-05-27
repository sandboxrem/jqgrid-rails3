class ActionController::Base

	# Convert the given columns and their values into SQL search terms while
	# protecting agains SQL injection.
	def filter_by_conditions (filter_columns)
		query = filter_columns.keys.map {|c| "#{c} LIKE ?"}.join(' AND ')
		data = filter_columns.keys.map {|c| "%#{filter_columns[c]}%"}
		[query] + data
	end

	# A param is special and cannot use the normal AR find method if it is a virtual attribute or it is tagged with 
	# one of the match criteria.  
	# The prefix match criteria are:
	# 	=		exact match to following string (may be empty for empty or null attribute),
	#   !=		not match to following string (may be empty for empty or null attribute),,
	#   >		attribute is greater than follow number, similarly for >=, < and <= 
	#   ~		attribute is tested agains the following string as a regular expression for a match
	#   !~		attribute is tested agains the following string as a regular expression for not a match
	#   ^		attribute must start with the following string
	# The middle match criteria are:
	#   ..		where the attribute must be >= the before .. string/number and < the .. after string/number
	# The postfix match criteria are:
	#   $ 		attribute must end with the preceding string
	# A string with out a prefix or postfix must be contained by the attribute for a match (same as the SQL LIKE operator).
	def special_match_condition? (param)
		if	param =~ /^(=|!=|>|~|!=|\^)/ || 					# a prefix match criteria
			param =~ /.+\.\..+/			||						# a middle match criteria
			param =~ /\$$/										# a post fix match criteria
				true
		else
				false
		end
	end
	
	def special_filter (model_class, regular, special, virtual, sort_index, sort_direction, current_page, rows_per_page)
		# Cache results between requests to speed up pagination and changes to sort order.
		##### Don't know how to do just yet - data is too large for flash so disable storing in flash for now.
		##### the fact that it doesn't work just costs performance at present...
		cache_key = [model_class, regular, special, virtual, sort_index]
		if !flash[:grid_records_cache] || flash[:grid_records_cache_attribs] != cache_key
			# Cached records, if present are not valid
			if regular.empty?
				# No regular search parameters so just grab everything.
				grid_records = model_class.all
			else
				# Query AR to get the super set of what we want.
				sql_query, sql_query_data = filter_by_conditions(regular)
				grid_records = model_class.where(sql_query, sql_query_data)
			end
	
			# Successively filter based on each condition
			special.merge(virtual).each do |col, param|
				case param 
					when /^~(.*)/, /^(\^.*)/, /(.*\$)$/		# matches against user regexp, starts with, ends with
						re = Regexp.new($1, Regexp::IGNORECASE)
						grid_records = grid_records.find_all {|r| get_column_value(r, col).to_s =~ re}

					when /^!~(.*)/								# does not match against user regexp
						re = Regexp.new($1, Regexp::IGNORECASE)
						grid_records = grid_records.find_all {|r| get_column_value(r, col).to_s !~ re}
						
					when /^=(.*)/								# exact match
						re = Regexp.new("^#{$1}$", Regexp::IGNORECASE)
						grid_records = grid_records.find_all {|r| get_column_value(r, col).to_s =~ re}

					when /^!=(.*)/								# exact non match
						re = Regexp.new("^#{$1}$", Regexp::IGNORECASE)
						grid_records = grid_records.find_all {|r| get_column_value(r, col).to_s !~ re}

					when /^>=(.*)/								# >=
						value = $1.to_f
						grid_records = grid_records.find_all {|r| get_column_value(r, col).to_f >= value}

					when /^>(.*)/								# >
						value = $1.to_f
						grid_records = grid_records.find_all {|r| get_column_value(r, col).to_f > value}

					when /^<=(.*)/								# <=
						value = $1.to_f
						grid_records = grid_records.find_all {|r| get_column_value(r, col).to_f <= value}

					when /^<(.*)/								# <
						value = $1.to_f
						grid_records = grid_records.find_all {|r| get_column_value(r, col).to_f < value}

					when /(.+)\.\.(.+)/	
						min = $1.to_f
						max = $2.to_f
						grid_records = grid_records.find_all do |r|
							value = get_column_value(r, col).to_f
							value >= min && value < max
						end
					else
						# Virtual attribute with no match so look for contains
						re = Regexp.new(param, Regexp::IGNORECASE)
						grid_records = grid_records.find_all {|r| get_column_value(r, col) =~ re}
				end
			end
			
			# Sort the results (this will be done on :id if non provided so as to stay consistent with the AR path)
			if model_class.columns_hash[sort_index.to_s]
				# Attribute.
				if sort_direction == 'asc'
					grid_records.sort! {|a, b| a.send(sort_index) <=> b.send(sort_index)}
				else
					grid_records.sort! {|a, b| b.send(sort_index) <=> a.send(sort_index)}
				end
			else
				# Virtual attribute.  Use sort_by to cache the virtual attributes before sorting in case
				# the virtual attributes have a high calculation cost.
				grid_records = grid_records.sort_by {|r| get_column_value(r, sort_index)}
				grid_records.reverse! if sort_direction == 'desc'
			end
		else
			grid_records = flash[:grid_records_cache]
			# Check if the sorting direction has changed.
			if sort_direction != flash[:grid_records_cache_sort_direction]
				grid_records.reverse!
			end
		end

		# Keep the results for the next (and only) the next request.
		# flash[:grid_records_cache_attribs] = cache_key
		# flash[:grid_records_cache] = grid_records					##### to big to store in flash!!!!
		# flash[:grid_records_cache_sort_direction] = sort_direction

		# Get the range of records
		if grid_records.length > rows_per_page
			start = current_page * rows_per_page
			start = grid_records.length - rows_per_page if start + rows_per_page > grid_records.length 
		else
			start = 0
		end
		
		return grid_records[start, rows_per_page], grid_records.length
	end
	
	def filter_on_params (model_class, grid_colunms)
		ar_options = {}
		current_page = params[:page] ? params[:page].to_i : 1
		rows_per_page = params[:rows] ? params[:rows].to_i : 10

		# Make sorting consistent regardless if done by AR or manually.
		sort_index = params[:sidx] && params[:sidx] != '' ? params[:sidx] : :id
		sort_dir = params[:sord] || 'asc'
		ar_options[:order] = "#{sort_index} #{sort_dir}"

		# Analyse the input params to see if any have the special match conditions or are virtual attributes.
		regular_attribute_params = {}
		special_attribute_params = {}
		virtual_attribute_params = {}
		grid_colunms.each do |c|
			param = params[c]
			if param
				if model_class.columns_hash[c.to_s]
					if special_match_condition?(param)
						special_attribute_params[c] = param
					else
						regular_attribute_params[c] = param
					end
				else
					virtual_attribute_params[c] = param
				end
			end
		end
		
		sort_on_virtual_attribute = !model_class.columns_hash[sort_index.to_s] ? sort_index : false

		if !sort_on_virtual_attribute && special_attribute_params.empty? && virtual_attribute_params.empty?
			# Get rid of any caching.
			#####  (for flash this will happen automatically) but needs to be done manually 
			ar_options[:conditions] = filter_by_conditions(regular_attribute_params) if params[:_search] == "true"
			ar_options[:page] = current_page
			ar_options[:per_page] = rows_per_page

			grid_records = model_class.paginate(ar_options)
			total_entries = grid_records.total_entries
		else
			grid_records, total_entries = special_filter(model_class, regular_attribute_params, special_attribute_params, virtual_attribute_params, 
															sort_index, sort_dir,
															current_page, rows_per_page)
		end
		
		return grid_records, total_entries, current_page, rows_per_page
	end	
	
	JSON_ESCAPE_MAP = {	  '\\'	  => '\\\\',
						  '</'	  => '<\/',
						  "\r\n"  => '\n',
						  "\n"	  => '\n',
						  "\r"	  => '\n',
						  '"'	  => '\\"' }

	def jqgrid_json (records, grid_columns, current_page, per_page, total)
		json = %Q^{"page": "#{current_page}","total": #{total/per_page.to_i + 1}, "records": "#{total}"^
		if total > 0
			rows = records.map do |record|
				record.id ||= index(record)
				columns = grid_columns.map do |column|
					value = get_column_value(record, column)
					value = escape_json(value) if value && value.kind_of?(String)
					%Q^"#{value}"^
				end
				%Q^{"id": "#{record.id}", "cell": [#{columns.join(',')}]}^
			end
			json << %Q^, "rows": [ #{rows.join(',')}]^
		end
		json << "}"
	end

	def escape_json(json)
		json ? json.gsub(/(\\|<\/|\r\n|[\n\r"])/) { JSON_ESCAPE_MAP[$1] } : ''
	end

	def get_column_value(record, column)
		column.split('.').reduce(record) do |obj, method| 
			next_obj = obj.send(method)
			return '' if !next_obj || next_obj == ''
			next_obj
		end
	end

# 	def _resolve_value(value, record)
# 		case value
# 			when Symbol
# 				if record.respond_to?(value)
# 					record.send(value) 
# 				else 
# 					value.to_s
# 				end
# 			when Proc
# 				value.call(record)
# 			else
# 				value
# 		end
# 	end
# 
# 	def get_nested_atr_value(elem, hierarchy)
# puts "XXXXXXXXXXXXXXXXX"
# 		return nil if hierarchy.size == 0
# 		atr = hierarchy.pop
# 		raise ArgumentError, "#{atr} doesn't exist on #{elem.inspect}" unless elem.respond_to?(atr)
# 		nested_elem = elem.send(atr)
# 		return "" if nested_elem.nil?
# 		value = get_nested_atr_value(nested_elem, hierarchy)
# 		value.nil? ? nested_elem : value
# 	end
end