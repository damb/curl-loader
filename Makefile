# This is <Makefile>
# -----------------------------------------------------------------------------
#
#  Usage:
#  ------
#
#  To build and install invoke:
#
#  	$ make [OPTIONS]
#
#  Available OPTIONS:
#
#  DEBUG={1,0}		Compile with -g . (default: 1)
#
#  OPTIMIZE={1,0} Compile with optimizations. (default: 1)
#
#  PROFILE={1,0}	Compile for profiling. (default: 0)
#  
# -----------------------------------------------------------------------------
#
# REVISION AND CHANGES
# 2018/10/03        V0.1    Daniel Armbruster (based on the original version
# 													from curl-loader)
# =============================================================================
#
# make OPTIONS
DEBUG ?= 1
OPTIMIZE ?= 1
PROFILE ?= 0

# ----------------------------------------------------------------------------
BINDIR:=./bin
BUILDDIR:=./build
EXTDIR:=./ext
LIBDIR:=./lib
INCLUDEDIR:=./include
PATCHDIR:=./patches
DOCDIR:=/usr/share/doc/curl-loader/
SRCDIR=./src

# manual page directory
MANDIR=/usr/share/man

TARGET=$(BINDIR)/curl-loader
TAGFILE = .tags

LIBCARES:=$(LIBDIR)/libcares.a
LIBCURL:=$(LIBDIR)/libcurl.a
LIBEVENT:=$(LIBDIR)/libevent.a


.PHONY: all
all: $(TARGET)

.PHONY: libs
libs: $(LIBEVENT) $(LIBCURL)

.PHONY: tags
tags: $(TAGFILE)

# ----------------------------------------------------------------------------
CC=gcc
CFLAGS= -W -Wall -Wpointer-arith -pipe \
	-DCURL_LOADER_FD_SETSIZE=20000 \
	-D_FILE_OFFSET_BITS=64

DEBUG_FLAGS=
PROFILE_FLAGS=
# CPU-tuning flags for Pentium-4 arch as an example.
#
# OPTIMIZE_FLAGS=-mtune=pentium4 -mcpu=pentium4

# CPU-tuning flags for Intel core-2 arch as an example. 
# Note, that it is supported only by gcc-4.3 and higher
# OPTIMIZE_FLAGS+=-mtune=core2 -march=core2
OPTIMIZE_FLAGS=


mkdirs:
	mkdir -pv $(INCLUDEDIR) $(LIBDIR) $(BUILDDIR) $(BINDIR) 

clean:
	rm -rvf $(SRCDIR)/*.o
	rm -rvf $(TARGET)
	rm -rvf $(TAGFILE)

cleanall: clean
	rm -rvf $(BUILDDIR) $(INCLUDEDIR) $(LIBDIR) $(BINDIR)

$(TAGFILE):
	ctags -o $@ $(addprefix $(SRCDIR)/, *.h *.c)

#install:
#	mkdir -p $(DESTDIR)/usr/bin 
#	mkdir -p $(DESTDIR)$(MANDIR)/man1
#	mkdir -p $(DESTDIR)$(MANDIR)/man5
#	mkdir -p $(DESTDIR)$(DOCDIR)
#	cp -f curl-loader $(DESTDIR)/usr/bin
#	cp -f doc/curl-loader.1 $(DESTDIR)$(MANDIR)/man1/  
#	cp -f doc/curl-loader-config.5 $(DESTDIR)$(MANDIR)/man5/
#	cp -f doc/* $(DESTDIR)$(DOCDIR) 
#	cp -rf config/examples $(DESTDIR)$(DOCDIR)

.PHONY: clean cleanall mkdirs

# ----------------------------------------------------------------------------
ifeq ($(DEBUG),1)
DEBUG_FLAGS+= -g
else
ifeq ($(PROFILE),0)
OPTIMIZE_FLAGS+= -fomit-frame-pointer
endif
endif

ifeq ($(OPTIMIZE),1)
OPTIMIZE_FLAGS+= -O3 -ffast-math -finline-functions -funroll-all-loops \
	-finline-limit=1000 -mmmx -msse -foptimize-sibling-calls
else
OPTIMIZE_FLAGS= -O0
endif

ifeq ($(PROFILE),1)
PROFILE_FLAGS+= -pg
endif

# ----------------------------------------------------------------------------
OBJECTS:=$(patsubst %.c, %.o, $(wildcard $(SRCDIR)/*.c))

# NOTE: If required, add -lidn and/or -lldap
$(TARGET): $(OBJECTS)  
	$(CC) -o $@ $(OBJECTS) -I $(INCLUDEDIR) -lcurl -levent -lz -lssl \
		-lcrypto -lcares -ldl -lpthread -lnsl -lrt -lresolv \
		$(PROFILE_FLAGS) $(DEBUG_FLAGS) $(OPTIMIZE_FLAGS) \
		-L $(LIBDIR) 

%.o: %.c $(LIBEVENT) $(LIBCURL)
	$(CC) $(CFLAGS) $(PROFILE_FLAGS) $(DEBUG_FLAGS) $(OPTIMIZE_FLAGS) \
		-c -o $@ -I $(INCLUDEDIR) $(word 1,$^)

# ----------------------------------------------------------------------------
# 3rd party dependencies
#
BUILDDIR_LIBCARES:=$(shell realpath -m $(BUILDDIR)/libcares)
VERSION_CARES:=1.7.5
MAKEDIR_LIBCARES=$(BUILDDIR_LIBCARES)/c-ares-$(VERSION_CARES)

$(LIBCARES): $(EXTDIR)/c-ares-$(VERSION_CARES).tar.gz 
	$(MAKE) mkdirs
	mkdir -pv $(BUILDDIR_LIBCARES)
	tar xvzf $< -C $(BUILDDIR_LIBCARES)
	cd $(MAKEDIR_LIBCARES); \
		./configure --prefix $(BUILDDIR_LIBCARES) \
		CFLAGS="$(PROFILE_FLAGS) $(DEBUG_FLAGS) $(OPTIMIZE_FLAGS)"
	make -C $(MAKEDIR_LIBCARES); make -C $(MAKEDIR_LIBCARES) install
	cp -pf $(BUILDDIR_LIBCARES)/include/*.h $(INCLUDEDIR)
	cp -pf $(BUILDDIR_LIBCARES)/lib/libcares.*a $(LIBDIR)


# ----
BUILDDIR_LIBEVENT:=$(shell realpath -m $(BUILDDIR)/libevent)
VERSION_LIBEVENT:=1.4.14b
MAKEDIR_LIBEVENT=$(BUILDDIR_LIBEVENT)/libevent-$(VERSION_LIBEVENT)-stable

$(LIBEVENT): $(EXTDIR)/libevent-$(VERSION_LIBEVENT)-stable.tar.gz 
	$(MAKE) mkdirs
	mkdir -pv $(BUILDDIR_LIBEVENT)
	tar xvzf $< -C $(BUILDDIR_LIBEVENT)
	cd $(MAKEDIR_LIBEVENT); \
		patch -p1 < ../../../$(PATCHDIR)/libevent-nevent.patch; \
		./configure --prefix $(BUILDDIR_LIBEVENT) \
		CFLAGS="$(PROFILE_FLAGS) $(DEBUG_FLAGS) $(OPTIMIZE_FLAGS)"
	make -C $(MAKEDIR_LIBEVENT); make -C $(MAKEDIR_LIBEVENT) install
	cp -pf $(BUILDDIR_LIBEVENT)/include/*.h $(INCLUDEDIR)
	cp -pf $(BUILDDIR_LIBEVENT)/lib/libevent.a $(LIBDIR)

# ----
# NOTE: To enable IPv6 change --disable-ipv6 to --enable-ipv6
BUILDDIR_LIBCURL:=$(shell realpath -m $(BUILDDIR)/curl)
VERSION_CURL:=7.61.1
MAKEDIR_CURL=$(BUILDDIR_LIBCURL)/curl-$(VERSION_CURL)

$(LIBCURL): $(EXTDIR)/curl-$(VERSION_CURL).tar.bz2 $(LIBCARES)
	$(MAKE) mkdirs
	mkdir -pv $(BUILDDIR_LIBCURL)
	tar xvjf $(word 1,$^) -C $(BUILDDIR_LIBCURL)
	cd $(MAKEDIR_CURL); \
		patch -p1 < ../../../$(PATCHDIR)/curl-trace-info-error.patch; \
		./configure --prefix=$(BUILDDIR_LIBCURL) \
				--without-libidn \
				--without-libssh2 \
				--disable-ldap \
				--disable-ipv6 \
				--enable-thread \
				--with-random=/dev/urandom \
				--with-ssl \
				--enable-shared=no \
				--enable-ares=$(BUILDDIR_LIBCARES) \
				CFLAGS="$(PROFILE_FLAGS) $(DEBUG_FLAGS) $(OPTIMIZE_FLAGS) -DCURL_MAX_WRITE_SIZE=4096"
	make -C $(MAKEDIR_CURL) && \
		make -C $(MAKEDIR_CURL)/lib install && \
		make -C $(MAKEDIR_CURL)/include/curl install 
	cp -a $(BUILDDIR_LIBCURL)/include/curl ./$(INCLUDEDIR)/curl
	cp -pf $(BUILDDIR_LIBCURL)/lib/libcurl.*a ./$(LIBDIR)

# ---- END OF <Makefile> ----
