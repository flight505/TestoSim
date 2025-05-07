#!/bin/bash

# Script to rename the updated files and replace the legacy ones

# First, make backup copies of the original files
echo "Making backups of original files..."
mkdir -p backup/ViewModels
mkdir -p backup/Views

# CoreDataManager
if [ -f "TestoSim/ViewModels/CoreDataManager.swift" ]; then
  cp "TestoSim/ViewModels/CoreDataManager.swift" "backup/ViewModels/CoreDataManager.swift.bak"
fi

# AppDataStore
if [ -f "TestoSim/ViewModels/AppDataStore.swift" ]; then
  cp "TestoSim/ViewModels/AppDataStore.swift" "backup/ViewModels/AppDataStore.swift.bak"
fi

# ContentView
if [ -f "TestoSim/ContentView.swift" ]; then
  cp "TestoSim/ContentView.swift" "backup/ContentView.swift.bak"
fi

# ProtocolFormView
if [ -f "TestoSim/Views/ProtocolFormView.swift" ]; then
  cp "TestoSim/Views/ProtocolFormView.swift" "backup/Views/ProtocolFormView.swift.bak"
fi

# ProtocolDetailView
if [ -f "TestoSim/Views/ProtocolDetailView.swift" ]; then
  cp "TestoSim/Views/ProtocolDetailView.swift" "backup/Views/ProtocolDetailView.swift.bak"
fi

# AddBloodworkView
if [ -f "TestoSim/Views/AddBloodworkView.swift" ]; then
  cp "TestoSim/Views/AddBloodworkView.swift" "backup/Views/AddBloodworkView.swift.bak"
fi

# CyclePlannerView
if [ -f "TestoSim/Views/CyclePlannerView.swift" ]; then
  cp "TestoSim/Views/CyclePlannerView.swift" "backup/Views/CyclePlannerView.swift.bak"
fi

echo "Backups created successfully."

# Now rename/move the updated files
echo "Replacing files with updated versions..."

# CoreDataManager
if [ -f "TestoSim/ViewModels/CoreDataManager_Updated.swift" ]; then
  mv "TestoSim/ViewModels/CoreDataManager_Updated.swift" "TestoSim/ViewModels/CoreDataManager.swift"
  echo "✅ CoreDataManager updated"
else
  echo "❌ CoreDataManager_Updated.swift not found"
fi

# AppDataStore
if [ -f "TestoSim/ViewModels/AppDataStore_Refactored.swift" ]; then
  mv "TestoSim/ViewModels/AppDataStore_Refactored.swift" "TestoSim/ViewModels/AppDataStore.swift"
  echo "✅ AppDataStore updated"
else
  echo "❌ AppDataStore_Refactored.swift not found"
fi

# ContentView
if [ -f "TestoSim/ContentView_Updated.swift" ]; then
  mv "TestoSim/ContentView_Updated.swift" "TestoSim/ContentView.swift"
  echo "✅ ContentView updated"
else
  echo "❌ ContentView_Updated.swift not found"
fi

# TreatmentFormView (replacing ProtocolFormView)
if [ -f "TestoSim/Views/TreatmentFormView_Updated.swift" ]; then
  mv "TestoSim/Views/TreatmentFormView_Updated.swift" "TestoSim/Views/TreatmentFormView.swift"
  echo "✅ TreatmentFormView updated"
else
  echo "❌ TreatmentFormView_Updated.swift not found"
fi

# TreatmentDetailView (replacing ProtocolDetailView)
if [ -f "TestoSim/Views/TreatmentDetailView_Updated.swift" ]; then
  mv "TestoSim/Views/TreatmentDetailView_Updated.swift" "TestoSim/Views/TreatmentDetailView.swift"
  echo "✅ TreatmentDetailView updated"
else
  echo "❌ TreatmentDetailView_Updated.swift not found"
fi

# AddBloodworkView
if [ -f "TestoSim/Views/AddBloodworkView_Updated.swift" ]; then
  mv "TestoSim/Views/AddBloodworkView_Updated.swift" "TestoSim/Views/AddBloodworkView.swift"
  echo "✅ AddBloodworkView updated"
else
  echo "❌ AddBloodworkView_Updated.swift not found"
fi

# AdvancedTreatmentView (replacing CyclePlannerView)
if [ -f "TestoSim/Views/AdvancedTreatmentView.swift" ] && [ -f "TestoSim/Views/CyclePlannerView.swift" ]; then
  mv "TestoSim/Views/CyclePlannerView.swift" "backup/Views/CyclePlannerView.swift.bak" # Make sure it's backed up
  cp "TestoSim/Views/AdvancedTreatmentView.swift" "TestoSim/Views/CyclePlannerView.swift" # Copy instead of move to keep the original
  echo "✅ CyclePlannerView replaced with AdvancedTreatmentView"
else
  echo "❌ AdvancedTreatmentView.swift or CyclePlannerView.swift not found"
fi

echo "File replacements completed."
echo "You may need to update imports and references in other files."