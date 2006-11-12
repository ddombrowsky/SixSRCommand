class TrackController < ApplicationController

# screw the worthless scaffolding crap
#	scaffold :track

	def list
		@startrow = 0;

		if @params["startrow"]!=nil
			@startrow=@params["startrow"];
		end
		@tracks = Track.get_set(@startrow);

		#the list.rhtml file will not be parsed if this renderes text ???
		#render_text @startrow;
	end


	def commitchanges 

		# DOES NOTHING
		#t = Track.find(10);
		#t["is_active"] = 1;

		# calls is_active= method in Track, totall useless
		#updates = { 10 => {"is_active",1}, 11=>{"is_active",1}};
		#Track.update(updates.keys, updates.values);
		
		# calls is_active=, USELESS
		#@t = Track.find(10);
		#@t.is_active = 1;
		#@t.save;

		#@t = Track.find(10);
		#@t.artist="YYYYYYYYYYYYXXXX";
		#@t.save;
		#render_text @t.track_id.to_s;
		
		# now this works.  problem was the Track class wasn't pointing
		# to the correct database table
		#@t = Track.find(10);
		#@t.is_active=1;
		#@t.save();

		@params.each do |e|
			if(e[0].to_i > 0) 
				puts "updating record: #{e[0]} = #{e[1]}";
				t = Track.find(e[0].to_i);
				t.is_active=e[1].to_i;
				t.save();
			end
		end

		@sr = @params["startrow"];
		puts "current startrow = #@sr";
		redirect_to :action => "list", :params => {"startrow" => @sr};
	end
end

