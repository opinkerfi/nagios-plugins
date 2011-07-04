##
## Process this file with automake to produce Makefile.in
##

AUTOMAKE_OPTIONS = 1.3 no-dependencies

#all:	tests

TEST_VERBOSE=0
TEST_TYPE=test_$(LINKTYPE)
TEST_FILE = test.pl
TEST_FILES = *.t
TESTDB_SW = -d

#EXTRA_DIST = *.t bin var etc
EXTRA_DIST = *.t

tests:
	$(PERL) "-MExtUtils::Command::MM" "-e" "test_harness($(TEST_VERBOSE))" $(TEST_FILES)
#	PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-MExtUtils::Command::MM" "-e" "test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')" $(TEST_FILES)

