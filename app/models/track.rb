class Track < ActiveRecord::Base

	def Track.get_set(startrow)
		@r = Track.find_by_sql "select * from tracks limit #{startrow},20";
		return @r;
	end
end
