#!/bin/bash

echo "Compiling compose2target"
dart compile exe bin/compose2target.dart -o bin/compose2target

/bin/rm -rf vnrtmp/*

echo "Running compose2target with 'run' option"
./bin/compose2target -i compose_samples/mariadb.yaml  -t run -m mapping/mappingFile.yaml

echo "Running compose2target with 'run' option without mappingfile"
./bin/compose2target -i compose_samples/mariadb.yaml  -t run

echo "Running compose2target with 'compose' option"
./bin/compose2target -i compose_samples/mariadb.yaml  -t compose -m mapping/mappingFile.yaml -o vnrtmp/mariadb_compose.yaml

echo "Running compose2target with 'quadlet' option"
./bin/compose2target -i compose_samples/mariadb.yaml  -t quadlet -m mapping/mappingFile.yaml -o vnrtmp/mariadb.container

echo "Running compose2target with 'quadlet' option without mappingfile"
./bin/compose2target -i compose_samples/mariadb.yaml  -t quadlet -o vnrtmp/mariadb2.container
