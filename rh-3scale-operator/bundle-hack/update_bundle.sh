#!/usr/bin/env bash

# enables strict mode: `-e` fails if error, `-u` checks variable references, `-o pipefail`: prevents errors in a pipeline from being masked
set -euo pipefail

export BACKEND_IMAGE_PULLSPEC="registry.redhat.io/3scale-amp2/backend-rhel8@sha256:e88fb30089d2e69b194dd51c5b9cadbed9e13465e14200751ee2a807a87c357b"
export APICAST_IMAGE_PULLSPEC="registry.redhat.io/3scale-amp2/apicast-gateway-rhel8@sha256:f31522d545ad43e8940b879d2907fefc4339b2fd9768cbcf551ad07e3ec458c5"
export SYSTEM_IMAGE_PULLSPEC="registry.redhat.io/3scale-amp2/system-rhel8@sha256:d08d7d6c98d1b922c50aa9dbb3ee636a41abb989c00e4d39eaf4b85c168cf034"
export ZYNC_IMAGE_PULLSPEC="registry.redhat.io/3scale-amp2/zync-rhel9@sha256:3516bfa7ad3dfb7a65879c641b01d18914ea0e17d1d4be0c32453834164cd999"
export SEARCHD_IMAGE_PULLSPEC="registry.redhat.io/3scale-amp2/manticore-rhel9@sha256:4c4f01055806af561276e4c7e25ab8933ba513f3e1bda53b832ea739bd283aca"
export OPERATOR_IMAGE_PULLSPEC="registry.redhat.io/3scale-amp2/3scale-rhel9-operator@sha256:da9ea49bfaba3d2cb3bf17e7db3ca9b1ba6d136c884cf64889fd302ff7250280"

# non-3scale dependencies
#TODO: automate updates of these with renovate
# renovate: datasource=docker versioning=docker
export MEMCACHED_IMAGE_PULLSPEC="registry.redhat.io/rhel9/memcached@sha256:63fde5fa8eec0d05e182c1ee52287a20846f5dddbdcfe2a6cd308860adb3984a"
# renovate: datasource=docker versioning=docker
export REDIS_IMAGE_PULLSPEC="registry.redhat.io/rhel9/redis-7@sha256:0e4e70917476b9b669c46524f409be360296d9dfbd11ee072b203d72d6b3f60e"
# renovate: datasource=docker versioning=docker
export MYSQL_IMAGE_PULLSPEC="registry.redhat.io/rhel8/mysql-80@sha256:f6a3025d463b7763ef78ed6cce8f3f053a661a8a506e67839c98e7d9882bdf21"
# renovate: datasource=docker versioning=docker
export POSTGRESQL_IMAGE_PULLSPEC="registry.redhat.io/rhel8/postgresql-13@sha256:db319b7e1dc1d0c4ba52765b9cc558d6e799159829de4856f48d0d47dfd37f40"
# renovate: datasource=docker versioning=docker
export OC_CLI_IMAGE_PULLSPEC="registry.redhat.io/openshift4/ose-cli@sha256:d2323a0294225b275d7d221da41d653c098185290ecafb723494e2833316493c"

export CSV_FILE=/manifests/3scale-operator.clusterserviceversion.yaml

sed -i -e "s|quay.io/3scale/3scale-operator:latest|\"${OPERATOR_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/3scale-operator:master|\"${OPERATOR_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/apisonator:latest|\"${BACKEND_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/apicast:latest|\"${APICAST_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/porta:latest|\"${SYSTEM_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/zync:latest|\"${ZYNC_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/3scale/searchd:latest|\"${SEARCHD_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/fedora/redis-7|\"${REDIS_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/sclorg/mysql-80-c8s|\"${MYSQL_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/sclorg/postgresql-13-c8s|\"${POSTGRESQL_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|quay.io/openshift/origin-cli:4.7|\"${OC_CLI_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"
sed -i -e "s|mirror.gcr.io/library/memcached:.*|\"${MEMCACHED_IMAGE_PULLSPEC}\"|g" "${CSV_FILE}"

export AMD64_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="amd64")')
export ARM64_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="arm64")')
export PPC64LE_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="ppc64le")')
export S390X_BUILT=$(skopeo inspect --raw docker://${OPERATOR_IMAGE_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="s390x")')

export EPOC_TIMESTAMP=$(date +%s)
# time for some direct modifications to the csv
python3 - << CSV_UPDATE
import os
from collections import OrderedDict
from sys import exit as sys_exit
from datetime import datetime
from ruamel.yaml import YAML
yaml = YAML()
def load_manifest(pathn):
   if not pathn.endswith(".yaml"):
      return None
   try:
      with open(pathn, "r") as f:
         return yaml.load(f)
   except FileNotFoundError:
      print("File can not found")
      exit(2)

def dump_manifest(pathn, manifest):
   with open(pathn, "w") as f:
      yaml.dump(manifest, f)
   return
timestamp = int(os.getenv('EPOC_TIMESTAMP'))
datetime_time = datetime.fromtimestamp(timestamp)
csv_manifest = load_manifest(os.getenv('CSV_FILE'))
# Add arch and os support labels
csv_manifest['metadata']['labels'] = csv_manifest['metadata'].get('labels', {})
if os.getenv('AMD64_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.amd64'] = 'supported'
if os.getenv('ARM64_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.arm64'] = 'supported'
if os.getenv('PPC64LE_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.ppc64le'] = 'supported'
if os.getenv('S390X_BUILT'):
	csv_manifest['metadata']['labels']['operatorframework.io/arch.s390x'] = 'supported'
csv_manifest['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
csv_manifest['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
csv_manifest['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'true'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
csv_manifest['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
# Ensure that other annotations are accurate
csv_manifest['metadata']['annotations']['repository'] = 'https://github.com/3scale/3scale-operator'
csv_manifest['metadata']['annotations']['containerImage'] = os.getenv('OPERATOR_IMAGE_PULLSPEC', '')

__dir = os.path.dirname(os.path.abspath(__file__))

# Ensure that any parameters are properly defined in the spec if you do not want to
# put them in the CSV itself
with open(f"{__dir}/DESCRIPTION", "r") as desc_file:
    description = desc_file.read()

with open(f"{__dir}/ICON", "r") as icon_file:
    icon_data = icon_file.read()

csv_manifest['spec']['description'] = description
csv_manifest['spec']['icon'][0]['base64data'] = icon_data


# Make sure that our latest nudged references are properly configured in the spec.relatedImages
# NOTE: the names should be unique
csv_manifest['spec']['relatedImages'] = [
   {'name': '3scale-operator', 'image': os.getenv('OPERATOR_IMAGE_PULLSPEC')}
]

dump_manifest(os.getenv('CSV_FILE'), csv_manifest)
CSV_UPDATE

cat $CSV_FILE