require "GNTools/Tools/NewPaths/GN_ToolpathPoint.rb"
require 'json'

module GNTools
  module NewPaths

    class ToolpathSchemas

	  # Base Types
	  # ├─ Arc
	  # │   └─ Définition : arc simple (segment circulaire)
	  # │   └─ Points : 2 (début et fin) + optionnel centre i,j,k
	  # │   └─ Usage : trous circulaires, arrondis de profile
	  # ├─ Line
	  # │   └─ Définition : ligne droite
	  # │   └─ Points : exactement 2
	  # │   └─ Usage : profils simples, découpe droite
	  # ├─ OpenShape
	  # │   └─ Définition : polyligne ouverte
	  # │   └─ Points : ≥2
	  # │   └─ Usage : gravure, parcours non fermé
	  # ├─ ClosedShape
	  # │   └─ Définition : polyligne fermée
	  # │   └─ Points : ≥3
	  # │   └─ Usage : poche, contour fermé, zone à usiner
	  # └─ Custom
	  #     └─ Définition : macro / stratégie complexe
	  #     └─ Points : variable
	  #     └─ Usage : pattern personnalisé, opérations spéciales
	  # 
	  # Dépendants / Extensions
	  # ├─ Hole
	  # │   └─ Base : Arc ou ClosedShape
	  # │   └─ Définition : trou circulaire ou polygonal
	  # │   └─ Points : 1 (trou central)
	  # │   └─ Usage : perçage précis
	  # ├─ Pocket
	  # │   └─ Base : ClosedShape
	  # │   └─ Définition : zone fermée à enlever
	  # │   └─ Usage : poche ou rainure contour de pièce, profilé
	  # ├─ Engrave
	  # │   └─ Base : OpenShape / ClosedShape / Line
	  # │   └─ Définition : gravure sur surface
	  # │   └─ Usage : texte, motifs, décoration
	  # └─ DrillPattern
	  #     └─ Base : collection de Hole
	  #     └─ Définition : série de trous selon pattern
	  #     └─ Usage : perçage multiple répétitif


      @SCHEMAS = {}

      # ===========================================================
      # == Méthode d'enregistrement générique ==
      # ===========================================================
      def self.register(type_name, schema_hash, dependance = nil)
        @SCHEMAS[type_name] = schema_hash
		@SCHEMAS[type_name]["dependance"] = dependance
      end

      # ===========================================================
      # == Récupération fusion Base + Schema spécifique ==
      # ===========================================================
      def self.get_schema(type_name)
		return nil unless @SCHEMAS.key?(type_name)


	    # ---------------------------------------------------
	    # Construire la liste : [dep1, dep2, ..., type_name]
	    # ---------------------------------------------------
		dependanceList = []
		dep = type_name
        while (dep)
		  dependanceList.unshift(dep)
          dep = @SCHEMAS[dep]["dependance"]
        end

	    max_idx_in = lambda do |m|
		  m["Schema"].values.map { |v| v["idx"].to_i }.max.to_i
	    end
		
		# ---------------------------------------------------
		# merged commence vide
		# ---------------------------------------------------
		merged = nil
		dependanceList.each { |dep|
          spec = Marshal.load(Marshal.dump(@SCHEMAS[dep]))
		  offset  = max_idx_in.call(spec)
		  if merged
			  # Ajoute offset  à tous les idx existants dans merged
			  merged["Schema"].each do |key, field|
				next if field["type"].to_s == ""
				field["idx"] = (field["idx"].to_i + offset )
			  end
			  merged["Schema"].merge!(spec["Schema"]) if spec["Schema"]
			  merged["Rules"].merge!(spec["Rules"])   if spec["Rules"]
		 else
			merged = spec
		 end
		}

	    # ---------------------------------------------------
	    # Rules + Strategy : uniquement le type final
	    # ---------------------------------------------------
	    final = Marshal.load(Marshal.dump(@SCHEMAS[type_name]))

	    final["Schema"]   = merged["Schema"]
	    final["Rules"]    = final["Rules"]
	    final["Strategy"] = final["Strategy"]


        return Marshal.load(Marshal.dump(final))
      end

      def self.get_meta_schema(type_name)
		self.get_schema(type_name)["Schema"]
	  end

      def self.get_meta_rules(type_name)
		self.get_schema(type_name)["Rules"]
	  end

      def self.get_strategy(type_name)
		self.get_schema(type_name)["Strategy"]
	  end

      # Expose la liste des types
      def self.types
        @SCHEMAS.keys
      end
		
	  def self.toHash
		merged = Marshal.load(Marshal.dump(@SCHEMAS))
	    merged.keys.each do |key|
		  dependance_list = []
		  dep = key
		  while dep
			# Ajoute au schema le schema dependant
			merged[key]["Schema"].merge!(self.get_meta_schema(dep))
			merged[key]["Schema"]["type"] = key.to_s
		    dependance_list.unshift(dep)
		    dep = merged[dep]["dependance"]  # on prend dans merged pour rester cohérent
		  end
		  
	    end
		merged.delete("Base")
		merged
	  end
		
	  def self.toJson
		merged = self.toHash
	    JSON.generate(merged)
	  end

	  # ===========================================================
	  #  Validation automatique des points
	  # ===========================================================
	  def self.validate_points(tp)
		schemaName = tp.metadata["type"]["Value"]
		if not schemaName
			puts "error schemaName"
		end
	    schema = self.get_schema(schemaName)
		if not schema
			puts "schemaName"
			puts schemaName
			puts "error schema ???"
		end
	    rules  = schema["Rules"]
		if not rules
			puts "error rules"
		end
	    count = tp.points.length
	    # Vérification min
	    if rules[:min_points] && count < rules[:min_points]
		  raise "Toolpath #{tp.metadata["type"]} requires at least #{rules[:min_points]} points, got #{count}"
	    end

	    # Vérification max
	    if rules[:max_points] && count > rules[:max_points]
		  raise "Toolpath #{tp.metadata["type"]} allows at most #{rules[:max_points]} points, got #{count}"
	    end
	    true
	  end

      # ===========================================================
      # Enregistrement des types internes
      # ===========================================================


      # --- Base Schema commun à tous ---
	  register("Base", {
	    "Schema" => {
		  "pathName"       => { "Value" => "",        "type" => "" },
		  "type"           => { "Value" => "Base",    "type" => "" },
		  "depth"          => { "Value" => 4.0,       "type" => "spinner",  "idx" => 1 },
		  "feedrate"       => { "Value" => 5.0,       "type" => "spinner",  "idx" => 2 },
		  "multipass"      => { "Value" => true,      "type" => "checkbox", "idx" => 3 },
		  "depthstep"      => { "Value" => 0.2,       "type" => "spinner",  "idx" => 4 },
		  "overlapPercent" => { "Value" => 50,        "type" => "spinner",  "idx" => 5 },
		  "drillBitName"   => { "Value" => "Default", "type" => "dropdown", "idx" => 6 }
	    },
	    "Rules" => {
		  min_points: 0,
		  max_points: nil,
	  	  closed: false
	    },
	    "Strategy" => { "Name" => "drill" , "Selection" => "Point"}
	  })


	  register("Arc", {
	    "Schema" => {
		  "type"        => { "Value" => "Arc",     "type" => "" },
		  "angle"       => { "Value" => 90.0,      "type" => "spinner",  "min": 0,"max": 180, "step": 0.1, "idx" => 1 },
		  "direction"   => { "Value" => "Horaire", "type" => "dropdown", "options": ["Horaire", "Anti Horaire"], "idx" => 2 },
		  "cutwidth"    => { "Value" => 3.175,     "type" => "spinner",  "idx" => 3 },
		  "nbdesegment" => { "Value" => 24,        "type" => "spinner",  "idx" => 4 }
	    },
	    "Rules" => {
		  min_points: 2,
	  	  max_points: 2,
		  closed: false
	    },
	    "Strategy" => { "Name" => "Arc" , "Selection" => "Arc"}
	  }, "Base")


	  register("Line", {
	    "Schema" => {
		  "type"       => { "Value" => "Line", "type" => "" },
		  "methodType" => { "Value" => "Ramp", "type" => "dropdown", "options": ["Ramp","Pocket", "Spiral"], "idx" => 2 },
		  "cutwidth"   => { "Value" => 3.175,  "type" => "spinner",  "idx" => 1 }
	    },
	    "Rules" => {
		  min_points: 2,
		  max_points: 2,
		  closed: false
	    },
	    "Strategy" => { "Name" => "Line" , "Selection" => "Line" }
	  }, "Base")


      register("OpenShape", {
        "Schema" => {
          "type"       => { "Value" => "OpenShape","type" => ""         },
           "methodType" => { "Value" => "Ramp",     "type" => "dropdown", "idx" => 1 }
        },
        "Rules" => {
          min_points: 2,
          max_points: nil,
          closed: false
        },
		"Strategy" => { "Name" => "OpenShape" , "Selection" => "Multiline"
		}
      },"Base")

      register("ClosedShape", {
        "Schema" => {
          "type"       => { "Value" => "ClosedShape", "type" => ""         },
          "methodType" => { "Value" => "Pocket",      "type" => "dropdown", "idx" => 1 }
        },
        "Rules" => {
          min_points: 3,
          max_points: nil,
          closed: true
        },
		"Strategy" => { "Name" => "ClosedShape" , "Selection" => "Loop"
		}
      },"Base")

      register("Hole", {
        "Schema" => {
		  "type"         => { "Value" => "Hole",   "type" => "" },
		  "holesize"     => { "Value" => 15.0,     "type" => "spinner",  "idx" => 1 },
		  "methodType"   => { "Value" => "Pocket", "type" => "dropdown", "options": ["Pocket", "Spiral"], "idx" => 2 },
		  "holeposition" => { "Value" => [0,0,0],  "type" => "" },
		  "nbdesegment"  => { "Value" => 24,       "type" => "spinner",  "idx" => 3 },
		  "cutwidth"     => { "Value" => 3.175,    "type" => "spinner",  "idx" => 4 }
        },
        "Rules" => {
          min_points: 1,
          max_points: 1,
          closed: true    # cercle
        },
		"Strategy" => { "Name" => "Hole" , "Selection" => "Point"
		}
      },"Base")

	  register("Pocket", {
	    "Schema" => {
		  "type"            => { "Value" => "Pocket", "type" => "" },
		  "methodType"      => { "Value" => "Pocket", "type" => "dropdown", "idx" => 1 },
		  "cutwidth"        => { "Value" => 3.175,    "type" => "spinner",  "idx" => 2 },
		  "overlapPercent"  => { "Value" => 50,       "type" => "spinner",  "idx" => 3 }
	    },
	    "Rules" => {
		  min_points: 3,
		  max_points: nil,
		  closed: true
	    },
		"Strategy" => { "Name" => "Pocket" , "Selection" => "Loop"
		}
	  }, "ClosedShape")

	  register("Engrave", {
	    "Schema" => {
		  "type"         => { "Value" => "Engrave",      "type" => ""         },
		  "methodType"   => { "Value" => "Engrave", "type" => "dropdown", "idx" => 1 },
		  "engraveDepth" => { "Value" => 0.3,       "type" => "spinner",  "idx" => 2 },
		  "cutwidth"     => { "Value" => 1.0,       "type" => "spinner",  "idx" => 3 }
	    },
	    "Rules" => {
		  min_points: 1,
		  max_points: nil,
		  closed: false
	    },
		"Strategy" => { "Name" => "Engrave" , "Selection" => "Multiline"
		}
	  }, "OpenShape")


	  register("DrillPattern", {
	    "Schema" => {
		  "type"         => { "Value" => "DrillPattern", "type" => ""         },
		  "holesize" => { "Value" => 10.0, "type" => "spinner",  "idx" => 1 },
		  "spacing"  => { "Value" => 20.0, "type" => "spinner",  "idx" => 2 },
		  "rows"     => { "Value" => 2,    "type" => "spinner",  "idx" => 3 },
		  "cols"     => { "Value" => 2,    "type" => "spinner",  "idx" => 4 }
	    },
	    "Rules" => {
		  min_points: 1,
		  max_points: nil,
		  closed: false
	    },
		"Strategy" => { "Name" => "DrillPattern" , "Selection" => "Point"
		}
	  }, "Hole")

    end

    class Toolpath
      include Enumerable

	  attr_accessor :id
      # --- type de chemin ---
      attr_accessor :type
	  
	  attr_accessor :name
	  
      # --- Points dans ce chemin ---
      attr_accessor :points
      # --- Metadata du chemin ---
      attr_accessor :metadata
	  
	  attr_accessor :visible
	  
      attr_accessor :toolpathValide
	  attr_accessor :toolpathError

      # Initialise un Toolpath
      # type: "Arc", "Line", "OpenShape", "ClosedShape"  etc., pour récupérer le schema de base
      # metadata: hash pour override les valeurs par défaut et garder les valeurs
	  def initialize(id: nil, name: "unnamed", type: nil, in_metadata: {}, point_data: [],visible: true )
		@id = id || SecureRandom.uuid

		@name = name

        @points = []

		@type = type

		@visible = visible
	
		if not @type
		  @type = "Base"
		end
		

        # On prend une copie du schema correspondant au type
        @metadata = ToolpathSchemas.get_meta_schema(@type || "")
        # Merge des valeurs fournies dans le hash metadata
        @metadata.each do |key, val|
#		  if key == "drillBitName"
#		    puts "metadata avant change  #{key} avec #{@metadata[key]["Value"]}" if in_metadata.key?(key)
#		  end
          @metadata[key]["Value"] = in_metadata[key] if in_metadata.key?(key)
#		  if key == "drillBitName"
#		    puts "metadata change  #{key} avec #{in_metadata[key]}" if in_metadata.key?(key)
#		  end
        end

		@toolpathValide = false
		# --- Ajouter des points si fournis ---
		addPoints(point_data)
      end

	  def addPoints(point_data)
	  	# --- Ajouter des points si fournis ---
		point_data.each do |pt|
		  pos, attrs = nil, {}
		  
		  case pt
		    when Geom::Point3d
			  pos = pt
		    when Array
			  raise ArgumentError, "Array doit avoir 3 éléments" unless pt.size == 3
			  pos = Geom::Point3d.new(*pt)
		    when Hash
		      if pt[:pos]
			    # pt = { pos: [x,y,z] or Geom::Point3d, attrs: {...} }
			    pos = pt[:pos].is_a?(Geom::Point3d) ? pt[:pos] : Geom::Point3d.new(*pt[:pos])
			    attrs = pt[:attrs] || {}
		      else
			    raise ArgumentError, "Point invalide: #{pt.inspect}"
		      end
		    else
		      raise ArgumentError, "Point invalide: #{pt.inspect}"
          end
		  @points << ToolpathPoint.new(pos, attrs)
		end
		begin
			ToolpathSchemas.validate_points(self)
			@toolpathValide = true
			@toolpathError = nil
		rescue => e
			@toolpathValide = false
			@toolpathError = e.message
		end
	  end

      # --- Gestion des points ---
      def add_point(position, attributes = {})
	    raise ArgumentError, "Doit être un Geom::Point3d" unless position.is_a?(Geom::Point3d)
        @points << ToolpathPoint.new(position, attributes)
		begin
			ToolpathSchemas.validate_points(self)
			@toolpathValide = true
			@toolpathError = nil
		rescue => e
			@toolpathValide = false
			@toolpathError = e.message
		end
      end

      def remove_point(point)
        @points.delete(point)
		begin
			ToolpathSchemas.validate_points(self)
			@toolpathValide = true
			@toolpathError = nil
		rescue => e
			@toolpathValide = false
			@toolpathError = e.message
		end
      end

      def delete_point(index)
        @points.delete_at(index) if index.between?(0, @points.size - 1)
		begin
			ToolpathSchemas.validate_points(self)
			@toolpathValide = true
			@toolpathError = nil
		rescue => e
			@toolpathValide = false
			@toolpathError = e.message
		end
      end

	  def update_point(idx, new_pt)
		@points[idx] = new_pt
	  end

      def transform_points(transformation)
        @points.each { |pt| pt.position.transform!(transformation) }
      end

      def each(&block)
        @points.each(&block)
      end

      def last_point
        @points.last
      end

      def total_length
        return 0 if @points.size < 2
        @points.each_cons(2).sum { |p1, p2| p1.position.distance(p2.position) }
      end

      def bounding_box
        box = Geom::BoundingBox.new
        @points.each { |p| box.add(p.position) }
        box
      end

      def merge!(other)
        @points.concat(other.points)
      end

      def empty?
        @points.empty?
      end

      # --- Helpers metadata ---
      def value(key)
        @metadata[key] ? @metadata[key]["Value"] : nil
      end

      def set_value(key, val)
        if @metadata[key]
          @metadata[key]["Value"] = val
        else
          @metadata[key] = { "Value" => val, "type" => "text", "multiple" => false }
        end
      end

	  def to_hash
	    {
		  id: @id,
		  name: @name,
		  type: @type,
		  visible: @visible,
		  metadata: Marshal.load(Marshal.dump(@metadata)),
		  points: @points.map do |p|
		    {
			  pos: p.position.to_a,
			  attrs: Marshal.load(Marshal.dump(p.attributes))
		    }
		  end
	    }
	  end


	  def self.from_hash(hash_in)
	    values_only = hash_in[:metadata].each_with_object({}) do |(k, v), out|
	  	  out[k] = v["Value"] || v[:Value]
	    end

	    tp = new(
		  id: hash_in[:id],
		  name: hash_in[:name],
		  type: hash_in[:type],
		  in_metadata: values_only,
		  visible: hash_in[:visible]
	    )

	    (hash_in[:points] || []).each do |pt|
		  tp.points << ToolpathPoint.new(
		    Geom::Point3d.new(*pt[:pos]),
		    pt[:attrs] || {}
		  )
	    end
	    tp
	  end

      # --- Debug lisible ---
      def to_s
        points_str = @points.map(&:to_s).join(", ")
        "Toolpath(metadata=#{@metadata}, points=[#{points_str}])"
      end
    end
  end
end
