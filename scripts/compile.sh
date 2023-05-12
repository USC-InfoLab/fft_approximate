gcc -c -fPIC -Wall -Werror -g3 -O0 -I$(pg_config --includedir-server) ../src/complex.c && gcc -shared -o complex.so complex.o && sudo cp complex.so $(pg_config --pkglibdir) &&

gcc -c -fPIC -Wall -Werror -g3 -O0 -I$(pg_config --includedir-server) ../src/avg.c && gcc -shared -o avg.so avg.o && sudo cp avg.so $(pg_config --pkglibdir)