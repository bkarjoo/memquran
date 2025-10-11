#!/usr/bin/env python3
import re
import uuid

# Read the project file
with open('MemQuran.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate UUIDs and entries for all 604 fonts
build_file_entries = []
file_ref_entries = []
resource_entries = []

for i in range(1, 605):
    # Generate consistent UUIDs for each font
    build_uuid = f"QPC{i:05d}AABBCCDDEE{i:04d}"
    file_uuid = f"QPC{i:05d}FFEEDDCCBB{i:04d}"

    # PBXBuildFile entry
    build_file_entries.append(f"\t\t{build_uuid} /* p{i}.ttf in Resources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* p{i}.ttf */; }};")

    # PBXFileReference entry
    file_ref_entries.append(f"\t\t{file_uuid} /* p{i}.ttf */ = {{isa = PBXFileReference; lastKnownFileType = file; name = p{i}.ttf; path = MemQuran/p{i}.ttf; sourceTree = \"<group>\"; }};")

    # Resource build phase entry
    resource_entries.append(f"\t\t\t\t{build_uuid} /* p{i}.ttf in Resources */,")

# Find and insert PBXBuildFile entries (after Kitab-Regular.ttf entry)
pattern = r'(.*Kitab-Regular\.ttf in Resources \*/ = {isa = PBXBuildFile;.*?};)'
match = re.search(pattern, content)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + '\n' + '\n'.join(build_file_entries) + content[insert_pos:]
    print(f"✅ Added {len(build_file_entries)} PBXBuildFile entries")
else:
    print("❌ Could not find insertion point for PBXBuildFile entries")

# Find and insert PBXFileReference entries (after ScheherazadeNew.ttf entry)
pattern = r'(.*ScheherazadeNew\.ttf.*?sourceTree = "<group>"; };)'
match = re.search(pattern, content, re.DOTALL)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + '\n' + '\n'.join(file_ref_entries) + content[insert_pos:]
    print(f"✅ Added {len(file_ref_entries)} PBXFileReference entries")
else:
    print("❌ Could not find insertion point for PBXFileReference entries")

# Find and insert Resources build phase entries (in the PBXResourcesBuildPhase section)
pattern = r'(A1000008000000000000008 /\* Kitab-Regular\.ttf in Resources \*/,)'
match = re.search(pattern, content)
if match:
    insert_pos = match.end()
    content = content[:insert_pos] + '\n' + '\n'.join(resource_entries) + content[insert_pos:]
    print(f"✅ Added {len(resource_entries)} Resources build phase entries")
else:
    print(f"❌ Could not find insertion point for Resources entries")

# Write the modified project file
with open('MemQuran.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("\n✅ Successfully modified Xcode project file")
print(f"Added {len(build_file_entries)} fonts to the project")
