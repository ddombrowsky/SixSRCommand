class TrackController < ApplicationController
	scaffold :track

	def list
		@startrow = 0;

		if @params["startrow"]!=nil
			@startrow=@params["startrow"];
		end
		@tracks = Track.get_set(@startrow);

		#the list.rhtml file will not be parsed if this renderes text ???
		#render_text @startrow;
		
		#@tracks = ["get","out"];
	end

	def edit
	end
end
