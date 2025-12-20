module GNTools
  module NewPaths

	##
    # GN_Transform
    # ---------------------------------------------------------------------
    # Classe utilitaire permettant de gérer les transformations
    # dans SketchUp (global <-> local).
    #
    # Fonctionne sur :
    #  - Group
    #  - ComponentInstance
    #  - ComponentDefinition
    #
    # Fournit :
    #  - getGlobalTransform(entity) → Transformation cumulée
    #  - getGlobalPoint(entity, pt) → Point transformé sans modifier l’original
    #  - setGlobal(entity, pt)      → Transforme le point dans le repère global
    #  - setLocal(entity, pt)       → Transforme le point dans le repère local
    #
	class GN_Transform

	  # Retourne la transformation globale cumulée d'une entité
	  def self.getGlobalTransform(entity)
		transformation = Geom::Transformation.new
		parent = entity

		while parent
		  case parent
		  when Sketchup::Group, Sketchup::ComponentInstance
			transformation *= parent.transformation
			parent = parent.parent
		  when Sketchup::ComponentDefinition
			# Prendre la première instance si elle existe
			parent = parent.instances.first
		  else
			break
		  end
		end

		transformation
	  end

      ##
      # Transforme un point dans le repère global sans modifier l’original.
      #
	  def self.getGlobal(entity, point)
		point.transform(getGlobalTransform(entity))
	  end

      ##
      # Transforme un point dans le repère local sans modifier l’original.
      #
	  def self.getLocal(entity, point)
		inverse = getGlobalTransform(entity).inverse
		point.transform!(inverse)
	  end


	  ##
      # Transforme un point directement dans le repère global (mutation).
      #
	  def self.setGlobal(entity, point)
		point.transform!(getGlobalTransform(entity))
	  end

      ##
      # Convertit un point global dans le repère local de l’entité (mutation).
      #
	  def self.setLocal(entity, point)
		inverse = getGlobalTransform(entity).inverse
		point.transform!(inverse)
	  end

	end

  end
end
