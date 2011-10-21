CC=/usr/gcc/bin/gcc

#INC=-I/usr/local/include/subversion-1 `apr-1-config --includes`
#LIBS=-L/usr/local/lib -lsvn_repos-1 -lsvn_fs-1 -lsvn_subr-1 `apr-1-config  --link-ld --libs`
INC=-I/usr/local/include/subversion-1 `/usr/local/apr/bin/apr-config --includes`
LIBS=-L/usr/local/lib -R/usr/local/lib -R/usr/local/apr/lib -lsvn_repos-1 -lsvn_fs-1 -lsvn_subr-1 `/usr/local/apr/bin/apr-config --link-ld --libs`

all:
	$(CC) $(INC) -o svntxnprop main.c $(LIBS)

clean:
	rm -f svntxnprop *.o 
