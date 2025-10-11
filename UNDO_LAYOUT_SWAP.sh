#!/bin/bash
# Undo script to restore original layout

echo "🔄 Restoring original uthmani layout..."

cd "$(dirname "$0")/MemQuran"

if [ -f "uthmani-15-lines.db.backup" ]; then
    cp uthmani-15-lines.db.backup uthmani-15-lines.db
    echo "✅ Original layout restored"
    echo "📝 Backup still available at: uthmani-15-lines.db.backup"
    echo ""
    echo "To rebuild the app, run:"
    echo "  cd /Users/behroozkarjoo/dev/memquran"
    echo "  xcodebuild -project MemQuran.xcodeproj -scheme MemQuran -configuration Debug build"
else
    echo "❌ Backup file not found!"
    exit 1
fi
