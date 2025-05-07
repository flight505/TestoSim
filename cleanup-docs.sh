#!/bin/bash

# This script backs up and removes the old documentation files
# after consolidating their content into FINAL_MIGRATION_PLAN.md

# Create backup directory if it doesn't exist
mkdir -p backup/docs

# Backup and remove old documentation files
echo "Backing up old documentation files..."

if [ -f "MIGRATION_PLAN.md" ]; then
  cp "MIGRATION_PLAN.md" "backup/docs/MIGRATION_PLAN.md"
  rm "MIGRATION_PLAN.md"
  echo "✅ Backed up and removed MIGRATION_PLAN.md"
else
  echo "❌ MIGRATION_PLAN.md not found"
fi

if [ -f "NEXT_STEPS.md" ]; then
  cp "NEXT_STEPS.md" "backup/docs/NEXT_STEPS.md"
  rm "NEXT_STEPS.md"
  echo "✅ Backed up and removed NEXT_STEPS.md"
else
  echo "❌ NEXT_STEPS.md not found"
fi

if [ -f "REFACTORING_SUMMARY.md" ]; then
  cp "REFACTORING_SUMMARY.md" "backup/docs/REFACTORING_SUMMARY.md"
  rm "REFACTORING_SUMMARY.md"
  echo "✅ Backed up and removed REFACTORING_SUMMARY.md"
else
  echo "❌ REFACTORING_SUMMARY.md not found"
fi

if [ -f "ai_docs/guide2.md" ]; then
  mkdir -p backup/docs/ai_docs
  cp "ai_docs/guide2.md" "backup/docs/ai_docs/guide2.md"
  rm "ai_docs/guide2.md"
  echo "✅ Backed up and removed ai_docs/guide2.md"
else
  echo "❌ ai_docs/guide2.md not found"
fi

echo "✨ Documentation cleanup complete. All information has been consolidated into FINAL_MIGRATION_PLAN.md"
echo "📂 Original files are backed up in the backup/docs directory"