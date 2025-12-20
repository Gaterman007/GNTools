module GNTools
  module NewPaths

    ##
    # ToolpathPoint
    # ---------------------------------------------------------------------
    # Représente un point dans un Toolpath.
    #
    # Contient :
    # - position   : Geom::Point3d
    # - attributes : Hash
    #
    # Exemple d'attributs utilisés :
    #   :type      → :rapid, :linear, :arc_cw, :arc_ccw, :stay, :custom…
    #   :feedrate  → vitesse d’avance
    #   :power     → puissance laser
    #   :extrusion → extrusion (CNC/3D)
    #   :i, :j, :k → centres pour arcs
    #   :comment   → commentaire libre
    #   :state     → infos machine (spindle, coolant, etc.)
    #

	class ToolpathPoint
	  # --- Position dans l’espace ---
	  attr_accessor :position  # Geom::Point3d

	  # --- Attributs machine pour ce point ---
	  attr_accessor :attributes

	  attr_accessor :precision

      ##
      # Initialise un point.
      # position  : Geom::Point3d OU [x,y,z]
      # attributes: Hash
      #
	  def initialize(position, attributes = {})
	    @position   = position.is_a?(Geom::Point3d) ? position : Geom::Point3d.new(*position)
	    @attributes = attributes
		@precision = 2
	  end

	  # -- Helpers -------------------------------------------------------------

	  def x_mm ; @position.x.to_mm ; end
	  def y_mm ; @position.y.to_mm ; end
	  def z_mm ; @position.z.to_mm ; end

	  # Type du mouvement (nil si non spécifié)
	  def type
	    @attributes[:type]
	  end

	  # Lecture d’attribut avec valeur par défaut
	  def [](key)
	    @attributes[key]
	  end

	  def []=(key, value)
	    @attributes[key] = value
	  end

	  # Clone complet
	  def clone
	    ToolpathPoint.new(@position.clone, @attributes.clone)
	  end

      ##
      # Retourne une string standard pour les déplacements CNC
      #
	  def position_to_string
		"X#{x_mm.round(@precision)} Y#{y_mm.round(@precision)} Z#{z_mm.round(@precision)}"
	  end

	  # Debug lisible
	  def to_s
	  	"ToolpathPoint(#{x_mm.round(@precision)}, #{y_mm.round(@precision)}, #{z_mm.round(@precision)}, #{@attributes})"
	  end
	end
  end
end
