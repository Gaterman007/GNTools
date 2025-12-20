# Structure du code (Modules & Classes)

## GN_Menus.rb

### Modules
- `GNTools`

### Classes (hors module)
- `GNMenu`

## GN_OverlayManager.rb

### Modules
- `GNTools`

### Classes (hors module)
- `ToolpathObserver` < `Sketchup::Overlay`
- `OverlayManager` < `Sketchup::AppObserver`

## GN_Toolbars.rb

### Modules
- `GNTools`

### Classes (hors module)
- `GN3DToolbars`

## GN_ToolsCore.rb

### Modules
- `GNTools`

## GN_command_class.rb

### Modules
- `GNTools`

### Classes (hors module)
- `CommandClass`

## Geometrie/CLineclass.rb

### Modules
- `GNTools`

### Classes (hors module)
- `LineTool`

## Geometrie/GNWin32.rb

### Modules
- `Win32API2`
- `ComDlg32`
- `User32`
- `CursorPos`
- `FileName`

## Geometrie/GN_Circle3Point.rb

### Modules
- `GNTools`

### Classes (hors module)
- `Circle3X3DPoints`

## Geometrie/GN_Line.rb

### Modules
- `GNTools`

### Classes (hors module)
- `LoopSegments`
- `Line3d`
- `Plan3d`
- `Segment3d`
- `Rayon3d`

## Tools/GN_DefaultCNCData.rb

### Modules
- `GNTools`

### Classes (hors module)
- `DefaultCNCData`
- `DefaultCNCDialog`
- `DefaultCNCTool`

## Tools/GN_DrillBits.rb

### Modules
- `GNTools`

### Classes (hors module)
- `DrillBit`
- `DrillBits`

## Tools/GN_GCodeGenerate.rb

### Modules
- `GNTools`

### Classes (hors module)
- `GCodeGenerate`

## Tools/GN_GCode_Manager.rb

### Modules
- `GNTools`
- `NewPaths`

### Classes (hors module)
- `GCodeManager`

## Tools/GN_Observers.rb

### Modules
- `GNTools`
- `ObserverModule`

### Classes (hors module)
- `ModelSpy` < `Sketchup::ModelObserver`
- `MySelectionObserver` < `Sketchup::SelectionObserver`

## Tools/GN_OctoPrintDialog.rb

### Modules
- `GNTools`

### Classes (hors module)
- `OctoPrintDialog`

## Tools/GN_PathObjUtils.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `ToolPathObjObserver` < `Sketchup::EntityObserver`
- `LoopFace`
- `EdgeOffsetter`
- `EdgeIntersector`
- `LoopRebuilder`
- `TransformPoint`
- `GN_PathObjDialog`
- `GN_PathObjTool`

## Tools/GN_ToolPath.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `GN_ToolPathObjData`
- `GN_ToolpathGCodeGenerator`
- `GN_ToolPathObj`

## Tools/GN_Translation.rb

### Modules
- `GNTools`

## Tools/GN_UndoRedoSystem.rb

### Modules
- `GNTools`
- `OperationTrackingPatch`
- `UndoRedoSystem`

### Classes (hors module)
- `OperationTracker`
- `UndoRedoObserver` < `Sketchup::ModelObserver`

## Tools/GN_WebSocketGN.rb

### Modules
- `GNTools`

### Classes (hors module)
- `WebSocketGN`

## Tools/GN_materialTool.rb

### Modules
- `GNTools`

### Classes (hors module)
- `Material`
- `MaterialDialog`

## Tools/NewPaths/GN_ToolPathDialogNew.rb

### Modules
- `GNTools`
- `NewPaths`
- `ToolPathDialogModeManager`
- `ToolPathDialogMouseEvents`
- `ToolPathDialogDraw`
- `ToolPathDialogDialogManager`

### Classes (hors module)
- `ToolPathDialog`

## Tools/NewPaths/GN_ToolpathCollection.rb

### Modules
- `GNTools`
- `NewPaths`

### Classes (hors module)
- `ToolpathCollection`

## Tools/NewPaths/GN_ToolpathPoint.rb

### Modules
- `GNTools`
- `NewPaths`

### Classes (hors module)
- `ToolpathPoint`

## Tools/NewPaths/GN_ToolpathPreview.rb

### Modules
- `GNTools`
- `NewPaths`

### Classes (hors module)
- `ToolpathPreview`

## Tools/NewPaths/GN_Toolpaths.rb

### Modules
- `GNTools`
- `NewPaths`

### Classes (hors module)
- `ToolpathSchemas`
- `Toolpath`

## Tools/NewPaths/GN_Transform.rb

### Modules
- `GNTools`
- `NewPaths`

### Classes (hors module)
- `GN_Transform`

## Tools/NewPaths/GN_strategies.rb

### Modules
- `GNTools`
- `NewPaths`

### Classes (hors module)
- `StrategyEngine`

## Tools/OldPaths/GN_HoleToolpath.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `HoleToolpathObj` < `ToolpathObj`

## Tools/OldPaths/GN_LineToolpath.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `LineToolpathObj` < `ToolpathObj`

## Tools/OldPaths/GN_ShapeToolpath.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `ShapeToolpathObj` < `ToolpathObj`

## Tools/OldPaths/GN_ToolPathObj.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `ToolpathObj`

## Tools/OldPaths/GN_ToolpathPoint.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `ToolpathPoint`

## Tools/OldPaths/GN_Toolpaths.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `ToolpathSchemas`
- `Toolpath`

## Tools/OldPaths/GN_Transform.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `GN_Transform`

## Tools/Paths/GN_Hole.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `GN_HoleData` < `GN_ToolPathObjData`
- `GN_Hole` < `GN_ToolPathObj`

## Tools/Paths/GN_Pocket.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `GN_PocketData` < `GN_ToolPathObjData`
- `GN_Pocket` < `GN_ToolPathObj`
- `PocketData`

## Tools/Paths/GN_StraitCut.rb

### Modules
- `GNTools`
- `Paths`

### Classes (hors module)
- `GN_StraitCutData` < `GN_ToolPathObjData`
- `GN_StraitCut` < `GN_ToolPathObj`

## Tools/octoprint.rb

### Modules
- `GNTools`

### Classes (hors module)
- `OctoPrint`

