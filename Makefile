SHELL := /bin/bash

#Common prefixes

prefix = /usr
datarootdir = $(prefix)/share
docdir = $(datarootdir)/cppreference/doc/en
bookdir = $(datarootdir)/devhelp/books/cppreference-doc-en

#Version

VERSION=20120330

#STANDARD RULES

all: doc_devhelp doc_qch

DISTFILES=	\
		reference				\
		images					\
		devhelp2qch.xsl			\
		fix_devhelp-links.sh	\
		fix_devhelp-links.xsl	\
		fix_html.sh				\
		fix_html-cleanup.xsl	\
		fix_html-css.css		\
		fix_html-httrack_meta.sed	\
		index2browser.xsl		\
		index2devhelp.xsl		\
		index2search.xsl		\
		index2highlight.xsl		\
		index_transform.xsl		\
		index-chapters.xml		\
		index-functions.README	\
		index-functions-cpp.xml	\
		Makefile				\
		README

CLEANFILES= \
		output								\
		images/output						\
		cppreference-doc-en.devhelp2		\
		cppreference-doc-en.qch				\
		qch-help-project.xml				\
		qch-files.xml						\
		devhelp-index.xml					\
		devhelp-files.xml

clean:
	rm -rf $(CLEANFILES)

check:

dist:
	mkdir -p "cppreference-doc-$(VERSION)"
	cp -r $(DISTFILES) "cppreference-doc-$(VERSION)"
	tar czf "cppreference-doc-$(VERSION).tar.gz" "cppreference-doc-$(VERSION)"
	rm -rf "cppreference-doc-$(VERSION)"

install:
	# install the devhelp documentation (skip the ttf files)
	pushd "output" > /dev/null; \
	find . -type f -not -iname "*.ttf" \
		-exec install -DT -m 644 '{}' "$(DESTDIR)$(docdir)/html/{}" \; ; \
	popd > /dev/null

	install -DT -m 644 cppreference-doc-en.devhelp2 "$(DESTDIR)$(bookdir)/cppreference-doc-en.devhelp2"

	# install the .qch (Qt Help) documentation
	install -DT -m 644 cppreference-doc-en.qch $(DESTDIR)$(docdir)/qch/cppreference-doc-en.qch

uninstall:
	rm -rf "$(DESTDIR)$(docdir)"
	rm -rf "$(DESTDIR)$(bookdir)"

#WORKER RULES

doc_devhelp: cppreference-doc-en.devhelp2

doc_qch: cppreference-doc-en.qch

#build the .devhelp2 index
cppreference-doc-en.devhelp2: output
	xsltproc --stringparam book-base $(docdir)/html \
		index2devhelp.xsl index-functions-cpp.xml > devhelp-index.xml

	#fix links in the .devhelp2 index
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><files>" > "devhelp-files.xml"
	pushd "output" > /dev/null;	\
	find . -iname "*.html" \
		-exec ../fix_devhelp-links.sh '{}' \; ; \
	popd > /dev/null

	echo "</files>" >> "devhelp-files.xml"

	xsltproc fix_devhelp-links.xsl devhelp-index.xml > cppreference-doc-en.devhelp2

#build the .qch (QT help) file
cppreference-doc-en.qch: qch-help-project.xml
	#qhelpgenerator only works if the project file is in the same directory as the documentation
	cp qch-help-project.xml output/qch.xml

	pushd "output" > /dev/null; \
	qhelpgenerator qch.xml -o "../cppreference-doc-en.qch"; \
	popd > /dev/null

	rm -f output/qch.xml

qch-help-project.xml: cppreference-doc-en.devhelp2
	#build the file list
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><files>" > "qch-files.xml"

	pushd "output" > /dev/null; \
	find . -type f -not -iname "*.ttf" \
		-exec echo "<file>"'{}'"</file>" >> "../qch-files.xml" \; ; \
	popd > /dev/null

	echo "</files>" >> "qch-files.xml"

	#create the project (copies the file list)
	xsltproc devhelp2qch.xsl cppreference-doc-en.devhelp2 > "qch-help-project.xml"

#create preprocessed archive
output:
	./preprocess.py

#redownloads the source documentation directly from en.cppreference.com
source:
	rm -rf "reference"
	mkdir "reference"

	pushd "reference" > /dev/null; \
	httrack http://en.cppreference.com/w/ -%k -%s -n -%q0 \
	  -* +en.cppreference.com/* +upload.cppreference.com/* -*index.php\?* \
	  -*/Special:* -*/Talk:* -*/Help:* -*/File:* -*/Cppreference:* -*/WhatLinksHere:* \
	  -*/Template:* -*/Category:* -*action=* -*printable=* \
	  +*MediaWiki:Common.css* +*MediaWiki:Print.css* +*MediaWiki:Vector.css* \
	  +*title=-&action=raw* --timeout=30 --retries=3 ;\
	popd > /dev/null

	#httrack apparently continues as a background process in non-interactive shells.
	#Wait for it to complete
	while [[ ! -e "reference/hts-in_progress.lock" ]] ; do sleep 1; done
	while [[ -e "reference/hts-in_progress.lock" ]] ; do sleep 3; done

	#delete useless files
	rm -rf "reference/hts-cache"
	rm -f "reference/backblue.gif"
	rm -f "reference/fade.gif"
	rm -f "reference/hts-log.txt"
	rm -f "reference/index.html"

