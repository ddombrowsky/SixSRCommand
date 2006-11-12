class Track < ActiveRecord::Base
	set_table_name("list_data");
	set_primary_key("id");

	def Track.get_set(startrow)
		@r = Track.find_by_sql "
			select * 
			from list_data
			left join tracks using (track_id)
			where list_id=1
			limit #{startrow},20
		";
		return @r;
	end

	#attr_accessor :is_active;
end
