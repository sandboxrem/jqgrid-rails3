require '2dc_jqgrid'
require 'filter'
require 'edit'

Array.send :include, JqgridJson
ActionView::Base.send :include, Jqgrid
