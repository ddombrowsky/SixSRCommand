class TrackController < ApplicationController

# screw the worthless scaffolding crap
#	scaffold :track

	def list
		@startrow = 0;
		@listid = 1;

		if @params["startrow"]!=nil
			@startrow=@params["startrow"];
		end
		@tracks = Track.get_set(@startrow,@listid);

		if @tracks.length==0
			redirect_to :action => "list", :params => {"startrow" => 0};
		end

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

		@newset = [];
		@curset = [];

		@params.each do |e|
			if(e[0].to_i > 0) 
				puts "updating record: #{e[0]} = 1";
				idx = e[0].to_i;
				@newset[idx]=1;
				t = Track.find(idx);
				t.is_active=1;
				t.save();
			elsif(e[0] =~ /^cur_/)
				# parse out the id and add to list
				idx=/^cur_([0-9]+)/.match(e[0])[1].to_i;
				@curset.push(idx);
			end
		end

		# clear records that need to be cleared
		@curset.each do |e|
			if(not @newset[e])
				puts "updating record: #{e} = 0";
				t = Track.find(e);
				t.is_active=0;
				t.save();
			end
		end

		@sr = @params["startrow"];
		puts "current startrow = #@sr";
		redirect_to :action => "list", :params => {"startrow" => @sr};
	end

	def search
		trackid = @params["trackid"];
		listid = 1;

		# if there is no track to search for, find the currently playing track
		if not trackid
			t=Track.find_by_sql("select track_id from list_data where is_playing=1");
			trackid=t[0]["track_id"];
		end

		# to get the current window of rows that the searching track resides in,
		# we simply count the number of rows previous, and integer devide by 
		# the window size
		t=Track.find_by_sql("
			select count(*) as c from list_data where ordering <
			(select ordering from list_data where track_id=#{trackid})
			and list_id=#{listid}
		");
		rnum=t[0]["c"].to_i;
		window=(rnum/20)*20;
		puts "search found: window:#{window} rnum:#{rnum}";

		redirect_to :action => "list", :params => {"startrow" => window};
	end

	def insert
		startrow=@params["startrow"];
		newtrackid=@params["trackid"];
		prevlistid=@params["prevlistid"];
		listid=1;

		# first, make sure we have room in our ordering
		t=Track.find_by_sql("
			select ordering from list_data
			where list_id=#{listid}
			and id=#{prevlistid}
		");
		curorder = t[0].ordering;

		t=Track.find_by_sql("
			select id, ordering from list_data 
			where list_id=#{listid}
			and ordering > #{curorder}
		");

		neworder = curorder + 1;
		nextorder = t[0].ordering;

		# make sure there is space
		if(nextorder - curorder <= 1)
			puts "reordering...";
			# no space, must recalculate ordering
			t.each do |e|
				e.ordering += 5;
				e.save();
			end
			nextorder = t[0].ordering;
			neworder = curorder + 1;
		end

		puts "good: cur:#{curorder} next:#{nextorder} new:#{neworder}";

		n=Track.new();
		n.track_id = newtrackid;
		n.ordering=neworder;
		n.list_id = listid;
		n.is_active=1;
		n.save();

		puts "new list_data id: " + n.id.to_s;

		redirect_to :action => "list", :params => {"startrow" => startrow};
	end
end

