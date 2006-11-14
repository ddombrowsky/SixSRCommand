ActionController::Routing::Routes.draw do |map|

  # this defines a "pretty url" field, which is parsed by the regular expression
  map.connect ':controller/:action/:listid', :listid => /[0-9]+/;

  # default action for this controller (usually track)
  # doesn't work because of base URL crap
  #map.connect ':controller', :action => 'list', :listid => '2';


#  map.connect ':controller/service.wsdl', :action => 'wsdl'
end
