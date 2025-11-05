#!/bin/bash

echo "Compiling compose2target"
dart compile exe ../bin/compose2target.dart -o ../bin/compose2target

#syft scan . -o cyclonedx@1.6 >localsbom.sbom
#grype --add-cpes-if-none --by-cve localsbom.sbom

if [ ! -d vnrtmp ]; then
    mkdir vnrtmp
else
    /bin/rm -rf vnrtmp/*
fi

mkdir vnrtmp/mapping vnrtmp/run vnrtmp/compose vnrtmp/quadlet vnrtmp/ha vnrtmp/helm vnrtmp/nopod

printf "fofofof" | podman secret create mariadb-chla-secret -

echo "Running compose2target for mapping only with mappingfile (no container)"
../bin/compose2target -i config_samples/envoy-custom.yaml       -t mapping  -m mapping/mappingFile.yaml       -o vnrtmp/mapping/envoy-custom.yaml

echo "Running compose2target with mappingfile but NOPOD"
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t run     --nopod  -m mapping/mappingFile.yaml       -o vnrtmp/nopod/mariadb_mapping_run.yaml
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t compose --nopod  -m mapping/mappingFile.yaml       -o vnrtmp/nopod/mariadb_compose.yaml
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t quadlet --nopod  -m mapping/mappingFile.yaml       -o vnrtmp/nopod/mariadb.container
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t ha      --nopod  -m mapping/mappingFile.yaml       -o vnrtmp/nopod/mariadb_mapping_ha.pcs        --user ansuser
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t compose -n mynetwork  -m mapping/mappingFile.yaml       -o vnrtmp/nopod/mariadb.compose

echo "Running compose2target with 'run' option with mappingfile"
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t run      -m mapping/mappingFile.yaml       -o vnrtmp/run/mariadb_mapping_run.yaml
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t run      -m mapping/mappingFile.yaml --dev -o vnrtmp/run/mariadb_mapping_rundev.yaml
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t run      -m mapping/mappingFile_Light.yaml -o vnrtmp/run/mariadb_mapping_run_light.yaml

echo "Running compose2target with 'run' option without mappingfile"
../bin/compose2target -i compose_samples/mariadb.yaml           -t run                                          -o vnrtmp/run/mariadb_run.yaml
../bin/compose2target -i compose_samples/mariadb.yaml           -t run                                    --dev -o vnrtmp/run/mariadb_rundev.yaml

echo "Running compose2target with 'compose' option with mappingfile"
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t compose  -m mapping/mappingFile.yaml         -o vnrtmp/compose/mariadb_compose.yaml
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t compose  -m mapping/mappingFile.yaml   --dev -o vnrtmp/compose/mariadb_compose_dev.yaml
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t compose  -m mapping/mappingFile_Light.yaml   -o vnrtmp/compose/mariadb_compose_light.yaml

echo "Running compose2target with 'quadlet' option with mappingfile"
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t quadlet  -m mapping/mappingFile.yaml         -o vnrtmp/quadlet/mariadb.container
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t quadlet  -m mapping/mappingFile_Light.yaml   -o vnrtmp/quadlet/mariadb_light.container

echo "Running compose2target with 'quadlet' option without mappingfile"
../bin/compose2target -i compose_samples/mariadb.yaml           -t quadlet                                      -o vnrtmp/quadlet/mariadb2.container

echo "Running compose2target with 'ha' option without mappingfile"
../bin/compose2target -i compose_samples/mariadb.yaml           -t ha                                           -o vnrtmp/ha/mariadb_ha.pcs             --user ansuser

echo "Running compose2target with 'ha' option with mappingfile"
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t ha       -m mapping/mappingFile.yaml         -o vnrtmp/ha/mariadb_mapping_ha.pcs        --user ansuser
../bin/compose2target -i compose_samples/mariadb_mapping.yaml   -t ha       -m mapping/mappingFile_Light.yaml   -o vnrtmp/ha/mariadb_mapping_light_ha.pcs  --user ansuser

echo "Running compose2target with 'ha' option without mappingfile"
../bin/compose2target -i compose_samples/jaeger.yaml            -t ha                                           -o vnrtmp/ha/jaeger_ha.pcs                 --user ansuser
../bin/compose2target -i compose_samples/jaeger_mapping.yaml    -t ha       -m mapping/mappingFile.yaml         -o vnrtmp/ha/jaegermapping_ha.pcs          --user ansuser

#mkdir vnrtmp/helm/mariadb
#cp vnrtmp/compose/mariadb_compose.yaml vnrtmp/helm/mariadb/docker-compose.yml
#cd vnrtmp/helm/mariadb
#katenary convert -o ./chart
#cd -
