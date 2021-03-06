#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"
cd ..

mkdir -p docs/api
node node_modules/ts-node/dist/bin.js tools/docublox --output docs --libName "dash" --rootUrl "/rodash/" src docs_source
mkdocs build --clean
