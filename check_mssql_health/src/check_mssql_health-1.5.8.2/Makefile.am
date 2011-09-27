## Process this file with automake to produce Makefile.in

# find . \( -type d -and -name .svn -and -prune \) -or -type f -exec fromdos -v {} \;

SUBDIRS = plugins-scripts t
EXTRA_DIST = contrib

dist-hook:
	rm -f t/var/tmp/*
	rm -f t/var/adm/*
	find $(distdir) -depth -name .svn -exec rm -rf {} \;
	find $(distdir) -type f -exec fromdos -v {} \;
	make
