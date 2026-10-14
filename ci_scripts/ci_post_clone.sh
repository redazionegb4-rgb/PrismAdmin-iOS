#!/bin/sh
set -eu
PRISM_ADMIN_ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
test -f "$PRISM_ADMIN_ROOT/PrismAdmin.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" || { echo 'Manca Package.resolved nel repository: aggiungi anche il workspace condiviso del progetto.'; exit 1; }
python3 - "$PRISM_ADMIN_ROOT/Config/App.xcconfig" <<'PY'
import os,re,sys
from pathlib import Path
p=Path(sys.argv[1]);s=p.read_text();build=os.environ.get('CI_BUILD_NUMBER','')
if build.isdigit():s=re.sub(r'CURRENT_PROJECT_VERSION = .*','CURRENT_PROJECT_VERSION = '+build,s)
p.write_text(s)
PY
