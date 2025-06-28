#!/bin/bash

echo "Compiling compose2target"
dart compile exe bin/compose2target.dart -o bin/compose2target

#syft scan . -o cyclonedx@1.6 >localsbom.sbom
#grype --add-cpes-if-none --by-cve localsbom.sbom

/bin/rm -rf vnrtmp/*

#echo "Running compose2target with 'run' option with mappingfile"
#./bin/compose2target -i compose_samples/mariadb_mapping.yaml  -t run -m mapping/mappingFile.yaml

#echo "Running compose2target with 'run' option without mappingfile"
#./bin/compose2target -i compose_samples/mariadb.yaml  -t run

echo "Running compose2target with 'compose' option with mappingfile"
./bin/compose2target -i compose_samples/mariadb_mapping.yaml  -t compose -m mapping/mappingFile.yaml -o vnrtmp/mariadb_compose.yaml

echo "Running compose2target with 'quadlet' option with mappingfile"
./bin/compose2target -i compose_samples/mariadb_mapping.yaml  -t quadlet -m mapping/mappingFile.yaml -o vnrtmp/mariadb.container

#echo "Running compose2target with 'quadlet' option without mappingfile"
#./bin/compose2target -i compose_samples/mariadb.yaml  -t quadlet -o vnrtmp/mariadb2.container

#echo "Running compose2target with 'ha' option without mappingfile"
##./bin/compose2target -i compose_samples/mariadb.yaml  -t ha
#./bin/compose2target -i compose_samples/mariadb.yaml  -t ha --user ansuser -o vnrtmp/mariadb_ha.pcs

echo "Running compose2target with 'ha' option with mappingfile"
#./bin/compose2target -i compose_samples/mariadb_mapping.yaml  -t ha -m mapping/mappingFile.yaml
./bin/compose2target -i compose_samples/mariadb_mapping.yaml  -t ha --user ansuser -m mapping/mappingFile.yaml -o vnrtmp/mariadb_mapping_ha.pcs

#echo "Running compose2target with 'ha' option without mappingfile"
##./bin/compose2target -i compose_samples/jaeger.yaml  -t quadlet
#./bin/compose2target -i compose_samples/jaeger.yaml  -t ha --user ansuser
#./bin/compose2target -i compose_samples/jaeger_mapping.yaml -t ha --user ansuser -m mapping/mappingFile.yaml

#echo "Running compose2target for mapping only with mappingfile"
#./bin/compose2target -i config_samples/envoy-custom.yaml -t mapping -m mapping/mappingFile.yaml -o vnrtmp/envoy-custom.yaml
