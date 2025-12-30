require_relative 'GN_ScriptEngine.rb'

module GNTools
  module NewPaths

    class StrategyEngine  < ScriptEngine

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
		  G0 X{CurrentTp.points[0].pos[0]} Y{CurrentTp.points[0].pos[1]} Z{Material.safeHeight} F{CurrentTp.metadata.feedrate.Value}
		  G1 Z{CurrentTp.metadata.depth.Value} F{CurrentTp.metadata.feedrate.Value}
		  G0 Z{Material.safeHeight}
	    STRAT

	    "Line" => <<~STRAT,
		  ; --- Strategy: Line ---
		  G0 X{CurrentTp.points[0].pos[0]} Y{CurrentTp.points[0].pos[1]} Z{Material.safeHeight} F{CurrentTp.metadata.feedrate.Value}
		  G1 Z{CurrentTp.metadata.depth.Value} F{CurrentTp.metadata.feedrate.Value}
		  G0 Z{Material.safeHeight}
	    STRAT
	  }
    
	  attr_accessor :strategies

      def self.instance
        @instance ||= new
      end
	
      def initialize()
		super()                       # ← ScriptEngine
		@strategies = load_all_strategies
      end

      # ============================================================
      # API PUBLIQUE
      # ============================================================

      # ============================================================
      # Générer le G-code à partir d’une stratégie
      # ============================================================
      def render(name,toolpath,vars = {})
	    run(
          get(name),
          toolpath,
          vars
        )
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
