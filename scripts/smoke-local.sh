#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "Running DocBridge Local Infrastructure Smoke Tests..."
echo "=========================================="

failures=0

record_check() {
  if [ "$1" -eq 0 ]; then
    echo "✅ PASS"
  else
    echo "❌ FAIL"
    failures=$((failures + 1))
  fi
}

# 1. Backing Services
echo -n "-> Checking LocalStack AWS emulator (port 4566)... "
if curl -s -f "http://localhost:4566/_localstack/health" > /dev/null; then
  record_check 0
else
  record_check 1
fi

echo -n "-> Checking PostgreSQL database (port 5432)... "
if nc -z localhost 5432 2>/dev/null || pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
  record_check 0
else
  record_check 1
fi

# 2. Application Services Health
echo -n "-> Checking user-api service (port 3001)... "
if curl -s -f "http://localhost:3001/health" > /dev/null 2>&1 || nc -z localhost 3001 2>/dev/null; then
  record_check 0
else
  record_check 1
fi

echo -n "-> Checking platform-api service (port 3002)... "
if curl -s -f "http://localhost:3002/health" > /dev/null 2>&1 || nc -z localhost 3002 2>/dev/null; then
  record_check 0
else
  record_check 1
fi

echo -n "-> Checking docbridge-api service (port 3003)... "
if curl -s -f "http://localhost:3003/health" > /dev/null 2>&1 || nc -z localhost 3003 2>/dev/null; then
  record_check 0
else
  record_check 1
fi

echo "=========================================="
echo "Smoke test sequence complete."
echo "=========================================="

if [ "$failures" -ne 0 ]; then
  exit 1
fi