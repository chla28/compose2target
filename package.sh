#!/bin/bash
VERSION=$1
[[ -z ${VERSION} ]] && echo "ERROR: A version is mandatory (e.g. 0.1)." && exit 1
! [[ "$(makeself.sh --version)" =~ ^Makeself.*$ ]] && echo "ERROR: Makeself is not installed (install it then set it to PATH)." && exit 1

TMPROOTFOLDER=$(mktemp -d)
BUILDFOLDER="${TMPROOTFOLDER}/compose2target-${VERSION}"
mkdir -p ${BUILDFOLDER}
DESTFILE="Compose2Target-${VERSION}.sh"

cp bin/compose2target               ${BUILDFOLDER}
cp LICENSE                          ${BUILDFOLDER}
cp README.md                        ${BUILDFOLDER}
cp CHANGELOG.md                     ${BUILDFOLDER}
cp resource-agent/podman-rootless   ${BUILDFOLDER}
if [ -f localsbom.sbom ]; then cp localsbom.sbom ${BUILDFOLDER}; fi

cd ${TMPROOTFOLDER}
makeself.sh --notemp . "${DESTFILE}" "Compose2Target ${VERSION} Autoextractible part for Compose2Target tool"
cp "${DESTFILE}" ~

cd -
/bin/rm -rf ${TMPROOTFOLDER}
