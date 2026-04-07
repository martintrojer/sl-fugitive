#!/bin/bash
set -e

tmp=$(mktemp -d /tmp/sl-fugitive-test.XXXXXX)
cd "$tmp"

sl init
sl config --local 'ui.username=Test User <test@example.com>'
# no remote configured — avoids network errors during testing

# Base commit
cat > README.md << 'EOF'
# Test Project
A project for testing sl-fugitive.
EOF
mkdir -p src
cat > src/main.py << 'EOF'
def main():
    print("hello world")

if __name__ == "__main__":
    main()
EOF
cat > src/utils.py << 'EOF'
def add(a, b):
    return a + b

def subtract(a, b):
    return a - b
EOF
sl add README.md src/main.py src/utils.py
sl commit -m "initial: project skeleton"

# Stack of 6 commits (deep enough to test ri, rf, etc.)
cat >> src/main.py << 'EOF'

def greet(name):
    print(f"Hello, {name}!")
EOF
sl commit -m "feat: add greet function"

cat >> src/utils.py << 'EOF'

def multiply(a, b):
    return a * b
EOF
sl commit -m "feat: add multiply to utils"

cat > src/config.py << 'EOF'
DEBUG = False
VERSION = "0.1.0"
LOG_LEVEL = "INFO"
EOF
sl add src/config.py
sl commit -m "feat: add config module"

cat >> src/main.py << 'EOF'

def farewell(name):
    print(f"Goodbye, {name}!")
EOF
sl commit -m "feat: add farewell function"

cat > src/tests.py << 'EOF'
from utils import add, subtract, multiply
from main import greet, farewell

def test_add():
    assert add(1, 2) == 3

def test_subtract():
    assert subtract(5, 3) == 2

def test_multiply():
    assert multiply(3, 4) == 12
EOF
sl add src/tests.py
sl commit -m "test: add unit tests"

cat >> README.md << 'EOF'

## Usage
Run `python src/main.py` to start.
EOF
sl commit -m "docs: add usage section to README"

# Create a bookmark at the tip
sl bookmark feature-branch -r .

# Branch off from "feat: add config module" (4th commit)
sl goto -q 'desc("feat: add config module")'
cat > src/logging.py << 'EOF'
import logging

logger = logging.getLogger(__name__)

def setup_logging(level="INFO"):
    logging.basicConfig(level=level)
    logger.info("Logging initialized")
EOF
sl add src/logging.py
sl commit -m "feat: add logging module"

cat >> src/logging.py << 'EOF'

def log_error(msg):
    logger.error(msg)
EOF
sl commit -m "feat: add error logging"
sl bookmark logging-branch -r .

# Branch off from "feat: add greet function" (2nd commit)
sl goto -q 'desc("feat: add greet function")'
cat > src/cli.py << 'EOF'
import argparse

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", default="world")
    return parser.parse_args()
EOF
sl add src/cli.py
sl commit -m "feat: add CLI argument parser"
sl bookmark cli-branch -r .

# Go back to the middle of the main stack for testing
sl goto -q 'desc("feat: add config module")'

# Leave some uncommitted changes for status/diff testing
echo "EXTRA_FLAG = True" >> src/config.py
echo "new file content" > untracked.txt

echo ""
echo "Test repo ready at: $tmp"
echo ""
echo "Stack:"
sl sl
echo ""
echo "Status:"
sl status
echo ""
echo "Open with:  cd $tmp && nvim src/main.py"
