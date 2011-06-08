module JqgridFilter
	
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
	
	# Convert the str to the same type as the column so we can use comparison operators.
	# Use the value from grid_records to guess the type as any virtual attributes or attribute
	# paths will have been resolved.
	def str_to_column_type (grid_records, str, col)
		begin
			value = case grid_records[0][col]
						when String		then str
						when Fixnum		then str.to_i
						when Float		then str.to_f
						when Date		then Date.strptime(str, Date::DATE_FORMATS[:default] || Date::DATE_FORMATS[:number])
						when Time		then Time.strptime(str, Time::DATE_FORMATS[:default] || Time::DATE_FORMATS[:number])
						when BigDecimal then str.to_d
						else
							raise "need to add type conversion here for #{grid_records[0][col].class}"
					end	
		rescue ArgumentError
			puts "ARGUMENT ERROR - str = #{str} for #{grid_records[0][col].class}"
			# The date or time conversion may have been passed an incomplete or wrong data or time to convert so return nil
			# so the filtering can be skipped until we get a good value.
			nil
		end	
	end
	
	def special_filter (model_class, grid_columns, regular, special, sort_index, sort_direction, current_page, rows_per_page)
		# Cache results between requests to speed up pagination and changes to sort order.  The cache will expire so is only
		# for short term use, however if any of the underlying tables are updated then the cache will *not* be invalidated
		#  (will be fixed in the future).
		cache_key = [model_class.to_s, regular, special, sort_index].inspect

		grid_records = Rails.cache.fetch(cache_key, :expires_in => 1.minutes) do
			# Cache miss, so do the work...
			if regular.empty?
				# No regular search parameters so just grab everything.
				grid_records = model_class.all
			else
				# Query AR to get the super set of what we want.
				sql_query, sql_query_data = filter_by_conditions(regular)
				grid_records = model_class.where(sql_query, sql_query_data)
			end

			# Convert all column data in each record into a simple hash, keyed with the column's name and
			# expanded so any virtual attributes or attributes with a path are resolved (so we only do it once).
			# This is for efficiency reasons.
			grid_records = grid_records.map do |record|
				grid_columns.reduce({}) {|hsh, col| hsh[col] = get_column_value(record, col); hsh}
			end
	
			# Successively filter based on each condition
			special.each do |col, param|
				case param 
					when /^~(.*)/, /^(\^.*)/, /(.*\$)$/		# matches against user regexp, starts with, ends with
						re = Regexp.new($1, Regexp::IGNORECASE)
						grid_records = grid_records.find_all {|r| r[col].to_s =~ re}

					when /^!~(.*)/								# does not match against user regexp
						re = Regexp.new($1, Regexp::IGNORECASE)
						grid_records = grid_records.find_all {|r| r[col].to_s !~ re}
						
					when /^=(.*)/								# exact match (use re so case insensitive)
						re = Regexp.new("^#{$1}$", Regexp::IGNORECASE)
						grid_records = grid_records.find_all {|r| r[col].to_s =~ re}

					when /^!=(.*)/								# exact non match (use re so case insensitive)
						re = Regexp.new("^#{$1}$", Regexp::IGNORECASE)
						grid_records = grid_records.find_all {|r| r[col].to_s !~ re}

					when /^>=(.*)/								# >=
						value = str_to_column_type(grid_records, $1, col)
						grid_records = grid_records.find_all {|r| r[col] >= value} if value

					when /^>(.*)/								# >
						value = str_to_column_type(grid_records, $1, col)
						grid_records = grid_records.find_all {|r| r[col] > value} if value

					when /^<=(.*)/								# <=
						value = str_to_column_type(grid_records, $1, col)
						grid_records = grid_records.find_all {|r| r[col] <= value} if value

					when /^<(.*)/								# <
						value = str_to_column_type(grid_records, $1, col)
						grid_records = grid_records.find_all {|r| r[col] < value} if value

					when /(.+)\.\.(.+)/	
						min = str_to_column_type(grid_records, $1, col)
						max = str_to_column_type(grid_records, $1, col)
						if min && max
							grid_records = grid_records.find_all do |r|
								value = r[col]
								value >= min && value < max
							end
						end
					else
						# Attribute with no match criteria so look for contains
						re = Regexp.new(param, Regexp::IGNORECASE)
						grid_records = grid_records.find_all {|r| r[col].to_s =~ re}
				end
			end
			
			# Sort the results (this will be done on :id if non provided so as to stay consistent with the AR path)
			grid_records.sort! {|a, b| a[sort_index] <=> b[sort_index]} if sort_index != :id
			grid_records
		end

		grid_records = grid_records.reverse if sort_direction != 'asc'

		# Get the range of records to show.
		if grid_records.length > rows_per_page
			start = current_page * rows_per_page
			start = grid_records.length - rows_per_page if start + rows_per_page > grid_records.length 
		else
			start = 0
		end
		
		return grid_records[start, rows_per_page], grid_records.length
	end
	
	def filter_on_params (model_class, grid_columns)
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
		grid_columns.each do |c|
			param = params[c]
			if param
				if model_class.columns_hash[c.to_s]
					if special_match_condition?(param)
						special_attribute_params[c] = param
					else
						regular_attribute_params[c] = param
					end
				else
					special_attribute_params[c] = param
				end
			end
		end
		
		sort_on_virtual_attribute = !model_class.columns_hash[sort_index.to_s] ? sort_index : false

		if !sort_on_virtual_attribute && special_attribute_params.empty?
			# Get rid of any caching.
			ar_options[:conditions] = filter_by_conditions(regular_attribute_params) if params[:_search] == "true"
			ar_options[:page] = current_page
			ar_options[:per_page] = rows_per_page

			grid_records = model_class.paginate(ar_options)
			total_entries = grid_records.total_entries
		else
			grid_records, total_entries = special_filter(model_class, grid_columns, regular_attribute_params, special_attribute_params, 
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

	# records may be an array of active records or an array of hashes (one entry per column)
	def jqgrid_json (records, grid_columns, current_page, per_page, total)
		json = %Q^{"page": "#{current_page}","total": #{total/per_page.to_i + 1}, "records": "#{total}"^
		if total > 0
			rows = records.map do |record|
				record[:id] ||= records.index(record)
				columns = grid_columns.map do |column|
					value = record[column] || get_column_value(record, column)
					value = escape_json(value) if value && value.kind_of?(String)
					%Q^"#{value}"^
				end
				%Q^{"id": "#{record[:id]}", "cell": [#{columns.join(',')}]}^
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
end

class ActionController::Base
	include JqgridFilter
end