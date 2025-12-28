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

	  # ===========================================================
	  # === Singleton Instance ===
	  # ===========================================================
	  @instance = nil
	  def self.instance
		@instance ||= new
	  end

	  # ===========================================================
	  # === Méthodes de classe exposées ===
	  # ===========================================================
	  def self.apply_schema_diff(diff)
		instance.apply_schema_diff(diff)
	  end

	  def self.toJson
		instance.to_json
	  end

	  def self.register(type_name, schema_hash, dependance = nil)
		instance.register(type_name, schema_hash, dependance)
	  end

	  # ===========================================================
	  # === Initialisation ===
	  # ===========================================================
	  def initialize
		@default_schemas = {}
		@custom_schemas  = load_custom_schemas
		@merged_cache    = {} # cache des schemas fusionnés pour éviter recalcul
	  end

	  attr_reader :default_schemas, :custom_schemas

	  # ===========================================================
	  # === Méthodes de chargement / sauvegarde ===
	  # ===========================================================
	  def load_custom_schemas
		file = File.join(GNTools::PATH_TOOLS, "Schemas.custom")
		return {} unless File.exist?(file)
		JSON.parse(File.read(file))
	  end

	  def save_custom_schemas
		file = File.join(GNTools::PATH_TOOLS, "Schemas.custom")
		File.write(file, JSON.pretty_generate(@custom_schemas))
		nil
	  end

	  # Applique un patch / diff sur les custom schemas
	  def apply_schema_diff(diff)
		return unless diff.is_a?(Hash)
		diff.each do |name, patch|
		  if patch.nil?
			@custom_schemas[name] = nil
		  else
			@custom_schemas[name] = Marshal.load(Marshal.dump(patch))
		  end
		  @merged_cache.delete(name) # invalide cache si custom modifié
		end
		save_custom_schemas
	  end

	  # ===========================================================
	  # === Enregistrement d'un schema par défaut ===
	  # ===========================================================
	  def register(type_name, schema_hash, dependance = nil)
		@default_schemas[type_name] = Marshal.load(Marshal.dump(schema_hash))
		@default_schemas[type_name]["dependance"] = dependance
		@merged_cache.delete(type_name)
	  end

	  # ===========================================================
	  # === Schéma fusionné avec custom override ===
	  # ===========================================================
	  def schemas
		# merge DEFAULT + CUSTOM
		merged = Marshal.load(Marshal.dump(@default_schemas))
		@custom_schemas.each do |name, custom|
		  if custom.nil?
			merged.delete(name)
		  else
			merged[name] = Marshal.load(Marshal.dump(custom))
		  end
		end
		merged
	  end

	  # ===========================================================
	  # === Récupération d'un schema fusionné avec dépendances ===
	  # ===========================================================
	  def get_schema(type_name)
		return nil unless schemas.key?(type_name)
		return @merged_cache[type_name] if @merged_cache.key?(type_name)

		# construire la liste de dépendances [dep1, dep2, ..., type_name]
		dependance_list = []
		dep = type_name
		while dep
		  dependance_list.unshift(dep)
		  dep = schemas[dep]["dependance"]
		end

		merged = nil
		dependance_list.each do |dep|
		  spec = Marshal.load(Marshal.dump(schemas[dep]))
		  offset = spec["Schema"].values.map { |v| v["idx"].to_i }.max.to_i
		  if merged
			merged["Schema"].each do |k, field|
			  next if field["type"].to_s == ""
			  field["idx"] += offset
			end
			merged["Schema"].merge!(spec["Schema"]) if spec["Schema"]
			merged["Rules"].merge!(spec["Rules"]) if spec["Rules"]
		  else
			merged = spec
		  end
		end

		# Rules et Strategy : uniquement le type final
		final = Marshal.load(Marshal.dump(schemas[type_name]))
		final["Schema"]   = merged["Schema"]
		final["Rules"]    = final["Rules"]
		final["Strategy"] = final["Strategy"]

		@merged_cache[type_name] = final
		final
	  end

	  # ===========================================================
	  # === Récupération parts d'un schema ===
	  # ===========================================================
	  def get_meta_schema(type_name)
		get_schema(type_name)["Schema"]
	  end

	  def get_meta_rules(type_name)
		get_schema(type_name)["Rules"]
	  end

	  def get_strategy(type_name)
		get_schema(type_name)["Strategy"]
	  end

	  # ===========================================================
	  # === Export complet (fusionné, cache utilisé) ===
	  # ===========================================================
	  def to_hash
		result = {}
		schemas.each_key do |type_name|
		  next if type_name == "Base"
		  merged_schema = get_meta_schema(type_name).dup
		  result[type_name] = {
			"Schema"   => merged_schema,
			"Rules"    => get_meta_rules(type_name),
			"Strategy" => get_strategy(type_name)
		  }
		end
		result
	  end

	  def to_json
		JSON.generate(to_hash)
	  end
	  
      # ===========================================================
      # Enregistrement des types internes
      # ===========================================================


      # --- Base Schema commun à tous ---
	  register("Base", {
	    "Schema" => {
		  "depth"          => { "Value" => 4.0,       "type" => "spinner",  "idx" => 1, "step" => 0.001, "decimal" => 3 },
		  "feedrate"       => { "Value" => 5.0,       "type" => "spinner",  "idx" => 2, "step" => 0.01, "decimal" => 2 },
		  "multipass"      => { "Value" => true,      "type" => "checkbox", "idx" => 3 },
		  "depthstep"      => { "Value" => 0.2,       "type" => "spinner",  "idx" => 4, "step" => 0.01, "decimal" => 2 },
		  "overlapPercent" => { "Value" => 50,        "type" => "spinner",  "idx" => 5, "min" => 0, "max" => 100, "step" => 0.01, "decimal" => 2 },
		  "drillBitName"   => { "Value" => "Default", "type" => "dropdown", "idx" => 6 }
	    },
	    "Rules" => {
		  min_points: 0,
		  max_points: nil,
	  	  closed: false
	    },
	    "Strategy" => { "Name" => "drill" , "Selection" => "Point"},
		"Preview" => { "Name" => "drill" }
	  })


	  register("Arc", {
	    "Schema" => {
		  "angle"       => { "Value" => 90.0,      "type" => "spinner",  "min" => 0,"max" => 180, "step" => 0.1, "idx" => 1 },
		  "direction"   => { "Value" => "Horaire", "type" => "dropdown", "options": ["Horaire", "Anti Horaire"], "idx" => 2 },
		  "cutwidth"    => { "Value" => 3.175,     "type" => "spinner",  "idx" => 3, "step" => 0.001, "decimal" => 3 },
		  "nbdesegment" => { "Value" => 24,        "type" => "spinner",  "idx" => 4, "step" => 1, "decimal" => 0 }
	    },
	    "Rules" => {
		  min_points: 2,
	  	  max_points: 2,
		  closed: false
	    },
	    "Strategy" => { "Name" => "Line" , "Selection" => "Arc"},
		"Preview" => { "Name" => "Arc" }
	  }, "Base")


	  register("Line", {
	    "Schema" => {
		  "methodType" => { "Value" => "Ramp", "type" => "dropdown", "options": ["Ramp","Pocket", "Spiral"], "idx" => 2 },
		  "cutwidth"   => { "Value" => 3.175,  "type" => "spinner",  "idx" => 1, "step" => 0.001, "decimal" => 3  }
	    },
	    "Rules" => {
		  min_points: 2,
		  max_points: 2,
		  closed: false
	    },
	    "Strategy" => { "Name" => "Line" , "Selection" => "Line" },
		"Preview" => { "Name" => "Line" }
	  }, "Base")


      register("OpenShape", {
        "Schema" => {
           "methodType" => { "Value" => "Ramp",     "type" => "dropdown", "idx" => 1 }
        },
        "Rules" => {
          min_points: 2,
          max_points: nil,
          closed: false
        },
		"Strategy" => { "Name" => "Line" , "Selection" => "Multiline"},
		"Preview" => { "Name" => "OpenShape" }
      },"Base")

      register("ClosedShape", {
        "Schema" => {
          "methodType" => { "Value" => "Pocket",      "type" => "dropdown", "idx" => 1 }
        },
        "Rules" => {
          min_points: 3,
          max_points: nil,
          closed: true
        },
		"Strategy" => { "Name" => "Line" , "Selection" => "Loop" },
		"Preview" => { "Name" => "ClosedShape" }
      },"Base")

      register("Hole", {
        "Schema" => {
		  "holesize"     => { "Value" => 15.0,     "type" => "spinner", "idx" => 1, "step" => 0.001, "decimal" => 3},
		  "methodType"   => { "Value" => "Pocket", "type" => "dropdown", "options": ["Pocket", "Spiral"], "idx" => 2 },
		  "holeposition" => { "Value" => [0,0,0],  "type" => "" },
		  "nbdesegment"  => { "Value" => 24,       "type" => "spinner",  "idx" => 3, "step" => 1, "decimal" => 0 },
		  "cutwidth"     => { "Value" => 3.175,    "type" => "spinner",  "idx" => 4, "step" => 0.001, "decimal" => 3 }
        },
        "Rules" => {
          min_points: 1,
          max_points: 1,
          closed: true    # cercle
        },
		"Strategy" => { "Name" => "Hole" , "Selection" => "Point" },
		"Preview" => { "Name" => "Hole" }
      },"Base")

	  register("Pocket", {
	    "Schema" => {
		  "methodType"      => { "Value" => "Pocket", "type" => "dropdown", "idx" => 1 },
		  "cutwidth"        => { "Value" => 3.175,    "type" => "spinner",  "idx" => 2, "step" => 0.001, "decimal" => 3  },
		  "overlapPercent"  => { "Value" => 50,       "type" => "spinner",  "idx" => 3 }
	    },
	    "Rules" => {
		  min_points: 3,
		  max_points: nil,
		  closed: true
	    },
		"Strategy" => { "Name" => "Line" , "Selection" => "Loop" },
		"Preview" => { "Name" => "Pocket" }
	  }, "ClosedShape")

	  register("Engrave", {
	    "Schema" => {
		  "type"         => { "Value" => "Engrave",      "type" => ""         },
		  "methodType"   => { "Value" => "Engrave", "type" => "dropdown", "idx" => 1 },
		  "engraveDepth" => { "Value" => 0.3,       "type" => "spinner",  "idx" => 2 },
		  "cutwidth"     => { "Value" => 1.0,       "type" => "spinner",  "idx" => 3, "step" => 0.001, "decimal" => 3 }
	    },
	    "Rules" => {
		  min_points: 1,
		  max_points: nil,
		  closed: false
	    },
		"Strategy" => { "Name" => "Line" , "Selection" => "Multiline" },
		"Preview" => { "Name" => "Engrave" }
	  }, "OpenShape")


	  register("DrillPattern", {
	    "Schema" => {
		  "holesize" => { "Value" => 10.0, "type" => "spinner",  "idx" => 1, "step" => 0.001, "decimal" => 3  },
		  "spacing"  => { "Value" => 20.0, "type" => "spinner",  "idx" => 2 },
		  "rows"     => { "Value" => 2,    "type" => "spinner",  "idx" => 3, "step" => 1, "decimal" => 0 },
		  "cols"     => { "Value" => 2,    "type" => "spinner",  "idx" => 4, "step" => 1, "decimal" => 0 }
	    },
	    "Rules" => {
		  min_points: 1,
		  max_points: nil,
		  closed: false
	    },
		"Strategy" => { "Name" => "Line" , "Selection" => "Point" },
		"Preview" => { "Name" => "DrillPattern" }
	  }, "Hole")
	  
	end
  end
end
