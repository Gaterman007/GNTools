module GNTools

  @@selectionHash = {}

  def self.selectionHash
	@@selectionHash
  end

  def self.selectionHash=(values)
	@@selectionHash = values
  end

  def self.verifieSelection(selection)
	detected_curves = Set.new
	detected_circle = Set.new
	selection.each do |item|
		if item.is_a?(Sketchup::Edge) && item.curve && item.curve.is_a?(Sketchup::ArcCurve)
			arc = item.curve
			unless detected_curves.include?(arc)
				detected_curves.add(arc)
				if (arc.end_angle - arc.start_angle).radians == 360.0
					detected_circle.add(arc)
					GNTools::ObserverModule.hasCircle = true
				end
			end
		end
	end
	detected_circle
  end
  


  module ObserverModule

    extend self

	@@modelObserver = nil

	@@allEdges = nil
	@@allFaces = nil
	@@allPoints = nil
	@@hasPaths = false
	@@hasCircle = false
	@@hasEdges = false
	@@hasFaces = false

	def self.allEdges
		@@allEdges
	end

	def self.allEdges=(value)
		@@allEdges = value
	end

	def self.allFaces
		@@allFaces
	end

	def self.allFaces=(value)
		@@allFaces = value
	end

	def self.allPoints
		@@allPoints
	end

	def self.allPoints=(value)
		@@allPoints = value
	end

	def self.hasPaths
		@@hasPaths
	end

	def self.hasPaths=(value)
		@@hasPaths = value
	end

	def self.hasCircle
		@@hasCircle
	end

	def self.hasCircle=(value)
		@@hasCircle = value
	end
	
	
	def self.hasEdges
		@@hasEdges
	end

	def self.hasEdges=(value)
		@@hasEdges = value
	end

	def self.hasFaces
		@@hasFaces
	end

	def self.hasFaces=(value)
		@@hasFaces = value
	end

    def attach(model)
      @@modelObserver = ModelSpy.new(model)
      model.add_observer(@@modelObserver)
    end
	
	def detach()
		if @@modelObserver != nil
			@@modelObserver.remove()
			model.remove_observer(@@modelObserver)
			@@modelObserver = nil
		end
	end

    def expectsStartupModelNotifications
      true
    end

    def onNewModel(model)
      attach(model)
	  DefaultCNCDialog.loadFromFile()
    end

    def onOpenModel(model)
      attach(model)
	  GNTools.setCNCDefaultNo
	  DefaultCNCDialog.def_CNCData.from_model
	  Paths.loadPaths()
    end

    def onQuit()
      # execute onQuit tasks
    end

    class ModelSpy < Sketchup::ModelObserver
      attr_reader :model
	  @@selectionObserver  = nil
      def initialize(model)
        @model = model
        # Hash to hold observer references:
        @spy = {}
        # Add all of the implemented observers:

		# Attach the observer.
		@@selectionObserver = MySelectionObserver.new
		Sketchup.active_model.selection.add_observer(@@selectionObserver)

		
 #       model.definitions.add_observer(@spy[:definitions]= DefinitionsSpy.new)
        # ... etc ...
      end
	  
	  def remove()
#		Sketchup.active_model.entities.remove_observer(@entities_observer) if @entities_observer
		Sketchup.active_model.selection.remove_observer(@@selectionObserver) if @@selectionObserver
	  end
	  
	  def onActivePathChanged(model)
		if model.active_path
#			puts "Groupe ouvert en mode édition: #{model.active_path.to_a}"
			if Paths::isGroupObj(model.active_path.last)
				openedGroup = model.active_path.last
				model.close_active
				Sketchup.active_model.selection.add(openedGroup)
				GNTools::activate_PathTool
			end
#		else
#			puts "Retour au modèle principal ou sortir du groupe"
		end
	  end
	  
	  def onTransactionRedo(model)
#		puts "onTransactionRedo: #{model}"
		new_groups = model.entities.grep(Sketchup::Group).select do |group|
			if !GNTools.pathObjList.key?(group.persistent_id)
				GNTools::Paths.createFromEnt(group)
			end
		end
      end
	  
	  def onTransactionUndo(model)
#		puts "onTransactionUndo: #{model}"
		new_groups = model.entities.grep(Sketchup::Group).select do |group|
			if !GNTools.pathObjList.key?(group.persistent_id)
				GNTools::Paths.createFromEnt(group)
			end
		end
	  end
	  
#	  def onTransactionEmpty(model)
#		puts "onTransactionEmpty: #{model}"
#	  end	  
      # ... ModelObserver callback method definitions ...
    end

  # This is an an observer that watches the selection for changes.
	class MySelectionObserver < Sketchup::SelectionObserver
	
		def check_Selection(selection)

		end
			
		def onSelectionBulkChange(selection)
			check_Selection(selection)
		end
	
		def onSelectionAdded(selection, entity)
			check_Selection(selection)
		end
		
		def onSelectionRemoved(selection, entity)
			check_Selection(selection)
		end		
		
		def onSelectionCleared(selection)
			check_Selection(selection)
		end
    end # MySelectionObserver

	def reload
		detach()
		attach(Sketchup.active_model)
		GNTools.setCNCDefaultNo
		DefaultCNCDialog.def_CNCData.from_model

	end
    # .. other observer class definitions ...

    # RUN ONCE AT STARTUP:
    if !defined?(@loaded)
      # Define UI objects here ...

      # Attach this module as an AppObserver object:
      Sketchup.add_observer(self)
      # Mark this extension as loaded:
      @loaded = true
    end

  end # extension submodule
end # namespace module
