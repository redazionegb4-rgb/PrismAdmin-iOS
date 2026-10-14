#!/bin/sh
set -eu
PRISM_ADMIN_ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
python3 - "$PRISM_ADMIN_ROOT/Config/App.xcconfig" <<'PY'
import os,re,sys
from pathlib import Path
p=Path(sys.argv[1]);s=p.read_text();build=os.environ.get('CI_BUILD_NUMBER','')
if build.isdigit():s=re.sub(r'CURRENT_PROJECT_VERSION = .*','CURRENT_PROJECT_VERSION = '+build,s)
p.write_text(s)
PY
