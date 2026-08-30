#!/usr/bin/env bash
set -e

echo "=========================================="
echo "Running DocBridge Local Infrastructure Smoke Tests..."
echo "=========================================="

# 1. Backing Services
echo -n "-> Checking LocalStack AWS emulator (port 4566)... "
if curl -s -f "http://localhost:4566/_localstack/health" > /dev/null; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

echo -n "-> Checking PostgreSQL database (port 5432)... "
if nc -z localhost 5432 2>/dev/null || pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

# 2. Application Services Health
echo -n "-> Checking user-api service (port 3001)... "
if curl -s -f "http://localhost:3001/health" > /dev/null 2>&1 || nc -z localhost 3001 2>/dev/null; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

echo -n "-> Checking platform-api service (port 3002)... "
if curl -s -f "http://localhost:3002/health" > /dev/null 2>&1 || nc -z localhost 3002 2>/dev/null; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

echo -n "-> Checking docbridge-api service (port 3003)... "
if curl -s -f "http://localhost:3003/health" > /dev/null 2>&1 || nc -z localhost 3003 2>/dev/null; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
fi

echo "=========================================="
echo "Smoke test sequence complete."
echo "=========================================="