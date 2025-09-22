#!make
# RTK Makefile - Modernized for cross-platform compilation
############################################################

# Detect system architecture and OS
ARCH := $(shell uname -m)
OS := $(shell uname -s)

# Compiler settings
CC = gcc -pipe -w
MAKE = make -s

# Architecture-specific optimizations
ifeq ($(ARCH),x86_64)
    ARCH_FLAGS = -m64
else ifeq ($(ARCH),aarch64)
    ARCH_FLAGS = -march=armv8-a
else ifeq ($(ARCH),arm64)
    ARCH_FLAGS = -march=armv8-a
else
    ARCH_FLAGS =
endif

# Use pkg-config for library detection with fallbacks
MYSQL_EXISTS := $(shell pkg-config --exists libmariadb && echo yes || echo no)
LUA_EXISTS := $(shell pkg-config --exists lua5.1 && echo yes || echo no)

ifeq ($(MYSQL_EXISTS),yes)
    MYSQL_CFLAGS := $(shell pkg-config --cflags libmariadb)
    MYSQL_LIBS := $(shell pkg-config --libs libmariadb)
else
    # Fallback to legacy paths
    MYSQL_CFLAGS := -I/usr/include/mysql -I/usr/local/mysql/include
    MYSQL_LIBS := -L/usr/local/mysql/lib -lmysqlclient
endif

ifeq ($(LUA_EXISTS),yes)
    LUA_CFLAGS := $(shell pkg-config --cflags lua5.1)
    LUA_LIBS := $(shell pkg-config --libs lua5.1)
else
    # Fallback to legacy paths
    LUA_CFLAGS := -I/usr/include/lua5.1
    LUA_LIBS := -llua5.1
endif

# Base compiler flags
BASE_CFLAGS = -O2 -DNDEBUG -Wall -Wno-sign-compare -DFD_SETSIZE=1024 -DNO_MEMMGR -DUSE_MYSQL -I../common
CFLAGS = $(BASE_CFLAGS) $(ARCH_FLAGS) $(MYSQL_CFLAGS) $(LUA_CFLAGS)
CLIBS = -lcrypt -lm -lz -ldl -lpthread $(MYSQL_LIBS) $(LUA_LIBS)

COMMON_OBJ = ../common/core.o ../common/socket.o ../common/timer.o ../common/crypt.o ../common/db.o ../common/malloc.o  ../common/db_mysql.o ../common/md5calc.o ../common/ers.o ../common/strlib.o ../common/showmsg.o ../common/rndm.o
COMMON_H = ../common/core.h ../common/socket.h ../common/timer.h ../common/crypt.h ../common/db.h ../common/mmo.h ../common/version.h ../common/malloc.h ../common/db_mysql.h ../common/md5calc.h ../common/ers.h ../common/cbasetypes.h ../common/strlib.h ../common/showmsg.h ../common/rndm.h

MKDEF = CC="$(CC)" CFLAGS="$(CFLAGS)" CLIBS="$(CLIBS)" COMMON_OBJ="$(COMMON_OBJ)" COMMON_H="$(COMMON_H)"
METADEF = CC="$(CC)" CFLAGS="$(CFLAGS)" CLIBS="$(CLIBS)" COMMON_OBJ="../common/db.o ../common/malloc.o ../common/db_mysql.o ../common/timer.o ../common/strlib.o ../common/showmsg.o ../common/ers.o ../common/md5calc.o" COMMON_H="../common/db.h ../common/malloc.h ../common/db_mysql.h ../common/timer.h ../common/md5calc.h"

all: title common login char map metan decrypt

title:
	@echo "Hyul [Make]"
	@echo "-----------"

common:
	@echo "Common:"
	@$(MAKE) $(MKDEF) -C src/common/

login: common
	@echo "Login Server:"
	@$(MAKE) $(MKDEF) -C src/login/ clean
	@$(MAKE) $(MKDEF) -C src/login/

char: common
	@echo "Char Server:"
	@$(MAKE) $(MKDEF) -C src/char/ clean
	@$(MAKE) $(MKDEF) -C src/char/

map: common
	@echo "Map Server:"
	@$(MAKE) $(MKDEF) -C src/map/ clean
	@$(MAKE) $(MKDEF) -C src/map/

metan: common
	@echo "Meta Creator:"
	@$(MAKE) $(METADEF) -C src/metan/ clean
	@$(MAKE) $(METADEF) -C src/metan/

#sqlclear: common
#	@echo "Sql Clear Tool:"
#	@$(MAKE) $(METADEF) -C src/sqlclear/ clean
#	@$(MAKE) $(METADEF) -C src/sqlclear/

decrypt: common
	@echo "Decrypt Packet Tool: "
	@$(MAKE) $(METADEF) -C src/decrypt/ clean
	@$(MAKE) $(METADEF) -C src/decrypt/



clean:
	@$(MAKE) $(MKDEF) $@ -C src/common/
	@$(MAKE) $(MKDEF) $@ -C src/login/
	@$(MAKE) $(MKDEF) $@ -C src/char/
	@$(MAKE) $(MKDEF) $@ -C src/map/
	@$(MAKE) $(MKDEF) $@ -C src/metan/
#	@$(MAKE) $(MKDEF) $@ -C src/sqlclear/
	@$(MAKE) $(MKDEF) $@ -C src/decrypt/
