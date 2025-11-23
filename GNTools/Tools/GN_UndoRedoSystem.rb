# ======================================================================
#   GNTools - Undo/Redo & Operation Tracker
#   Fichier : GN_undo_redo_observer.rb
# ======================================================================

module GNTools

  # ============================================================
  # 1) OperationTracker : Log interne des opérations SketchUp
  # ============================================================
  class OperationTracker

    @current_op = nil
    @stack_depth = 0
    @history = []

    class << self
      attr_reader :current_op, :stack_depth, :history

      def log_start(name)
        @current_op = name
        @stack_depth += 1
        @history << { type: :start, name: name, time: Time.now, depth: @stack_depth }
      end

      def log_commit
        @history << { type: :commit, name: @current_op, time: Time.now, depth: @stack_depth }
        @stack_depth -= 1 if @stack_depth > 0
        @current_op = nil if @stack_depth == 0
      end

      def log_abort
        @history << { type: :abort, name: @current_op, time: Time.now, depth: @stack_depth }
        @stack_depth -= 1 if @stack_depth > 0
        @current_op = nil if @stack_depth == 0
      end

      def log_external_change(event)
        @history << { type: :external_event, event: event, time: Time.now }
      end
    end
  end


  # ============================================================
  # 2) Patch du modèle SketchUp (safe + idempotent)
  # ============================================================
  module OperationTrackingPatch

    def self.apply!
      model = Sketchup::Model

      # Empêche d'appliquer deux fois
      return if model.instance_methods.include?(:start_operation_without_gntrack)

      model.class_eval do

        #
        # START OPERATION
        #
        alias_method :start_operation_without_gntrack, :start_operation
        def start_operation(name, *args)
          GNTools::OperationTracker.log_start(name.to_s)
          start_operation_without_gntrack(name, *args)
        end

        #
        # COMMIT OPERATION
        #
        alias_method :commit_operation_without_gntrack, :commit_operation
        def commit_operation(*args)
          GNTools::OperationTracker.log_commit
          commit_operation_without_gntrack(*args)
        end

        #
        # ABORT OPERATION
        #
        alias_method :abort_operation_without_gntrack, :abort_operation
        def abort_operation(*args)
          GNTools::OperationTracker.log_abort
          abort_operation_without_gntrack(*args)
        end

      end
    end
  end


  # ============================================================
  # 3) Observer Undo/Redo
  # ============================================================
  class UndoRedoObserver < Sketchup::ModelObserver
    def onActivePathChanged(model)
      GNTools::OperationTracker.log_external_change(:undo_or_redo)
    end

    def onTransactionUndo(model)
      GNTools::OperationTracker.log_external_change(:undo)
    end

    def onTransactionRedo(model)
      GNTools::OperationTracker.log_external_change(:redo)
    end
  end


  # ============================================================
  # 4) Initialisation
  # ============================================================
  module UndoRedoSystem
    @initialized = false

    def self.init!
      return if @initialized
      @initialized = true

      # Patch du model
      GNTools::OperationTrackingPatch.apply!

      # Ajouter l'observer Undo/Redo
      Sketchup.active_model.add_observer(GNTools::UndoRedoObserver.new)
    end
  end

end

# Initialise automatiquement si chargé dans SketchUp
GNTools::UndoRedoSystem.init!
