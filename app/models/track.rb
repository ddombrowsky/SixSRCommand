class Track < ActiveRecord::Base
	set_table_name("list_data");
	set_primary_key("id");

	def Track.get_set(startrow,listid)
		@r = Track.find_by_sql "
			select * 
			from list_data
			left join tracks using (track_id)
			where list_id=#{listid}
			order by ordering
			limit #{startrow},20
		";

		return @r;
	end

	def Track.find_all(listid)
		return Track.find_by_sql("
			select * 
			from list_data
			left join tracks using (track_id)
			where list_id=#{listid}
			order by ordering
		");
	end

	#attr_accessor :is_active;
end
