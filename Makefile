tests: test4 test5 test6

test4:
	SIMPLE_SQL_ACTIVERECORD_SPECS="> 4,< 5" bundle
	rspec

test5:
	SIMPLE_SQL_ACTIVERECORD_SPECS="> 5,< 6" bundle update activerecord
	rspec

test6:
	SIMPLE_SQL_ACTIVERECORD_SPECS="> 6,< 7" bundle update activerecord
	rspec

stats:
	@scripts/stats lib/simple/sql
	@scripts/stats spec/simple/sql
	@scripts/stats lib/simple/store
	@scripts/stats spec/simple/store
