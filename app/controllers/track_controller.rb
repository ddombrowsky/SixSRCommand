class TrackController < ApplicationController

# screw the worthless scaffolding crap
#    scaffold :track

    def list
        @startrow = 0;
        @listid = nil;

        if @params["listid"]!=nil
            @listid=@params["listid"];
        else
            if @listid == nil
                render :text => "invalid listid";
                return;
            end
        end

        if @params["startrow"]!=nil
            @startrow=@params["startrow"];
        end
        @tracks = Track.get_set(@startrow,@listid);

        if @tracks.length==0
            redirect_to :action => "list",:listid => @listid.to_s, :params => {"startrow" => 0};
        end

        #the list.rhtml file will not be parsed if this renderes text ???
        #render_text @startrow;
        #render :text => "Hello world from ruby";
    end


    def commitchanges

        @newset = [];
        @curset = [];

        @params.each do |e|
            if(e[0].to_i > 0)
                #puts "updating record: #{e[0]} = 1";
                idx = e[0].to_i;
                @newset[idx]=1;
                t = Track.find(idx);
                t.is_active=1;
                t.save();
            elsif(e[0] =~ /^cur_/)
                # parameter is a selected checkbox
                # parse out the id and add to list
                idx=/^cur_([0-9]+)/.match(e[0])[1].to_i;
                @curset.push(idx);
            elsif(e[0] =~ /^com_/)
                # parameter is a comment field
                idx=/^com_([0-9]+)/.match(e[0])[1].to_i;
                t = Track.find(idx);
                t.comments=e[1];
                t.save();
            end
        end

        # clear records that need to be cleared
        @curset.each do |e|
            if(not @newset[e])
                #puts "updating record: #{e} = 0";
                t = Track.find(e);
                t.is_active=0;
                t.save();
            end
        end

        @sr = @params["startrow"];

        #puts "current startrow = #@sr";
        redirect_to :action => "list", :listid => @params["listid"], :params => {"startrow" => @sr};
    end

    def search
        trackid = @params["trackid"];
        listid = @params["listid"];

        ldataid = nil;

        # if we're searching by trackid, find the first id with that track id.
        # all subsequent results (if the track appears more than one) are discarded.
        if not trackid
            # if there is no track to search for, find the currently playing track
            t=Track.find_by_sql("select id from list_data where is_playing=1 and list_id=#{listid}");
            if((t != nil) && (t.length>0))
                ldataid=t[0]["id"];
            else
                ldataid=0;
            end
        else
            t=Track.find_by_sql("select id from list_data where track_id=#{trackid} limit 1");
            if((t == nil) || (t.length==0))
                render :text => "no results for #{trackid}";
                return
            end
            ldataid=t[0]["id"];
        end

        # to get the current window of rows that the searching track resides in,
        # we simply count the number of rows previous, and integer devide by
        # the window size
        t=Track.find_by_sql("
            select count(*) as c from list_data where ordering <
            (select ordering from list_data where id=#{ldataid})
            and list_id=#{listid}
        ");
        rnum=t[0]["c"].to_i;
        window=(rnum/20)*20;
        #puts "search found: window:#{window} rnum:#{rnum}";

        redirect_to :action => "list", :listid => listid.to_s, :params => {"startrow" => window};
    end

    def insert
        startrow=@params["startrow"];
        newtrackid=@params["trackid"];
        prevlistid=@params["prevlistid"];
        listid=@params["listid"];

        newtracks = newtrackid.split(/,/);

        # this iterates through each new track and inserts
        # it.  This could probably be put into some sql structure
        # to make it faster.
        newtracks.each do |ntrack|
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
                order by ordering
            ");

            neworder = curorder + 1;

            # check the case where the insert is on
            # the end of the list.  if so, then no
            # reordering is needed.
            if(t.length>0)
                nextorder = t[0].ordering;

                # make sure there is space
                if((nextorder - curorder <= 1) || (neworder >= nextorder))
                    #puts "reordering...";
                    # no space, must recalculate ordering
                    # must process list from bottom up to avoid
                    # key conflicts
                    ix=t.length-1;
                    while ix>=0 do
                        e=t[ix];
                        e.ordering += 5;
                        e.save();
                        ix=ix-1;
                    end
                    nextorder = t[0].ordering;
                    neworder = curorder + 1;
                end
            end

            #puts "good: cur:#{curorder} next:#{nextorder} new:#{neworder}";

            n=Track.new();
            n.track_id = ntrack;;
            n.ordering=neworder;
            n.list_id = listid;
            n.is_active=1;
            n.save();

            #puts "new list_data id: " + n.id.to_s;
            prevlistid=n.id;
        end

        redirect_to :action => "list", :listid => listid.to_s, :params => {"startrow" => startrow};
    end

    def edit
        listid=@params["listid"];
        @tracks=Track.find_all(listid);
    end
end

