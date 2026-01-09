require_relative 'GN_ScriptEngine.rb'

module GNTools
  module NewPaths


    class StrategyEngine  < BaseScriptEngine

	  DEFAULT = {
	    "contour" => <<~STRAT,
		  ; --- Strategy: contour ---
		  G0 X{CurrentTp.points[0].pos[0]} Y{CurrentTp.points[0].pos[1]} Z{Material.safeHeight}
		  {foreach p in CurrentTp.points}
		    G1 X{p.pos[0]} Y{p.pos[1]} F{CurrentTp.metadata.feedrate.Value}
		  {end}
		  G1 Z{Material.safeHeight}
	    STRAT

	    "drill" => <<~STRAT,
		  ; --- Strategy: drill ---
		  G0 X{CurrentTp.points[0].x} Y{CurrentTp.points[0].y} Z{Material.safeHeight}
		  G1 Z{CurrentTp.metadata.depth.Value} F{Material.feedrate}
		  G0 Z{Material.safeHeight}
	    STRAT

	    "Hole" => <<~STRAT,
		  ; --- Strategy: Hole ---
		  G0 Z{Material.safeHeight}
		  G0 X{CurrentTp.points[0].pos[0]} Y{CurrentTp.points[0].pos[1]} Z{Material.safeHeight} F{CurrentTp.metadata.feedrate.Value}
		  G1 Z{CurrentTp.metadata.depth.Value} F{CurrentTp.metadata.feedrate.Value}
		  G0 Z{Material.safeHeight}
	    STRAT

	    "Line" => <<~STRAT,
		  ; --- Strategy: Line ---
		  G0 Z{Material.safeHeight}
		  G0 X{CurrentTp.points[0].pos[0]} Y{CurrentTp.points[0].pos[1]} F{CurrentTp.metadata.feedrate.Value}
		  G1 Z{CurrentTp.metadata.depth.Value} F{CurrentTp.metadata.feedrate.Value}
		  G1 X{CurrentTp.points[1].pos[0]} Y{CurrentTp.points[1].pos[1]} F{CurrentTp.metadata.feedrate.Value}
		  G0 Z{Material.safeHeight}
	    STRAT
	  }
    
	  attr_accessor :strategies

      def self.instance
        @instance ||= new
      end
	
      def initialize()
		super()                       # ← ScriptEngine
		@lines = []
		@strategies = load_all_strategies
      end

      # ============================================================
      # API PUBLIQUE
      # ============================================================

      # ============================================================
      # Générer le G-code à partir d’une stratégie
      # ============================================================
      def render(name,toolpath,vars = {})
	    @lines.clear
		compile(get(name), @global_vars["Toolpaths"][toolpath])
		gcode
      end

      # ============================================================
      # Récupérer une stratégie (base + custom)
      # ============================================================
      def get(name)
        @strategies[name] or raise "Strategy '#{name}' not found"
      end

      # ============================================================
      # Ajouter ou modifier une stratégie à chaud
      # ============================================================
      def set(name, text)
        @strategies[name] = text
        save_custom_strategies
      end

      # ============================================================
      # Chargements
      # ============================================================
      def load_all_strategies
        base = DEFAULT.dup
        custom = load_custom_file
        base.merge(custom)
      end

      def load_custom_file
        file = File.join(GNTools::PATH_TOOLS, "Strategies.custom")
        return {} unless File.exist?(file)

        text = File.read(file)
        parse_custom_strategies(text)
      end
      # ============================================================
      # Sauvegarde
      # ============================================================
      def save_custom_strategies
        file = File.join(GNTools::PATH_TOOLS, "Strategies.custom")

        File.open(file, "w") do |f|
          @strategies.each do |name, text|
            next if GNTools::NewPaths::StrategyEngine::DEFAULT[name] == text # évite les doublons
            f.puts "[strategy #{name}]"
            f.puts text
            f.puts
          end
        end
      end

      # ============================================================
      # Parsing du fichier custom
      # ============================================================
      def parse_custom_strategies(text)
        h = {}
        current = nil
        buffer = []

        text.each_line do |line|
          if line =~ /^\[strategy (.+?)\]/
            h[current] = buffer.join if current
            current = $1.strip
            buffer = []
          elsif current
            buffer << line
          end
        end

        h[current] = buffer.join if current
        h
      end

	  def handle_instruction(inst)
	    if inst =~ /\A([^;#]*)([;#].*)?\z/
		  code    = Regexp.last_match(1)
		  comment = Regexp.last_match(2)
		  code = code.gsub(/\{([a-zA-Z0-9_\.\[\]]+)\}/) do
		    eval_in_schema(Regexp.last_match(1))
		  end

		  @lines << [code, comment].compact.join
	    else
		  @lines << inst
	    end
	  end
      
      def gcode
        @lines.join("\n")
      end
      
 	  # -------------------------------------------------
	  # Évaluation des expressions {…} dans le script
	  # -------------------------------------------------
	  def eval_in_schema(expr)
	    expr = expr.strip
	    return "" if expr.empty?

	    # 1 — Literal numérique
	    return expr.to_f if expr.match?(/\A-?\d+(\.\d+)?\z/)

	    # 2 — Vérifier les variables locales / globales
	    if @vars.key?(expr)
		  val = @vars[expr]
		  return format_value(val)
	    end

	    # 3 — Accès aux objets imbriqués via . et tableaux []
	    if expr.include?(".") || expr.include?("[")
          val = resolve_path(expr)
		  return format_value(val)
	    end

	    # 4 — Si rien trouvé, retourner vide
	    ""
	  end

	  # -------------------------------------------------
	  # Résolution des chemins imbriqués
	  # Exemple :
	  # CurrentTp.points[0].x
	  # Material.metadata.depth.Value
	  # -------------------------------------------------
	  def resolve_path(path)
	    parts = path.split(".")
	    first = parts.shift

 	    # Chercher dans les vars ou toolpath
		# Si c'est CurrentTp, on prend directement @toolpath
	    obj = @vars[first]
	    return "" unless obj
	    parts.each do |part|
		  # Accès tableau : points[0]
		  if part =~ /(\w+)\[(\d+)\]/
		    key = $1
		    idx = $2.to_i
		    if obj.is_a?(Hash)
			  obj = obj[key]
		    end
		    if obj.is_a?(Array)
			  obj = obj[idx]
		    else
			  return ""
		    end
		  else
		    # Accès Hash ou objet
		    if obj.is_a?(Hash)
			  obj = obj[part]
		    elsif obj.respond_to?(part)
			  obj = obj.send(part)
		    else
			  return ""
		    end
		  end
		  return "" if obj.nil?
	    end

	    obj
	  end
	  # -------------------------------------------------
	  # Formatage final de la valeur pour le script
	  # -------------------------------------------------
	  def format_value(val)
	    case val
	    when Numeric
		  val.round(4).to_s
	    when Array
		  val.join(",")
	    else
		  val.to_s
	    end
	  end      

	  def self.get_strategy(name)
		self.instance.get(name)
	  end

	  def self.toJson
	  	JSON.generate(self.instance.strategies)
	  end

	  def self.apply_strategie_diff(diff_hash)
	    return unless diff_hash.is_a?(Hash)

	    diff_hash.each do |name, text|
		  if text.nil?
		    # suppression
		    self.instance.strategies.delete(name)
		  else
		    # ajout ou override
		    self.instance.strategies[name] = text
		  end
	    end

	    self.instance.save_custom_strategies
	  end
    end
  end
end
