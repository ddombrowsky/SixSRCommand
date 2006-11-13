ActionController::Routing::Routes.draw do |map|
  map.connect ':controller/commitchanges', :action => 'commitchanges'

  map.connect ':controller/search', :action => 'search'

  map.connect ':controller/list', :action => 'list'

  map.connect ':controller', :action => 'list'


#  map.connect ':controller/service.wsdl', :action => 'wsdl'
end
