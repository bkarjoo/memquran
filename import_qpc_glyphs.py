#!/usr/bin/env python3
import json
import sqlite3

# Load the QPC glyph codes JSON
print("Loading QPC glyph codes JSON...")
with open('/Users/behroozkarjoo/Downloads/qpc-v1-glyph-codes-wbw.json', 'r', encoding='utf-8') as f:
    qpc_data = json.load(f)

print(f"Loaded {len(qpc_data)} word entries")

# Connect to the database
print("Connecting to database...")
conn = sqlite3.connect('/Users/behroozkarjoo/dev/memquran/uthmani.db')
cursor = conn.cursor()

# Update each word with its QPC glyph code
updated_count = 0
not_found_count = 0

for location, data in qpc_data.items():
    surah = int(data['surah'])
    ayah = int(data['ayah'])
    word = int(data['word'])
    glyph_text = data['text']

    # Update the word in the database
    cursor.execute('''
        UPDATE words
        SET text = ?
        WHERE surah = ? AND ayah = ? AND word = ?
    ''', (glyph_text, surah, ayah, word))

    if cursor.rowcount > 0:
        updated_count += 1
    else:
        not_found_count += 1

    if updated_count % 10000 == 0:
        print(f"Updated {updated_count} words...")

# Commit changes
conn.commit()
conn.close()

print(f"\n✅ Successfully updated {updated_count} words with QPC glyph codes")
if not_found_count > 0:
    print(f"⚠️  {not_found_count} words not found in database")
