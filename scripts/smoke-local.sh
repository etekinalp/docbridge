#!/usr/bin/env bash
set -e

echo "=========================================="
echo "Running DocBridge Local Infrastructure Smoke Tests..."
echo "=========================================="

# 1. Check LocalStack (AWS S3 / SQS emulation)
echo -n "-> Checking LocalStack AWS emulator (port 4566)... "
if curl -s -f "http://localhost:4566/_localstack/health" > /dev/null; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

# 2. Check PostgreSQL Database container
echo -n "-> Checking PostgreSQL database (port 5432)... "
if nc -z localhost 5432 2>/dev/null || pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

echo "=========================================="
echo "Smoke test sequence complete."
echo "=========================================="
